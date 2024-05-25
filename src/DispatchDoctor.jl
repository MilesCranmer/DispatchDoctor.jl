module DispatchDoctor

export @stable, TypeInstabilityError

using MacroTools: combinedef, splitdef, postwalk, isdef, isshortdef, rmlines, prettify
using TestItems: @testitem

struct TypeInstabilityError <: Exception
    f::Any
    args::Any
    kwargs::Any
    T::Any
end

function extract_symb(ex::Symbol, full_ex, ::String)
    return ex
end
function extract_symb(ex::Expr, full_ex, type::String)
    if ex.head == :kw
        return extract_symb(ex.args[1], full_ex, type)
    elseif ex.head == :tuple
        return ex
    elseif ex.head == :(::)
        return extract_symb(ex.args[1], full_ex, type)
    elseif ex.head == :(...)
        return ex
    else
        error(
            "Incompatible format for function $(type): `$(full_ex)`. " *
            "Make sure to specify a symbol for each $(type) in the signature.",
        )
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
    pushfirst!(
        module_body.args,
        quote
            include(path) = include($(_stable_fnc), path)
        end,
    )
    return ex
end

function _stable_all_fnc(ex)
    return postwalk(ex) do ex_part
        if isdef(ex_part)
            _stable_fnc(ex_part)
        else
            ex_part
        end
    end
end

# TODO: Test that closures aren't wrapped
# TODO: Test that we don't get any `@stable @stable`

function _stable_fnc(fex::Expr)
    func = splitdef(fex)

    arg_symbols = map(a -> extract_symb(a, a, "argument"), func[:args])
    kwarg_symbols = map(a -> extract_symb(a, a, "keyword argument"), func[:kwargs])

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
