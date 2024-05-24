# DispatchDoctor

*Nature abhors type instability*

This package provides the `@stable` macro
as a more ergonomic way to use `Test.@inferred`
within a codebase:

```julia
using DispatchDoctor: @stable

@stable function f(x)
    if x > 0
        return x
    else
        return 1.0
    end
end
```

which will then throw an error for
any type instability:

```julia
julia> f(2.0)
2.0

julia> f(1)
ERROR: return type Int64 does not match inferred return type Union{Float64, Int64}
Stacktrace:
 [1] error(s::String)
   @ Base ./error.jl:35
 [2] f(x::Int64)
   @ Main ~/PermaDocuments/DispatchDoctor.jl/src/DispatchDoctor.jl:18
 [3] top-level scope
   @ REPL[4]:1
```
