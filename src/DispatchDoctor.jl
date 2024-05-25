module DispatchDoctor

export @stable, TypeInstabilityError

using MacroTools: combinedef, splitdef
using TestItems: @testitem

struct TypeInstabilityError <: Exception
    f::Any
    args::Any
    kwargs::Any
    T::Any
end

function Base.showerror(io::IO, e::TypeInstabilityError)
    print(io, "TypeInstabilityError: Type instability detected in function `$(e.f)`")
    parts = []
    if !isempty(e.args)
        push!(parts, "arguments `$(e.args)`")
    end
    if !isempty(e.kwargs)
        push!(parts, "keyword arguments `$(e.kwargs)`")
    end
    if !isempty(parts)
        print(io, " with ")
        join(io, parts, " and ")
    end
    print(io, ". ")
    return print(io, "Inferred to be `$(e.T)`, which is not a concrete type.")
end

@inline function _stable_wrap(f::F, caller::G, args...; kwargs...) where {F,G}
    T = if isempty(kwargs)
        Base.promote_op(f, map(typeof, args)...)
    else
        Base.promote_op(Core.kwcall, typeof(NamedTuple(kwargs)), F, map(typeof, args)...)
    end
    if !Base.isconcretetype(T)
        throw(TypeInstabilityError(caller, args, kwargs, T))
    end
    return f(args...; kwargs...)::T
end

function extract_symb(ex::Symbol)
    return ex
end
function extract_symb(ex::Expr)
    if ex.head == :kw
        return ex.args[1]
    elseif ex.head == :tuple
        return ex
    else
        error("Unexpected: head=$(ex.head) args=$(ex.args)")
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
            $(map(extract_symb, func[:args])...);
            $(map(extract_symb, func[:kwargs])...),
        )
    end

    return quote
        $(combinedef(func_runner))
        $(combinedef(func))
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
ERROR: TypeInstabilityError: Type instability detected
in function `relu` with arguments `(0,)`. Inferred to be
`Union{Float64, Int64}`, which is not a concrete type.
```

# Note

`@stable` acts as a no-op on Julia versions before 1.10.
"""
macro stable(fex)
    if VERSION < v"1.10"
        return esc(fex)
    else
        return esc(_stable(fex))
    end
end

@testitem "smoke test" begin
    using DispatchDoctor
    @stable f(x) = x
    @test f(1) == 1
end
@testitem "with error" begin
    using DispatchDoctor
    @stable f(x) = x > 0 ? x : 1.0

    # Will catch type instability:
    if VERSION >= v"1.10"
        @test_throws TypeInstabilityError f(1)
    else
        @test f(1) == 1
    end
    @test f(2.0) == 2.0
end
@testitem "with kwargs" begin
    using DispatchDoctor
    @stable f(x; a=1, b=2) = x + a + b
    @test f(1) == 4
    @stable g(; a=1) = a > 0 ? a : 1.0
    if VERSION >= v"1.10"
        @test_throws TypeInstabilityError g()
    else
        @test g() == 1
    end
    @test g(; a=2.0) == 2.0
end
@testitem "tuple args" begin
    using DispatchDoctor
    @stable f((x, y); a=1, b=2) = x + y + a + b
    @test f((1, 2)) == 6
    @test f((1, 2); b=3) == 7
    @stable g((x, y), z=1.0; c=2.0) = x > 0 ? y : c + z
    @test g((1, 2.0)) == 2.0
    if VERSION >= v"1.10"
        @test_throws TypeInstabilityError g((1, 2))
    else
        @test g((1, 2)) == 2.0
    end
end

end
