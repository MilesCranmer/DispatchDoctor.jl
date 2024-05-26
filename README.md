<div align="center">

# DispatchDoctor 🩺

*The doctor's orders: no type instability allowed!*

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/DispatchDoctor.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/DispatchDoctor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MilesCranmer/DispatchDoctor.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/DispatchDoctor.jl/badge.svg?branch=main)](https://coveralls.io/github/MilesCranmer/DispatchDoctor.jl?branch=main)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![](https://img.shields.io/badge/%F0%9F%9B%A9%EF%B8%8F_tested_with-JET.jl-ffffff)](https://github.com/aviatesk/JET.jl)

</div>

This package provides the `@stable` macro
to enforce that a function has a type stable
return value.

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

which will then throw an error for any type instability:

```julia
julia> relu(1.0)
1.0

julia> relu(0)
ERROR: TypeInstabilityError: Instability detected in function `relu`
with arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,
which is not a concrete type.
```

Code which is type stable should safely compile away the check:

```julia
julia> @stable f(x) = x;
```

leaving `@code_llvm f(1)`:

```llvm
define i64 @julia_f_12055(i64 signext %"x::Int64") #0 {
top:
  ret i64 %"x::Int64"
}
```

and thus meaning there is zero overhead on the type stability check.

You can also use `@stable` on entire modules:

```julia
@stable module A
    using DispatchDoctor: @unstable

    @unstable f1() = rand(Bool) ? 0 : 1.0
    f2(x) = x
    f3(; a=1) = a > 0 ? a : 0.0
end
```

where we use `@unstable` to mark functions that should not be wrapped.

(*Tip: in the REPL, wrap this with `@eval`, because the REPL has special handling of the `module` keyword.*)

This gives us:

```julia
julia> A.f1()
0

julia> A.f2(1.0)
1.0

julia> A.f3(a=2)
ERROR: TypeInstabilityError: Instability detected in function `f3`
with keyword arguments `@NamedTuple{a::Int64}`. Inferred to be
`Union{Float64, Int64}`, which is not a concrete type.
```

where we can see that the `@stable` was automatically applied
to all the functions, except for `f1`.

> [!NOTE]
> This will automatically propagate apply through any `include` within the module,
> by overwriting the default method.

## Credits

Many thanks to @chriselrod and @thofma for tips on this
[discord thread](https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697).
