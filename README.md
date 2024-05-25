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

which will then throw an error for
any type instability:

```julia
julia> relu(1.0)
1.0

julia> relu(0)
ERROR: TypeInstabilityError: Type instability detected
in function relu with arguments (0,). Inferred to be
Union{Float64, Int64}, which is not a concrete type.
Stacktrace:
 [1] #_stable_wrap#1
   @ ~/PermaDocuments/DispatchDoctor.jl/src/DispatchDoctor.jl:39 [inlined]
 [2] _stable_wrap
   @ ~/PermaDocuments/DispatchDoctor.jl/src/DispatchDoctor.jl:32 [inlined]
 [3] relu(x::Int64)
   @ Main ~/PermaDocuments/DispatchDoctor.jl/src/DispatchDoctor.jl:65
 [4] top-level scope
   @ REPL[7]:1
```
