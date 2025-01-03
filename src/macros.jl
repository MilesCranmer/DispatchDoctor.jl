"""This module contains the main macros for DispatchDoctor"""
module _Macros

using .._Utils: JULIA_OK
using .._Stabilization: _stable

"""
    @stable [options...] [code_block]

A macro to enforce type stability in functions.
When applied, it ensures that the return type of the function is concrete.
If type instability is detected, a `TypeInstabilityError` is thrown.

# Options

- `default_mode::String="error"`:
  - Change the default mode from `"error"` to `"warn"` to only emit a warning, or `"disable"` to disable type instability checks by default.
  - To locally or globally override the mode for a package that uses DispatchDoctor, you can use the `"dispatch_doctor_mode"` key in your LocalPreferences.toml (typically configured with Preferences.jl).
- `default_codegen_level::String="debug"`:
  - Set the code generation level to `"min"` to only generate a single function body for each stabilized function. The default, `"debug"`, generates an entire duplicate function so that `@code_warntype` can be used.
  - To locally or globally override the code generation level for a package that uses DispatchDoctor, you can use the `"dispatch_doctor_codegen_level"` key in your LocalPreferences.toml.
- `default_union_limit::Int=1`:
  - Sets the maximum elements in a union to be considered stable. The default is `1`, meaning that all unions are considered unstable. A value of `2` would indicate that `Union{Float32,Float64}` is considered stable, but `Union{Float16,Float32,Float64}` is not.
  - To locally or globally override the union limit for a package that uses DispatchDoctor, you can use the `"dispatch_doctor_union_limit"` key in your LocalPreferences.toml.


# Example
    
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

which will automatically flag any type instability:

```julia
julia> relu(1.0)
1.0

julia> relu(0)
ERROR: TypeInstabilityError: Instability detected in function `relu`
with arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,
which is not a concrete type.
```

# Extended help

You may also apply `@stable` to arbitrary blocks of code, such as `begin`
or `module`, and have it be applied to all functions.
(Just note that this skips closure functions.)

```julia
using DispatchDoctor: @stable

@stable begin
    f(x) = x
    g(x) = x > 0 ? x : 0.0
    @unstable begin
        g(x::Int) = x > 0 ? x : 0.0
    end
    module A
        h(x) = x
        include("myfile.jl")
    end
end
```

This `@stable` will apply to `f`, `g`, `h`,
as well as all functions within `myfile.jl`.
It skips the definition `g(x::Int)`, meaning
that when `Int` input is provided to `g`,
type instability is not detected.

"""
macro stable(args...)
    if JULIA_OK
        return esc(_stable(args...; source_info=__source__, calling_module=__module__))
    else
        return esc(args[end])
    end
end

"""
    @unstable [code_block]

A no-op macro to hide blocks of code from `@stable`.
"""
macro unstable(fex)
    return esc(fex)
end

end
