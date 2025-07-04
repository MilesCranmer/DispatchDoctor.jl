"""This module contains functions for modifying stabilized-functions at runtime"""
module _RuntimeChecks

using .._Errors: AllowUnstableDataRace

"""To avoid errors and warnings during precompilation."""
@inline is_precompiling() = ccall(:jl_generating_output, Cint, ()) == 1

"""To locally enable/disable instability checks."""
@inline function checking_enabled()
    return !is_precompiling() && INSTABILITY_CHECK_ENABLED.value[]
end

const INSTABILITY_CHECK_ENABLED = (; value=Ref(true), lock=ReentrantLock())

"""
    allow_unstable(f::F) where {F<:Function}

Globally disable type DispatchDoctor instability checks within the provided function `f`.

This function allows you to execute a block of code where type instability
checks are disabled. It ensures that the checks are re-enabled after the block
is executed, even if an error occurs.

This function uses a `ReentrantLock` and will throw an error if used from
two tasks at once.

# Usage

```
allow_unstable() do
    # do unstable stuff
end
```

# Arguments

- `f::F`: A function to be executed with type instability checks disabled.

# Returns

- The result of the function `f`.

# Notes

You cannot call `allow_unstable` from two tasks at once. An error
will be thrown if you try to do so.
"""
@inline function allow_unstable(f::F) where {F<:Function}
    successful_lock = trylock(INSTABILITY_CHECK_ENABLED.lock)
    if !successful_lock
        throw(
            AllowUnstableDataRace(
                "You cannot call `allow_unstable` from two tasks at once. " *
                "This error is a result of `INSTABILITY_CHECK_ENABLED` " *
                "being locked by another task.",
            ),
        )
    end
    old_value = INSTABILITY_CHECK_ENABLED.value[]
    INSTABILITY_CHECK_ENABLED.value[] = false
    out = try
        f()
    finally
        INSTABILITY_CHECK_ENABLED.value[] = old_value
        unlock(INSTABILITY_CHECK_ENABLED.lock)
    end
    return out
end

end
