<div align="center">

# DispatchDoctor 🩺

*The doctor's orders: no type instability allowed!*


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

Note that `@stable` acts as a no-op on Julia versions which are either not tested
or known to be incompatible.

## Credits

Many thanks to @chriselrod for performance tips on this [discord thread](https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697).
