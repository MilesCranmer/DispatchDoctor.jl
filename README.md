<div align="center">

# DispatchDoctor 🩺

*The doctor's orders: no type instability allowed!*

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ai.damtp.cam.ac.uk/dispatchdoctor/dev/)
[![Build Status](https://github.com/MilesCranmer/DispatchDoctor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MilesCranmer/DispatchDoctor.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/MilesCranmer/DispatchDoctor.jl/branch/main/graph/badge.svg?token=tCOvkJPPDY)](https://codecov.io/gh/MilesCranmer/DispatchDoctor.jl)

[![DispatchDoctor](https://img.shields.io/badge/%F0%9F%A9%BA_tested_with-DispatchDoctor.jl-blue?labelColor=white)](https://github.com/MilesCranmer/DispatchDoctor.jl)

</div>

## 💊 Usage

This package provides the `@stable` macro
to enforce that functions have type stable return values.

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

Calling this function will throw an error for any type instability:

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

with `@code_llvm f(1)`:

```llvm
define i64 @julia_f_12055(i64 signext %"x::Int64") #0 {
top:
  ret i64 %"x::Int64"
}
```

Meaning there is zero overhead on this type stability check.
(This may not always be true, so be sure to try the workflow in [usage in packages](#-usage-in-packages))

You can use `@stable` on blocks of code,
including `begin-end` blocks, `module`, and anonymous functions.
The inverse of `@stable` is `@unstable` which turns it off:

```julia
@stable begin

    f() = rand(Bool) ? 0 : 1.0
    f(x) = x

    module A
        # Will apply to code inside modules:
        g(; a, b) = a + b

        # Will recursively apply to included files:
        include("myfile.jl")

        module B
            # as well as nested submodules!

            # `@unstable` inverts `@stable`:
            using DispatchDoctor: @unstable
            @unstable h() = rand(Bool) ? 0 : 1.0

            # This can also apply to code blocks:
            @unstable begin
                h(x::Int) = rand(Bool) ? 0 : 1.0
                # ^ And target specific methods
            end
        end
    end
end
```

All methods in the block will be wrapped with the type stability check:

```julia
julia> f()
ERROR: TypeInstabilityError: Instability detected in function `f`.
Inferred to be `Union{Float64, Int64}`, which is not a concrete type.
```

(*Tip: you cannot import or define macros within a `begin...end` block, unless it is at the "top level" of a submodule. So, if you are wrapping the contents of a package, you should either import any macros outside of `@stable begin...end`, or put them into a submodule.*)

(*Tip 2: in the REPL, you must wrap modules with `@eval`, because the REPL has special handling of the `module` keyword.*)

You can disable stability errors for a single scope
with the `allow_unstable` context:

```julia
julia> @stable f(x) = x > 0 ? x : 0.0

julia> allow_unstable() do
           f(1)
       end
1
```

although this will error if you try to use it simultaneously
from two separate threads.

### 🧪 Options

You can provide the following options to `@stable`:

- `default_mode::String="error"`:
  - Change the default mode from `"error"` to `"warn"` to only emit a warning, or `"disable"` to disable type instability checks by default.
  - To locally or globally override the mode for a package that uses DispatchDoctor, you can use the `"dispatch_doctor_mode"` key in your LocalPreferences.toml (typically configured with Preferences.jl).
- `default_codegen_level::String="debug"`:
  - Set the code generation level to `"min"` to only generate a single function body for each stabilized function. The default, `"debug"`, generates an entire duplicate function so that `@code_warntype` can be used.
  - To locally or globally override the code generation level for a package that uses DispatchDoctor, you can use the `"dispatch_doctor_codegen_level"` key in your LocalPreferences.toml.
- `default_union_limit::Int=1`:
  - Sets the maximum elements in a union to be considered stable. The default is `1`, meaning that all unions are considered unstable. A value of `2` would indicate that `Union{Float32,Float64}` is considered stable, but `Union{Float16,Float32,Float64}` is not.
  - To locally or globally override the union limit for a package that uses DispatchDoctor, you can use the `"dispatch_doctor_union_limit"` key in your LocalPreferences.toml.

Each of these is denoted a `default_` because you may set them globally or at a per-package level with `Preferences.jl` (see below).

### 🚑 Usage in packages

You might find it useful to *only* enable `@stable` during unit-testing,
to have it check every function in a library, but not throw errors for
downstream users. You may also want to have warnings instead of errors.

For this, use the `default_mode` keyword to set the default behavior:

```julia
module MyPackage
using DispatchDoctor
@stable default_mode="disable" begin

# Entire package code

end
end
```

`"disable"` as the mode will turn `@stable` into a *no-op*, so that
DispatchDoctor has no effect on your code by default.

The mode is configurable
via [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl),
meaning that, within your `test/runtests.jl`, you could add a line **before importing your package**:

```julia
using Preferences: set_preferences!

set_preferences!("MyPackage", "dispatch_doctor_mode" => "error")
```

You can also set to be `"warn"` if you would just like warnings.

You might also find it useful to set
the `default_codegen_level` parameter to `"min"` instead of
the default `"debug"`. This will result in no code duplication,
improving precompilation time (although `@code_warntype` and error
messages will be less useful).
As with the `default_mode`, you can configure the codegen level with Preferences.jl
by using the `"dispatch_doctor_codegen_level"` key.

Note that for code coverage to work as expected over stabilized code,
you will also need to use `default_codegen_level="min"`.

## 🔬 Special Cases

> [!NOTE]
> There are several scenarios and special cases for which type instabilities will be ignored. These are discussed below.

1. **During precompilation.**
2. **In unsupported Julia versions** (currently only [1.10.0, 1.12.0) are active)
3. **When loading code changes with Revise.jl\*.**
   - \*Basically, `@stable` will attempt to travel through any `include`'s. However, if you edit the included file and load the changes with Revise.jl, instability checks will get stripped (see [Revise#634](https://github.com/timholy/Revise.jl/issues/634)). The result will be that the `@stable` will be ignored.
4. **Within certain code blocks and function types:**
    - Within an `@unstable` block
    - Within a `@generated` block
    - Within any function containing a `@nospecialize` macro
	- Within a `quote ... end` block
	- Within a `macro ... end` block
	- Within an incompatible macro, such as
		- `@eval`
		- `@assume_effects`
		- `@pure`
		- Or anything else registered as incompatible with `register_macro!`
	- Parameterized functions like `MyType{T}(args...) = ...`
	- Functions with an expression-based name like `(::MyType)(args...) = ...`
	- A function inside another function (a closure).
		- But note the outer function will still be stabilized. So, e.g., `@stable f(x) = map(xi -> xi^2, x)` would stabilize `f`, but not `xi -> xi^2`. Though if `xi -> xi^2` were unstable, `f` would likely be as well, and it would get caught!

Note that you can safely use `@stable` over all of these cases, and special cases will automatically be skipped. Although, if you use `@stable` internally in some of these cases, like calling `@stable` within a function on a closure, such as directly on the `xi -> xi^2`, then it can still apply.



## 🩹 Eliminating Type Instabilities

Say that you start using `@stable` and you run into a type instability error.
What then? How should you fix it?

The first thing you can try is using `@code_warntype` on the
function in question, which will highlight each individual variable's
type with a special color for any instabilities.

Note that some of the lines you will see are from DispatchDoctor's inserted
code. If those are bothersome, you can disable the checking with
`Preferences.set_preferences!("MyPackage", "dispatch_doctor_mode" => "disable")`
followed by restarting Julia.

Other, much more powerful options to try include
[Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl) and
[JET.jl](https://github.com/aviatesk/JET.jl/), which can
provide more detailed type instability reports in an easier-to-read
format than `@code_warntype`. Both packages can also descend into
your function calls to help you locate the source of the instability.

## 🦠 Caveats

- Using `@stable` is likely to increase precompilation time. (To reduce this effect, try the `default_codegen_level` above)
- Using `@stable` over an entire package may result in flagging type instabilities on small functions that act as aliases and may otherwise be inlined by the Julia compiler. Try putting `@unstable` on any suspected such functions if needed.

## 🧑‍⚕️ Credits

Many thanks to @chriselrod and @thofma for tips on this
[discourse thread](https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697).
