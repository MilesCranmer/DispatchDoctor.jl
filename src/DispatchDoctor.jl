module DispatchDoctor

export @stable, @unstable, allow_unstable, TypeInstabilityError

using MacroTools: @capture, combinedef, splitdef, isdef, longdef
using TestItems: @testitem
using Preferences: load_preference

const JULIA_OK = let
    JULIA_LOWER_BOUND = v"1.10.0-DEV.0"
    JULIA_UPPER_BOUND = v"1.12.0-DEV.0"

    VERSION >= JULIA_LOWER_BOUND && VERSION < JULIA_UPPER_BOUND
end
# TODO: Get exact lower/upper bounds

const INCOMPATIBLE_MACROS = [
    Symbol("@generated"),          # Base.jl
    Symbol("@eval"),               # Base.jl
    Symbol("@propagate_inbounds"), # Base.jl
    Symbol("@assume_effects"),     # Base.jl
    Symbol("@model"),              # Turing.jl
    Symbol("@capture"),            # MacroTools.jl
]
function matches_incompatible_macro(ex::Symbol)
    return ex in INCOMPATIBLE_MACROS
end
function matches_incompatible_macro(ex)
    return false
end
function matches_incompatible_macro(ex::Expr)
    return any(matches_incompatible_macro, ex.args)
end
function matches_incompatible_macro(ex::QuoteNode)
    return matches_incompatible_macro(ex.value)
end

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
    elseif ex.head == :(kw) && length(ex.args) == 2
        if ex.args[1] isa Expr
            if ex.args[1].head == :(::) && length(ex.args[1].args) == 1
                return Expr(
                    :(kw), Expr(:(::), gensym("arg"), ex.args[1].args[1]), ex.args[2]
                )
            else
                return ex
            end
        else
            return ex
        end
    end
    return ex
end

specializing_typeof(::T) where {T} = T
specializing_typeof(::Type{T}) where {T} = Type{T}
specializing_typeof(::Val{T}) where {T} = Val{T}

function _stable(args...; calling_module, kws...)
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
            elseif option.args[1] == :mode
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
            load_preference(calling_module, "instability_check", mode)
        catch
            mode
        end
        # TODO: Why do we need this try-catch? Seems like its used by e.g.,
        # https://github.com/JuliaLang/PrecompileTools.jl/blob/a99446373f9a4a46d62a2889b7efb242b4ad7471/src/workloads.jl#L2C10-L11
    end
    if enable !== nothing
        @warn "The `enable` option is deprecated. Please use `mode` instead, either \"error\", \"warn\", or \"disable\"."
        if warnonly !== nothing
            @warn "The `warnonly` option is deprecated. Please use `mode` instead, either \"error\", \"warn\", or \"disable\"."
            mode = warnonly ? "warn" : (enable ? "error" : "disable")
        else
            mode = enable ? "error" : "disable"
        end
    end
    if mode in ("error", "warn")
        return _stabilize_all(ex; kws..., mode)
    elseif mode == "disable"
        return ex
    else
        error("Unknown mode: $mode. Please use \"error\", \"warn\", or \"disable\".")
    end
end

function _stabilize_all(ex; kws...)
    return ex
end
function _stabilize_all(ex::Expr; kws...)
    #! format: off
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@unstable")
        # Allow disabling
        return ex
    elseif ex.head == :macrocall && matches_incompatible_macro(ex.args[1])
        return ex
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
        return _stabilize_module(ex; kws...)
    elseif ex.head == :call && ex.args[1] == Symbol("include") && length(ex.args) == 2
        # Replace include with DispatchDoctor version
        return :($(_stabilizing_include)(@__MODULE__, $(ex.args[2]); $(kws)...))
    elseif isdef(ex) && @capture(longdef(ex), function (fcall_ | fcall_) body_ end)
        #               ^ This is the same check done by `splitdef`
        # TODO: Should report `isdef` to MacroTools as not capturing all cases
        return _stabilize_fnc(ex; kws...)
    else
        return Expr(ex.head, map(e -> _stabilize_all(e; kws...), ex.args)...)
    end
    #! format: on
end

function _stabilizing_include(m::Module, path; kws...)
    return m.include(ex -> _stabilize_all(ex; kws...), path)
end

function _stabilize_module(ex; kws...)
    ex = Expr(
        :module,
        ex.args[1],
        ex.args[2],
        Expr(:block, map(e -> _stabilize_all(e; kws...), ex.args[3].args)...),
    )
    return ex
end

function _stabilize_fnc(
    fex::Expr; mode::String="error", source_info::Union{LineNumberNode,Nothing}=nothing
)
    func = splitdef(fex)

    if haskey(func, :params) && length(func[:params]) > 0
        # Incompatible with parameterized functions
        return fex
    elseif haskey(func, :name) && func[:name] isa Expr
        # Incompatible with expression-based function names
        return fex
    end

    func_with_body = splitdef(deepcopy(fex))
    source_info =
        source_info === nothing ? nothing : string(source_info.file, ":", source_info.line)

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
    func_with_body[:args] = deepcopy(args)

    arg_symbols = map(extract_symbol, args)
    kwarg_symbols = map(extract_symbol, kwargs)
    where_param_symbols = map(extract_symbol, where_params)

    closure = gensym(string(name, "_closure"))
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
            maxlog = 1
        ))
    else
        error("Unknown mode: $mode. Please use \"error\" or \"warn\".")
    end

    checker = if isempty(kwarg_symbols)
        :($(Base).promote_op($closure, map($specializing_typeof, ($(arg_symbols...),))...))
    else
        :($(Base).promote_op(
            Core.kwcall,
            typeof((; $(kwarg_symbols...))),
            typeof($closure),
            map($specializing_typeof, ($(arg_symbols...),))...,
        ))
    end

    caller = if isempty(kwarg_symbols)
        :($closure($(arg_symbols...)))
    else
        :($closure($(arg_symbols...); $(kwarg_symbols...)))
    end

    func_with_body[:name] = closure
    func[:body] = quote
        $T = $checker
        if $(type_instability)($T) && !$(is_precompiling)() && $(checking_enabled)()
            $err
        end

        return $caller
    end

    return quote
        $(Base).@inline $(combinedef(func_with_body))
        $(Base).@__doc__ $(combinedef(func))
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

- `mode::String="error"`: Set this to `"warn"` to only emit a warning, or
   `"disable"` to disable type instability checks altogether.

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
