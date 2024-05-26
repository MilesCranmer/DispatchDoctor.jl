module DispatchDoctor

export @stable, @unstable, TypeInstabilityError

using MacroTools: combinedef, splitdef, isdef
using TestItems: @testitem

function extract_symbol(ex::Symbol)
    return ex
end
function extract_symbol(ex::Expr)
    if ex.head in (:kw, :(::))
        out = extract_symbol(ex.args[1])
        return out isa Unknown ? Unknown(string(ex)) : out
    elseif ex.head in (:tuple, :(...))
        return ex
    else
        return Unknown(string(ex))
    end
end

function _stable(args...)
    options, ex = args[begin:(end - 1)], args[end]
    warnonly = false
    for option in options
        if option isa Expr && option.head == :(=)
            if option.args[1] == :warnonly
                warnonly = option.args[2]
                continue
            end
        end
        error("Unknown macro option: $option")
    end
    return _stabilize_all(ex; warnonly)
end

function _stabilize_all(ex; kws...)
    return ex
end
function _stabilize_all(ex::Expr; kws...)
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@unstable")
        # Allow disabling
        return ex
    elseif ex.head == :module
        return _stabilize_module(ex; kws...)
    elseif ex.head == :call && ex.args[1] == Symbol("include") && length(ex.args) == 2
        # Replace include with DispatchDoctor version
        return :($(_stabilizing_include)(@__MODULE__, $(ex.args[2]); $(kws)...))
    elseif isdef(ex)
        # Avoiding `MacroTools.postwalk` means we don't
        # recursively call this on closures
        _stabilize_fnc(ex; kws...)
    else
        Expr(ex.head, map(e -> _stabilize_all(e; kws...), ex.args)...)
    end
end

function _stabilizing_include(m::Module, path; kws...)
    return Base.include(ex -> _stabilize_all(ex; kws...), m, path)
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

function _stabilize_fnc(fex::Expr; warnonly::Bool)
    func = splitdef(fex)

    name = string(func[:name])
    arg_symbols = map(extract_symbol, func[:args])
    kwarg_symbols = map(extract_symbol, func[:kwargs])

    closure = gensym(string(name, "_closure"))
    T = gensym(string(name, "_return_type"))

    err = if !warnonly
        :(throw(
            $(TypeInstabilityError)(
                $(name), ($(arg_symbols...),), (; $(kwarg_symbols...)), $T
            ),
        ))
    else
        :(@warn(
            $(TypeInstabilityWarning)(
                $(name), ($(arg_symbols...),), (; $(kwarg_symbols...)), $T
            ),
            maxlog = 1
        ))
    end

    func[:body] = quote
        let $closure() = $(func[:body]), $T = $(Base).promote_op($closure)
            if $(type_instability)($T)
                $err
            end

            return $closure()::$T
        end
    end

    return combinedef(func)
end

"""
    type_instability(T::Type)

Returns true if this type is not concrete. Will also
return false for `Union{}`, so that errors can propagate.
"""
@inline type_instability(::Type{T}) where {T} = !Base.isconcretetype(T)
@inline type_instability(::Type{Union{}}) = false

"""
    @stable [warnonly=false] [code_block]

A macro to enforce type stability in functions.
When applied, it ensures that the return type of the function is concrete.
If type instability is detected, a `TypeInstabilityError` is thrown.
You may also pass `warnonly=true` to only emit a warning.

# Usage
    
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

# Example

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
    return esc(_stable(args...))
end

"""
    @unstable [code_block]

A no-op macro to hide blocks of code from `@stable`.
"""
macro unstable(fex)
    return esc(fex)
end

struct TypeInstabilityError <: Exception
    f::String
    args::Any
    kwargs::Any
    T::Any
end
struct TypeInstabilityWarning
    f::String
    args::Any
    kwargs::Any
    T::Any
end
function _print_msg(io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning})
    print(io, "$(typeof(e)): Instability detected in function `$(e.f)`")
    parts = []
    if !isempty(e.args)
        push!(parts, "arguments `$(map(typeinfo, e.args))`")
    end
    if !isempty(e.kwargs)
        push!(parts, "keyword arguments `$(typeof(e.kwargs))`")
    end
    if !isempty(parts)
        print(io, " with ")
        join(io, parts, " and ")
    end
    print(io, ". ")
    return print(io, "Inferred to be `$(e.T)`, which is not a concrete type.")
end
typeinfo(x) = typeof(x)

Base.showerror(io::IO, e::TypeInstabilityError) = _print_msg(io, e)
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

struct Unknown
    msg::String
end
Base.show(io::IO, u::Unknown) = print(io, string("[", u.msg, "]"))
typeinfo(u::Unknown) = u

end
