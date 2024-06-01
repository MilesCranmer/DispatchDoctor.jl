<div align="center">

# DispatchDoctor 🩺

*The doctor's orders: no type instability allowed!*

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/DispatchDoctor.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/DispatchDoctor.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MilesCranmer/DispatchDoctor.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/DispatchDoctor.jl/badge.svg?branch=main)](https://coveralls.io/github/MilesCranmer/DispatchDoctor.jl?branch=main)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![](https://img.shields.io/badge/%F0%9F%9B%A9%EF%B8%8F_tested_with-JET.jl-ffffff)](https://github.com/aviatesk/JET.jl)

</div>

## Usage

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

You can also use `@stable` on blocks of code,
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

### Usage in packages

You might find it useful to *only* enable `@stable` during unit-testing,
to have it check every function in a library, but not throw errors for
downstream users. You may also want to have warnings instead of errors.

For this, you can use the `default_mode` keyword to set the
default behavior:

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
meaning that, within your `test/runtests.jl`, you could add a line:

```julia
using Preferences: set_preferences!

set_preferences!("MyPackage", "instability_check" => "error")
```

You can also set to be `"warn"` if you would just like warnings.

You might find that `@stable` doubles the precompilation time of
your library, as it duplicates each function body for simulation.
The duplication is not necessary, however, its main purpose is to
make `@code_warntype` and other static analysis tools print information
about the original function.

If you have no need for these utilities, or only want them for testing but not production,
you can set the `default_codegen_level` parameter to `"min"` instead of
the default `"debug"`. This will result in no code duplication.

As with the `default_mode`, you can configure the codegen level with Preferences.jl
by using the `"instability_check_codegen"` key.


You can also disable stability errors for a single scope
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

### Additional notes

Note that instability errors are automatically skipped during precompilation.

> [!NOTE]
> `@stable` will have no effect on code if it is:
> - Within an `@unstable` block
> - Within a macro
> - A function inside another function (a closure)
> - A generated function
> - Within an `@eval` statement
> - Within a `quote` block
> - If the function name is an expression (such as parameterized functions like `MyType{T}(args...) = ...`)
>
> You can safely use `@stable` over all of these cases, it will simply be ignored.
> Although, if you use `@stable` *internally* in any of these cases, (like calling `@stable` *within* a function on a closure), then it might still apply.
>
> Also, `@stable` has no effect on code in unsupported Julia versions.

## Eliminating Type Instabilities

Say that you start using `@stable` and you run into a type instability error.
What then? How should you fix it?

The first thing you can try is using `@code_warntype` on the
function in question, which will highlight each individual variable's
type with a special color for any instabilities.

Note that some of the lines you will see are from DispatchDoctor's inserted
code. If those are bothersome, you can disable the checking with
`Preferences.set_preferences!("MyPackage", "instability_check" => "disable")`
followed by restarting Julia.

Other, much more powerful options to try include
[Cthulhu.jl](https://github.com/JuliaDebug/Cthulhu.jl) and
[JET.jl](https://github.com/aviatesk/JET.jl/), which can
provide more detailed type instability reports in an easier-to-read
format than `@code_warntype`. Both packages can also descend into
your function calls to help you locate the source of the instability.

## Credits

Many thanks to @chriselrod and @thofma for tips on this
[discord thread](https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697).
