module DispatchDoctor

export @stable, @unstable, TypeInstabilityError

using MacroTools: combinedef, splitdef, isdef
using TestItems: @testitem

function extract_symbol(ex::Symbol)
    return ex
end
function extract_symbol(ex::Expr)
    if ex.head == :kw
        return extract_symbol(ex.args[1])
    elseif ex.head == :tuple
        return ex
    elseif ex.head == :(::)
        return extract_symbol(ex.args[1])
    elseif ex.head == :(...)
        return ex
    else
        return Unknown()
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
    return _stable_dispatch(ex; warnonly)
end
function _stable_dispatch(ex::Expr; kws...)
    if ex.head == :module
        return _stable_module(ex; kws...)
    else
        return _stable_fnc(ex; kws...)
    end
end

function _stable_module(ex; kws...)
    ex = _stable_all_fnc(ex; kws...)
    @assert ex.head == :module
    module_body = ex.args[3]
    @assert module_body.head == :block
    pushfirst!(
        module_body.args,
        :(function include(path::AbstractString)
            return include(ex -> $(_stable_all_fnc)(ex; $(kws)...), path)
        end),
    )
    return ex
end

function _stable_all_fnc(ex; kws...)
    return ex
end
function _stable_all_fnc(ex::Expr; kws...)
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@unstable")
        # Allow disabling
        return ex
    elseif isdef(ex)
        # Avoiding `MacroTools.postwalk` means we don't
        # recursively call this on closures
        _stable_fnc(ex; kws...)
    else
        Expr(ex.head, map(ex -> _stable_all_fnc(ex; kws...), ex.args)...)
    end
end

function _stable_fnc(fex::Expr; warnonly::Bool)
    func = splitdef(fex)

    arg_symbols = map(extract_symbol, func[:args])
    kwarg_symbols = map(extract_symbol, func[:kwargs])

    closure = gensym(string(func[:name], "_closure"))
    T = gensym(string(func[:name], "_return_type"))

    err = if !warnonly
        :(throw(
            $(TypeInstabilityError)(
                $(func[:name]), ($(arg_symbols...),), (; $(kwarg_symbols...)), $T
            ),
        ))
    else
        :(@warn(
            $(TypeInstabilityWarning)(
                $(func[:name]), ($(arg_symbols...),), (; $(kwarg_symbols...)), $T
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
    @stable [warnonly=false] [func_definition]

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

"""
macro stable(args...)
    return esc(_stable(args...))
end

"""
    @unstable [func_definition]

A no-op macro to mark functions as unstable when `@stable` is used on a module.
"""
macro unstable(fex)
    return esc(fex)
end

struct TypeInstabilityError <: Exception
    f::Any
    args::Any
    kwargs::Any
    T::Any
end
struct TypeInstabilityWarning
    f::Any
    args::Any
    kwargs::Any
    T::Any
end
function _print_msg(io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning})
    print(io, "$(typeof(e)): Instability detected in function `$(e.f)`")
    parts = []
    if !isempty(e.args)
        push!(parts, "arguments `$(map(typeof, e.args))`")
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

Base.showerror(io::IO, e::TypeInstabilityError) = _print_msg(io, e)
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

struct Unknown end
Base.show(io::IO, ::Type{Unknown}) = print(io, "[undefined symbol]")

end
