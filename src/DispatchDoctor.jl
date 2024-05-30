module DispatchDoctor

export @stable, @unstable, allow_unstable, TypeInstabilityError, register_macro!

using MacroTools: @capture, combinedef, splitdef, isdef, longdef
using TestItems: @testitem
using Preferences: load_preference, get_uuid

const JULIA_OK = let
    JULIA_LOWER_BOUND = v"1.10.0-DEV.0"
    JULIA_UPPER_BOUND = v"1.12.0-DEV.0"

    VERSION >= JULIA_LOWER_BOUND && VERSION < JULIA_UPPER_BOUND
end
# TODO: Get exact lower/upper bounds

"""
An enum to describe the behavior of macros when interacting with `@stable`.

- `CompatibleMacro`: Propagate macro through to both function and simulator.
- `DontPropagateMacro`: Do not propagate macro; leave it at the outer block.
- `IncompatibleMacro`: Do not propagate macro through to the function or simulator.
"""
@enum MacroBehavior begin
    CompatibleMacro
    DontPropagateMacro
    IncompatibleMacro
end

# Macros we dont want to propagate
const MACRO_BEHAVIOR = (;
    table=Dict([
        Symbol("@doc") => DontPropagateMacro,               # Core
        # ^ Base.@__doc__ takes care of this.
        Symbol("@assume_effects") => IncompatibleMacro,     # Base
        # ^ Some effects are incompatible, like
        #   :nothrow, so this requires much more
        #   work to get working. TODO.
        Symbol("@enum") => IncompatibleMacro,               # Base
        # ^ TODO. Seems to interact.
        Symbol("@eval") => IncompatibleMacro,               # Base
        # ^ Too much flexibility to apply,
        #   and user could always use `@eval`
        #   inside function.
        Symbol("@deprecate") => IncompatibleMacro,          # Base
        # ^ TODO. Seems to interact.
        Symbol("@generated") => IncompatibleMacro,          # Base
        # ^ In principle this is compatible but
        #   needs additional logic to work.
        Symbol("@kwdef") => IncompatibleMacro,              # Base
        # ^ TODO. Seems to interact.
        Symbol("@pure") => IncompatibleMacro,               # Base
        # ^ See `@assume_effects`.
        Symbol("@everywhere") => DontPropagateMacro,        # Distributed
        # ^ Prefer to have block passed to workers
        #   only a single time. And `@everywhere`
        #   works with blocks of code, so it is
        #   fine.
        Symbol("@model") => IncompatibleMacro,              # Turing
        # ^ Fairly common macro used to define
        #   probabilistic models. The syntax is
        #   incompatible with `@stable`.
        Symbol("@capture") => IncompatibleMacro,            # MacroTools
        # ^ Similar to `@model`.
    ]),
    lock=Threads.SpinLock(),
)
#! format: off
get_macro_behavior(_) = CompatibleMacro
get_macro_behavior(ex::Symbol) = get(MACRO_BEHAVIOR.table, ex, CompatibleMacro)
get_macro_behavior(ex::QuoteNode) = get_macro_behavior(ex.value)
get_macro_behavior(ex::Expr) = reduce(combine_behavior, map(get_macro_behavior, ex.args); init=CompatibleMacro)
#! format: on

function combine_behavior(a::MacroBehavior, b::MacroBehavior)
    if a == CompatibleMacro && b == CompatibleMacro
        return CompatibleMacro
    elseif a == IncompatibleMacro || b == IncompatibleMacro
        return IncompatibleMacro
    else
        return DontPropagateMacro
    end
end

"""
    register_macro!(macro_name::Symbol, behavior::MacroBehavior)

Register a macro with a specified behavior in the `MACRO_BEHAVIOR` list.

This function adds a new macro and its associated behavior to the global list that
tracks how macros should be treated when encountered during the stabilization
process. The behavior can be one of `CompatibleMacro`, `IncompatibleMacro`, or `DontPropagateMacro`,
which influences how the `@stable` macro interacts with the registered macro.

The default behavior for `@stable` is to assume `CompatibleMacro` unless explicitly declared.

# Arguments
- `macro_name::Symbol`: The symbol representing the macro to register.
- `behavior::MacroBehavior`: The behavior to associate with the macro, which dictates how it should be handled.

# Examples
```julia
using DispatchDoctor: register_macro!, IncompatibleMacro

register_macro!(Symbol("@mymacro"), IncompatibleMacro)
```
"""
function register_macro!(macro_name::Symbol, behavior::MacroBehavior)
    lock(MACRO_BEHAVIOR.lock) do
        if haskey(MACRO_BEHAVIOR.table, macro_name)
            error(
                "Macro $macro_name already registered with behavior $(MACRO_BEHAVIOR.table[macro_name]).",
            )
        end
        MACRO_BEHAVIOR.table[macro_name] = behavior
        MACRO_BEHAVIOR.table[macro_name]
    end
end

is_function_name_compatible(ex) = false
is_function_name_compatible(ex::Symbol) = true
is_function_name_compatible(ex::Expr) = ex.head == :(.) && all(is_symbol_like, ex.args)
is_symbol_like(ex) = false
is_symbol_like(ex::QuoteNode) = is_symbol_like(ex.value)
is_symbol_like(ex::Symbol) = true

function extract_symbol(ex::Symbol, fullex=ex)
    if ex == Symbol("_")
        return Unknown("_")
    else
        return ex
    end
end
function extract_symbol(ex::Expr, fullex=ex)
    #! format: off
    if ex.head == :(::) && length(ex.args) > 1 && @capture(ex.args[2], Vararg | Vararg{_} | Vararg{_,_})
        return :($(ex.args[1])...)
    elseif ex.head in (:kw, :(::), :(<:))
        out = extract_symbol(ex.args[1], ex)
        return out isa Unknown ? Unknown(string(ex)) : out
    elseif ex.head == :(...) && ex.args[1] isa Expr && ex.args[1].head == :(::)
        # Such as `a::Int...`
        return :($(ex.args[1].args[1])...)
    elseif ex.head in (:tuple, :(...))
        return ex
    else
        return Unknown(string(ex))
    end
    #! format: on
end

"""
Fix args that do not have a symbol.
"""
function inject_symbol_to_arg(ex::Symbol)
    return ex
end
function inject_symbol_to_arg(ex::Expr)
    if ex.head == :(::) && length(ex.args) == 1
        return Expr(:(::), gensym("arg"), ex.args[1])
    elseif ex.head == :(kw) &&
        length(ex.args) == 2 &&
        ex.args[1] isa Expr &&
        ex.args[1].head == :(::) &&
        length(ex.args[1].args) == 1

        # Matches things like `::Type{T}=MyType`
        return Expr(:(kw), Expr(:(::), gensym("arg"), ex.args[1].args[1]), ex.args[2])
    elseif ex.head == :(...) &&
        length(ex.args) == 1 &&
        ex.args[1] isa Expr &&
        ex.args[1].head == :(::) &&
        length(ex.args[1].args) == 1

        # Matches things like `::Int...`
        return Expr(:(...), Expr(:(::), gensym("arg"), ex.args[1].args[1]))
    else
        return ex
    end
end

specializing_typeof(::T) where {T} = T
specializing_typeof(::Type{T}) where {T} = Type{T}
specializing_typeof(::Val{T}) where {T} = Val{T}

function _stable(args...; calling_module, source_info, kws...)
    options, ex = args[begin:(end - 1)], args[end]

    # Standard defaults:
    mode = "error"

    # Deprecated
    warnonly = nothing
    enable = nothing
    for option in options
        if option isa Expr && option.head == :(=)
            if option.args[1] == :warnonly
                warnonly = option.args[2]
                continue
            elseif option.args[1] == :enable
                enable = option.args[2]
                continue
            elseif option.args[1] == :default_mode
                mode = option.args[2]
                continue
            end
        end
        error("Unknown macro option: $option")
    end

    # Load in any expression-based options
    mode = if mode isa Expr
        Core.eval(calling_module, mode)
    else
        (mode isa QuoteNode ? mode.value : mode)
    end

    # Deprecated
    warnonly = warnonly isa Expr ? Core.eval(calling_module, warnonly) : warnonly
    enable = enable isa Expr ? Core.eval(calling_module, enable) : enable

    if calling_module != Core.Main
        # Local setting from Preferences.jl overrides defaults
        mode = try
            load_preference(get_uuid(calling_module)::Base.UUID, "instability_check", mode)
        catch
            mode
        end
        # TODO: Why do we need this try-catch? Seems like its used by e.g.,
        # https://github.com/JuliaLang/PrecompileTools.jl/blob/a99446373f9a4a46d62a2889b7efb242b4ad7471/src/workloads.jl#L2C10-L11
    end
    if enable !== nothing
        @warn "The `enable` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
        if warnonly !== nothing
            @warn "The `warnonly` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
            mode = warnonly ? "warn" : (enable ? "error" : "disable")
        else
            mode = enable ? "error" : "disable"
        end
    end
    if mode in ("error", "warn")
        num_matches = Ref(0)
        out = _stabilize_all(ex, num_matches; source_info, kws..., mode)
        if num_matches[] == 0
            @warn(
                "`@stable` found no compatible functions to stabilize",
                source_info = source_info,
                calling_module = calling_module,
            )
        end
        return out
    elseif mode == "disable"
        return ex
    else
        error("Unknown mode: $mode. Please use \"error\", \"warn\", or \"disable\".")
    end
end

function _stabilize_all(ex, num_matches::Ref{Int}, macro_stack::Vector{Any}=Any[]; kws...)
    return ex
end
function _stabilize_all(
    ex::Expr, num_matches::Ref{Int}, macro_stack::Vector{Any}=Any[]; kws...
)
    #! format: off
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@unstable")
        # Allow disabling
        return ex
    elseif ex.head == :macrocall
        macro_behavior = get_macro_behavior(ex.args[1])
        if macro_behavior == IncompatibleMacro
            return ex
        elseif macro_behavior == CompatibleMacro
            # We build up a stack of macros to propagate to the function call
            push!(macro_stack, ex.args[1:end-1])
            return _stabilize_all(ex.args[end], num_matches, macro_stack; kws...)
        else
            @assert macro_behavior == DontPropagateMacro
            return Expr(:macrocall, ex.args[1], map(e -> _stabilize_all(e, num_matches; kws...), ex.args[2:end])...)
        end
    elseif ex.head == :macro
        # Do nothing inside macros (in case of closure)
        return ex
    elseif ex.head == :quote
        # Do nothing inside of quotes
        return ex
    elseif ex.head == :global
        # Incompatible with two functions
        return ex
    elseif ex.head == :module
        return _stabilize_module(ex, num_matches; kws...)
    elseif ex.head == :call && ex.args[1] == Symbol("include") && length(ex.args) == 2
        # We can't track the matches in includes, so just assume
        # there are some matches. TODO: However, this is not a great solution.
        num_matches[] += 1
        # Replace include with DispatchDoctor version
        return :($(_stabilizing_include)(@__MODULE__, $(ex.args[2]), $num_matches; $(kws)...))
    elseif isdef(ex) && @capture(longdef(ex), function (fcall_ | fcall_) body_ end)
        #               ^ This is the same check done by `splitdef`
        # TODO: Should report `isdef` to MacroTools as not capturing all cases
        return _stabilize_fnc(ex, num_matches, macro_stack; kws...)
    else
        return Expr(ex.head, map(e -> _stabilize_all(e, num_matches; kws...), ex.args)...)
    end
    #! format: on
end

function _stabilizing_include(m::Module, path, num_matches::Ref{Int}; kws...)
    return m.include(ex -> _stabilize_all(ex, num_matches; kws...), path)
end

function _stabilize_module(ex, num_matches::Ref{Int}; kws...)
    ex = Expr(
        :module,
        ex.args[1],
        ex.args[2],
        Expr(:block, map(e -> _stabilize_all(e, num_matches; kws...), ex.args[3].args)...),
    )
    return ex
end

get_first_source_info(ex) = nothing
get_first_source_info(l::LineNumberNode) = l
function get_first_source_info(s::Expr)
    for arg in s.args
        extracted_arg = get_first_source_info(arg)
        if extracted_arg isa LineNumberNode
            return extracted_arg
        end
    end
    return nothing
end

function _stabilize_fnc(
    fex::Expr,
    num_matches::Ref{Int},
    macro_stack::Vector{Any}=Any[];
    mode::String="error",
    source_info::Union{LineNumberNode,Nothing}=nothing,
)
    func = splitdef(fex)

    if haskey(func, :params) && length(func[:params]) > 0
        # Incompatible with parameterized functions
        return fex
    elseif haskey(func, :name) && !is_function_name_compatible(func[:name])
        return fex
    end

    # It's a match, so increment the number of matches
    num_matches[] += 1

    func_simulator = splitdef(deepcopy(fex))

    # Load any information about the source
    searched_source_info = get_first_source_info(fex)
    source_info = if searched_source_info isa LineNumberNode
        string(searched_source_info.file, ":", searched_source_info.line)
    elseif source_info isa LineNumberNode
        string(source_info.file, ":", source_info.line)
    else
        nothing
    end

    if haskey(func, :name)
        name = string(func[:name])
        print_name = string("`", name, "`")
    else
        name = "anonymous_function"
        print_name = "anonymous function"
    end

    args = map(inject_symbol_to_arg, func[:args])
    kwargs = func[:kwargs]
    where_params = func[:whereparams]

    func[:args] = args
    func_simulator[:args] = deepcopy(args)

    arg_symbols = map(extract_symbol, args)
    kwarg_symbols = map(extract_symbol, kwargs)
    where_param_symbols = map(extract_symbol, where_params)

    simulator = gensym(string(name, "_simulator"))
    T = gensym(string(name, "_return_type"))

    err = if mode == "error"
        :(throw(
            $(TypeInstabilityError)(
                $(print_name),
                $(source_info),
                ($(arg_symbols...),),
                (; $(kwarg_symbols...)),
                ($(where_param_symbols) .=> ($(where_param_symbols...),)),
                $T,
            ),
        ))
    elseif mode == "warn"
        :(@warn(
            $(TypeInstabilityWarning)(
                $(print_name),
                $(source_info),
                ($(arg_symbols...),),
                (; $(kwarg_symbols...)),
                ($(where_param_symbols) .=> ($(where_param_symbols...),)),
                $T,
            ),
        ))
    else
        error("Unknown mode: $mode. Please use \"error\" or \"warn\".")
    end

    checker = if isempty(kwarg_symbols)
        :($(Base).promote_op($simulator, map($specializing_typeof, ($(arg_symbols...),))...))
    else
        :($(Base).promote_op(
            Core.kwcall,
            typeof((; $(kwarg_symbols...))),
            typeof($simulator),
            map($specializing_typeof, ($(arg_symbols...),))...,
        ))
    end

    func_simulator[:name] = simulator
    func[:body] = quote
        $T = $checker
        if $(type_instability)($T) && !$(is_precompiling)() && $(checking_enabled)()
            $err
        end

        $(func[:body])
    end

    func_simulator_ex = combinedef(func_simulator)
    func_ex = combinedef(func)

    # We apply other macros to both the function and the simulator
    for macro_element in macro_stack
        func_ex = Expr(:macrocall, macro_element..., func_ex)
        func_simulator_ex = Expr(:macrocall, macro_element..., func_simulator_ex)
    end

    return quote
        $(func_simulator_ex)
        $(Base).@__doc__ $(func_ex)
    end
end

"""To avoid errors and warnings during precompilation."""
@inline is_precompiling() = ccall(:jl_generating_output, Cint, ()) == 1

"""To locally enable/disable instability checks."""
@inline function checking_enabled()
    return INSTABILITY_CHECK_ENABLED.value[]
end
const INSTABILITY_CHECK_ENABLED = (; value=Ref(true), lock=ReentrantLock())

"""
    allow_unstable(f::F) where {F<:Function}

Globally disable type DispatchDoctor instability checks within the provided function `f`.

This function allows you to execute a block of code where type instability
checks are disabled. It ensures that the checks are re-enabled after the block
is executed, even if an error occurs.

This function uses a `ReentrantLock` and will throw an error if used from
two tasks at once.

# Usage

```
allow_unstable() do
    # do unstable stuff
end
```

# Arguments

- `f::F`: A function to be executed with type instability checks disabled.

# Returns

- The result of the function `f`.

# Notes

You cannot call `allow_unstable` from two tasks at once. An error
will be thrown if you try to do so.
"""
@inline function allow_unstable(f::F) where {F<:Function}
    successful_lock = trylock(INSTABILITY_CHECK_ENABLED.lock)
    if !successful_lock
        throw(
            AllowUnstableDataRace(
                "You cannot call `allow_unstable` from two tasks at once. " *
                "This error is a result of `INSTABILITY_CHECK_ENABLED` " *
                "being locked by another task.",
            ),
        )
    end
    local out
    try
        INSTABILITY_CHECK_ENABLED.value[] = false
        out = f()
    finally
        INSTABILITY_CHECK_ENABLED.value[] = true
        unlock(INSTABILITY_CHECK_ENABLED.lock)
    end
    return out
end

"""
    type_instability(T::Type)

Returns true if this type is not concrete. Will also
return false for `Union{}`, so that errors can propagate.
"""
@inline type_instability(::Type{T}) where {T} = !Base.isconcretetype(T)
@inline type_instability(::Type{Union{}}) = false

"""
    @stable [options...] [code_block]

A macro to enforce type stability in functions.
When applied, it ensures that the return type of the function is concrete.
If type instability is detected, a `TypeInstabilityError` is thrown.

# Options

- `default_mode::String="error"`: Change the default mode to `"warn"` to only emit a warning, or
   `"disable"` to disable type instability checks by default. To locally set the mode for
   a package that uses DispatchDoctor, you can use the "instability_check" key in your
   LocalPreferences.toml (typically configured with Preferences.jl)

# Example
    
```julia
using DispatchDoctor: @stable

@stable function relu(x)
    if x > 0
        return x
    else
        return 0.0
    end
end
```

which will automatically flag any type instability:

```julia
julia> relu(1.0)
1.0

julia> relu(0)
ERROR: TypeInstabilityError: Instability detected in function `relu`
with arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,
which is not a concrete type.
```

# Extended help

You may also apply `@stable` to arbitrary blocks of code, such as `begin`
or `module`, and have it be applied to all functions.
(Just note that this skips closure functions.)

```julia
using DispatchDoctor: @stable

@stable begin
    f(x) = x
    g(x) = x > 0 ? x : 0.0
    @unstable begin
        g(x::Int) = x > 0 ? x : 0.0
    end
    module A
        h(x) = x
        include("myfile.jl")
    end
end
```

This `@stable` will apply to `f`, `g`, `h`,
as well as all functions within `myfile.jl`.
It skips the definition `g(x::Int)`, meaning
that when `Int` input is provided to `g`,
type instability is not detected.

"""
macro stable(args...)
    if JULIA_OK
        return esc(_stable(args...; source_info=__source__, calling_module=__module__))
    else
        return esc(args[end])
    end
end

"""
    @unstable [code_block]

A no-op macro to hide blocks of code from `@stable`.
"""
macro unstable(fex)
    return esc(fex)
end

struct AllowUnstableDataRace <: Exception
    msg::String
end
Base.showerror(io::IO, e::AllowUnstableDataRace) = print(io, e.msg)

struct TypeInstabilityError <: Exception
    f::String
    source_info::Union{String,Nothing}
    args::Any
    kwargs::Any
    params::Any
    return_type::Any
end
struct TypeInstabilityWarning
    f::String
    source_info::Union{String,Nothing}
    args::Any
    kwargs::Any
    params::Any
    return_type::Any
end
function _print_msg(io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning})
    print(io, "$(typeof(e)): Instability detected in $(e.f)")
    if e.source_info !== nothing
        print(io, " defined at ", e.source_info)
    end
    parts = []
    if !isempty(e.args)
        push!(parts, "arguments `$(map(typeinfo, e.args))`")
    end
    if !isempty(e.kwargs)
        push!(parts, "keyword arguments `$(typeof(e.kwargs))`")
    end
    if !isempty(e.params)
        push!(parts, "parameters `$(e.params)`")
    end
    if !isempty(parts)
        print(io, " with ")
        join(io, parts, " and ")
    end
    print(io, ". ")
    return print(io, "Inferred to be `$(e.return_type)`, which is not a concrete type.")
end
typeinfo(x) = specializing_typeof(x)

Base.showerror(io::IO, e::TypeInstabilityError) = _print_msg(io, e)
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

struct Unknown
    msg::String
end
Base.show(io::IO, u::Unknown) = print(io, string("[", u.msg, "]"))
typeinfo(u::Unknown) = u

end
