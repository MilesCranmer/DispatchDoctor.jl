module DispatchDoctor

export @stable, TypeInstabilityError

using MacroTools: combinedef, splitdef
using TestItems: @testitem

const JULIA_LOWER_BOUND = v"1.10.0"
const JULIA_UPPER_BOUND = v"1.12.0-DEV.0"

struct TypeInstabilityError <: Exception
    f::Any
    args::Any
    kwargs::Any
    T::Any
end

@inline function _stable_wrap(f::F, caller::G, args...; kwargs...) where {F,G}
    T = if isempty(kwargs)
        Base.promote_op(f, map(typeof, args)...)
    else
        Base.promote_op(Core.kwcall, typeof(NamedTuple(kwargs)), F, map(typeof, args)...)
    end
    if !Base.isconcretetype(T)
        throw(TypeInstabilityError(caller, args, NamedTuple(kwargs), T))
    end
    return f(args...; kwargs...)::T
end

function extract_symb(ex::Symbol, ::String)
    return ex
end
function extract_symb(ex::Expr, type::String)
    if ex.head == :kw
        return extract_symb(ex.args[1], type)
    elseif ex.head == :tuple
        return ex
    elseif ex.head == :(::)
        return extract_symb(ex.args[1], type)
    else
        error(
            "Incompatible format for function $(type): `$(ex)` " *
            "with head=$(ex.head) args=$(ex.args). " *
            "Make sure to specify a symbol for each $(type) in the signature.",
        )
    end
end

function _stable(fex::Expr)
    func = splitdef(fex)
    func_runner = splitdef(fex)

    # keys: :name, :args, :kwargs, :body, :whereparams
    func_runner[:name] = gensym(string(func[:name]))

    func[:body] = quote
        $(_stable_wrap)(
            $(func_runner[:name]),
            $(func[:name]),
            $(map(a -> extract_symb(a, "argument"), func[:args])...);
            $(map(a -> extract_symb(a, "keyword argument"), func[:kwargs])...),
        )
    end

    return quote
        $(combinedef(func_runner))
        $(Base).@__doc__ $(combinedef(func))
    end
end

"""
    @stable [func_definition]

A macro to enforce type stability in functions. When applied, it ensures that the return type of the function is concrete. If type instability is detected, a `TypeInstabilityError` is thrown.

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

# Note

`@stable` acts as a no-op on Julia versions which are either not tested
or known to be incompatible.
"""
macro stable(fex)
    if VERSION < JULIA_LOWER_BOUND || VERSION >= JULIA_UPPER_BOUND
        return esc(fex)
    else
        return esc(_stable(fex))
    end
end

function Base.showerror(io::IO, e::TypeInstabilityError)
    print(io, "TypeInstabilityError: Instability detected in function `$(e.f)`")
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

end
