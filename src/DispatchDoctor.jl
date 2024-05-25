module DispatchDoctor

export @stable, TypeInstabilityError

using MacroTools: combinedef, splitdef, isdef
using TestItems: @testitem

struct TypeInstabilityError <: Exception
    f::Any
    args::Any
    kwargs::Any
    T::Any
end

struct Unknown end
Base.show(io::IO, ::Type{Unknown}) = print(io, "[undefined symbol]")

function extract_symb(ex::Symbol)
    return ex
end
function extract_symb(ex::Expr)
    if ex.head == :kw
        return extract_symb(ex.args[1])
    elseif ex.head == :tuple
        return ex
    elseif ex.head == :(::)
        return extract_symb(ex.args[1])
    elseif ex.head == :(...)
        return ex
    else
        return Unknown()
    end
end

function _stable(ex::Expr)
    if ex.head == :module
        return _stable_module(ex)
    else
        return _stable_fnc(ex)
    end
end

function _stable_module(ex)
    ex = _stable_all_fnc(ex)
    @assert ex.head == :module
    module_body = ex.args[3]
    @assert module_body.head == :block
    pushfirst!(module_body.args, :(include(path) = include($(_stable_all_fnc), path)))
    return ex
end

function _stable_all_fnc(ex)
    return ex
end
function _stable_all_fnc(ex::Expr)
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex
    elseif isdef(ex)
        # Avoiding `MacroTools.postwalk` means we don't
        # recursively call this on closures
        _stable_fnc(ex)
    else
        Expr(ex.head, map(_stable_all_fnc, ex.args)...)
    end
end

function _stable_fnc(fex::Expr)
    func = splitdef(fex)

    arg_symbols = map(extract_symb, func[:args])
    kwarg_symbols = map(extract_symb, func[:kwargs])

    closure = gensym(string(func[:name], "_closure"))
    T = gensym(string(func[:name], "_return_type"))

    func[:body] = quote
        let $closure() = $(func[:body]), $T = $(Base).promote_op($closure)
            if !$(Base).isconcretetype($T)
                throw(
                    $(TypeInstabilityError)(
                        $(func[:name]),
                        ($(arg_symbols...),),
                        (; $(kwarg_symbols...)),
                        $T,
                    ),
                )
            end

            return $closure()::$T
        end
    end

    return combinedef(func)
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

"""
macro stable(fex)
    return esc(_stable(fex))
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
