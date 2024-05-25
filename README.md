<div align="center">

# DispatchDoctor

*The doctor's orders: no type instability allowed!*

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

Code which is stable should safely compile away the check:

```julia
julia> @stable f(x) = x;
```

where `@code_llvm f(1)` will output:

```llvm
define i64 @julia_f_12055(i64 signext %"x::Int64") #0 {
top:
  ret i64 %"x::Int64"
}
```

Note that `@stable` acts as a no-op on Julia versions which are either not tested
or known to be incompatible.

## Credits

Many thanks to @chriselrod for performance tips on this [discord thread](https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697).
