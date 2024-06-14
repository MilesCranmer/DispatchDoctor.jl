var documenterSearchIndex = {"docs":
[{"location":"reference/#Reference","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/#Macros","page":"Reference","title":"Macros","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"@stable\n@unstable","category":"page"},{"location":"reference/#DispatchDoctor._Macros.@stable","page":"Reference","title":"DispatchDoctor._Macros.@stable","text":"@stable [options...] [code_block]\n\nA macro to enforce type stability in functions. When applied, it ensures that the return type of the function is concrete. If type instability is detected, a TypeInstabilityError is thrown.\n\nOptions\n\ndefault_mode::String=\"error\":\nChange the default mode from \"error\" to \"warn\" to only emit a warning, or \"disable\" to disable type instability checks by default.\nTo locally or globally override the mode for a package that uses DispatchDoctor, you can use the \"instability_check\" key in your LocalPreferences.toml (typically configured with Preferences.jl).\ndefault_codegen_level::String=\"debug\":\nSet the code generation level to \"min\" to only generate a single function body for each stabilized function. The default, \"debug\", generates an entire duplicate function so that @code_warntype can be used.\nTo locally or globally override the code generation level for a package that uses DispatchDoctor, you can use the \"instability_check_codegen_level\" key in your LocalPreferences.toml.\ndefault_union_limit::Int=1:\nSets the maximum elements in a union to be considered stable. The default is 1, meaning that all unions are considered unstable. A value of 2 would indicate that Union{Float32,Float64} is considered stable, but Union{Float16,Float32,Float64} is not.\nTo locally or globally override the union limit for a package that uses DispatchDoctor, you can use the \"instability_check_union_limit\" key in your LocalPreferences.toml.\n\nExample\n\nusing DispatchDoctor: @stable\n\n@stable function relu(x)\n    if x > 0\n        return x\n    else\n        return 0.0\n    end\nend\n\nwhich will automatically flag any type instability:\n\njulia> relu(1.0)\n1.0\n\njulia> relu(0)\nERROR: TypeInstabilityError: Instability detected in function `relu`\nwith arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,\nwhich is not a concrete type.\n\nExtended help\n\nYou may also apply @stable to arbitrary blocks of code, such as begin or module, and have it be applied to all functions. (Just note that this skips closure functions.)\n\nusing DispatchDoctor: @stable\n\n@stable begin\n    f(x) = x\n    g(x) = x > 0 ? x : 0.0\n    @unstable begin\n        g(x::Int) = x > 0 ? x : 0.0\n    end\n    module A\n        h(x) = x\n        include(\"myfile.jl\")\n    end\nend\n\nThis @stable will apply to f, g, h, as well as all functions within myfile.jl. It skips the definition g(x::Int), meaning that when Int input is provided to g, type instability is not detected.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#DispatchDoctor._Macros.@unstable","page":"Reference","title":"DispatchDoctor._Macros.@unstable","text":"@unstable [code_block]\n\nA no-op macro to hide blocks of code from @stable.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#Utilities","page":"Reference","title":"Utilities","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"If you wish to turn off @stable for a single function call, you can use allow_unstable:","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"allow_unstable","category":"page"},{"location":"reference/#DispatchDoctor._RuntimeChecks.allow_unstable","page":"Reference","title":"DispatchDoctor._RuntimeChecks.allow_unstable","text":"allow_unstable(f::F) where {F<:Function}\n\nGlobally disable type DispatchDoctor instability checks within the provided function f.\n\nThis function allows you to execute a block of code where type instability checks are disabled. It ensures that the checks are re-enabled after the block is executed, even if an error occurs.\n\nThis function uses a ReentrantLock and will throw an error if used from two tasks at once.\n\nUsage\n\nallow_unstable() do\n    # do unstable stuff\nend\n\nArguments\n\nf::F: A function to be executed with type instability checks disabled.\n\nReturns\n\nThe result of the function f.\n\nNotes\n\nYou cannot call allow_unstable from two tasks at once. An error will be thrown if you try to do so.\n\n\n\n\n\n","category":"function"},{"location":"reference/","page":"Reference","title":"Reference","text":"@stable will normally interact with macros by propagating them to the function definition as well as the function simulator. If you would like to change this behavior, or declare a macro as being incompatible with @stable, you can use register_macro!:","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"register_macro!","category":"page"},{"location":"reference/#DispatchDoctor._Interactions.register_macro!","page":"Reference","title":"DispatchDoctor._Interactions.register_macro!","text":"register_macro!(macro_name::Symbol, behavior::MacroInteractions)\n\nRegister a macro with a specified behavior in the MACRO_BEHAVIOR list.\n\nThis function adds a new macro and its associated behavior to the global list that tracks how macros should be treated when encountered during the stabilization process. The behavior can be one of CompatibleMacro, IncompatibleMacro, or DontPropagateMacro, which influences how the @stable macro interacts with the registered macro.\n\nThe default behavior for @stable is to assume CompatibleMacro unless explicitly declared.\n\nArguments\n\nmacro_name::Symbol: The symbol representing the macro to register.\nbehavior::MacroInteractions: The behavior to associate with the macro, which dictates how it should be handled.\n\nExamples\n\nusing DispatchDoctor: register_macro!, IncompatibleMacro\n\nregister_macro!(Symbol(\"@mymacro\"), IncompatibleMacro)\n\n\n\n\n\n","category":"function"},{"location":"reference/#Internals","page":"Reference","title":"Internals","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"DispatchDoctor.type_instability","category":"page"},{"location":"reference/#DispatchDoctor._Utils.type_instability","page":"Reference","title":"DispatchDoctor._Utils.type_instability","text":"type_instability(T::Type)\n\nReturns true if this type is not concrete. Will also return false for Union{}, so that errors can propagate.\n\n\n\n\n\n","category":"function"},{"location":"#DispatchDoctor","page":"Home","title":"DispatchDoctor 🩺","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The doctor's orders: no type instability allowed!","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: Dev) (Image: Build Status) (Image: Coverage) (Image: Aqua QA) (Image: )","category":"page"},{"location":"#Usage","page":"Home","title":"Usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package provides the @stable macro to enforce that functions have type stable return values.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using DispatchDoctor: @stable\n\n@stable function relu(x)\n    if x > 0\n        return x\n    else\n        return 0.0\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Calling this function will throw an error for any type instability:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> relu(1.0)\n1.0\n\njulia> relu(0)\nERROR: TypeInstabilityError: Instability detected in function `relu`\nwith arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,\nwhich is not a concrete type.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Code which is type stable should safely compile away the check:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @stable f(x) = x;","category":"page"},{"location":"","page":"Home","title":"Home","text":"with @code_llvm f(1):","category":"page"},{"location":"","page":"Home","title":"Home","text":"define i64 @julia_f_12055(i64 signext %\"x::Int64\") #0 {\ntop:\n  ret i64 %\"x::Int64\"\n}","category":"page"},{"location":"","page":"Home","title":"Home","text":"Meaning there is zero overhead on this type stability check.","category":"page"},{"location":"","page":"Home","title":"Home","text":"You can use @stable on blocks of code, including begin-end blocks, module, and anonymous functions. The inverse of @stable is @unstable which turns it off:","category":"page"},{"location":"","page":"Home","title":"Home","text":"@stable begin\n\n    f() = rand(Bool) ? 0 : 1.0\n    f(x) = x\n\n    module A\n        # Will apply to code inside modules:\n        g(; a, b) = a + b\n\n        # Will recursively apply to included files:\n        include(\"myfile.jl\")\n\n        module B\n            # as well as nested submodules!\n\n            # `@unstable` inverts `@stable`:\n            using DispatchDoctor: @unstable\n            @unstable h() = rand(Bool) ? 0 : 1.0\n\n            # This can also apply to code blocks:\n            @unstable begin\n                h(x::Int) = rand(Bool) ? 0 : 1.0\n                # ^ And target specific methods\n            end\n        end\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"All methods in the block will be wrapped with the type stability check:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> f()\nERROR: TypeInstabilityError: Instability detected in function `f`.\nInferred to be `Union{Float64, Int64}`, which is not a concrete type.","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Tip: you cannot import or define macros within a begin...end block, unless it is at the \"top level\" of a submodule. So, if you are wrapping the contents of a package, you should either import any macros outside of @stable begin...end, or put them into a submodule.)","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Tip 2: in the REPL, you must wrap modules with @eval, because the REPL has special handling of the module keyword.)","category":"page"},{"location":"","page":"Home","title":"Home","text":"You can disable stability errors for a single scope with the allow_unstable context:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @stable f(x) = x > 0 ? x : 0.0\n\njulia> allow_unstable() do\n           f(1)\n       end\n1","category":"page"},{"location":"","page":"Home","title":"Home","text":"although this will error if you try to use it simultaneously from two separate threads.","category":"page"},{"location":"#Options","page":"Home","title":"Options","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"You can provide the following options to @stable:","category":"page"},{"location":"","page":"Home","title":"Home","text":"default_mode::String=\"error\":\nChange the default mode from \"error\" to \"warn\" to only emit a warning, or \"disable\" to disable type instability checks by default.\nTo locally or globally override the mode for a package that uses DispatchDoctor, you can use the \"instability_check\" key in your LocalPreferences.toml (typically configured with Preferences.jl).\ndefault_codegen_level::String=\"debug\":\nSet the code generation level to \"min\" to only generate a single function body for each stabilized function. The default, \"debug\", generates an entire duplicate function so that @code_warntype can be used.\nTo locally or globally override the code generation level for a package that uses DispatchDoctor, you can use the \"instability_check_codegen_level\" key in your LocalPreferences.toml.\ndefault_union_limit::Int=1:\nSets the maximum elements in a union to be considered stable. The default is 1, meaning that all unions are considered unstable. A value of 2 would indicate that Union{Float32,Float64} is considered stable, but Union{Float16,Float32,Float64} is not.\nTo locally or globally override the union limit for a package that uses DispatchDoctor, you can use the \"instability_check_union_limit\" key in your LocalPreferences.toml.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Each of these is denoted a default_ because you may set them globally or at a per-package level with Preferences.jl (see below).","category":"page"},{"location":"#Usage-in-packages","page":"Home","title":"Usage in packages","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"You might find it useful to only enable @stable during unit-testing, to have it check every function in a library, but not throw errors for downstream users. You may also want to have warnings instead of errors.","category":"page"},{"location":"","page":"Home","title":"Home","text":"For this, use the default_mode keyword to set the default behavior:","category":"page"},{"location":"","page":"Home","title":"Home","text":"module MyPackage\nusing DispatchDoctor\n@stable default_mode=\"disable\" begin\n\n# Entire package code\n\nend\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"\"disable\" as the mode will turn @stable into a no-op, so that DispatchDoctor has no effect on your code by default.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The mode is configurable via Preferences.jl, meaning that, within your test/runtests.jl, you could add a line before importing your package:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Preferences: set_preferences!\n\nset_preferences!(\"MyPackage\", \"instability_check\" => \"error\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"You can also set to be \"warn\" if you would just like warnings.","category":"page"},{"location":"","page":"Home","title":"Home","text":"You might also find it useful to set the default_codegen_level parameter to \"min\" instead of the default \"debug\". This will result in no code duplication, improving precompilation time (although @code_warntype and error messages will be less useful). As with the default_mode, you can configure the codegen level with Preferences.jl by using the \"instability_check_codegen_level\" key.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that for code coverage to work as expected over stabilized code, you will also need to use default_codegen_level=\"min\".","category":"page"},{"location":"#Special-Cases","page":"Home","title":"Special Cases","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"[!NOTE] There are several scenarios and special cases for which type instabilities will be ignored: (1) during precompilation, (2) in supported Julia versions, (3) when loading code changes with Revise.jl*, and (4) within certain code blocks and function types. These are discussed below.","category":"page"},{"location":"","page":"Home","title":"Home","text":"During precompilation.\nIn unsupported Julia versions.\nWhen loading code changes with Revise.jl*.\n*Basically, @stable will attempt to travel through any include's. However, if you edit the included file and load the changes with Revise.jl, instability checks will get stripped (see Revise#634). The result will be that the @stable will be ignored.\nWithin certain code blocks and function types:\nWithin an @unstable block\nWithin a @generated block","category":"page"},{"location":"","page":"Home","title":"Home","text":"- Within a `quote ... end` block\n- Within a `macro ... end` block\n- Within an incompatible macro, such as\n\t- `@eval`\n\t- `@generated`\n\t- `@assume_effects`\n\t- `@pure`\n\t- Or anything else registered as incompatible with `register_macro!`\n- Parameterized functions like `MyType{T}(args...) = ...`\n- Functions with an expression-based name like `(::MyType)(args...) = ...`\n- A function inside another function (a closure).\n\t- But note the outer function will still be stabilized. So, e.g., `@stable f(x) = map(xi -> xi^2, x)` would stabilize `f`, but not `xi -> xi^2`. Though if `xi -> xi^2` were unstable, `f` would likely be as well, and it would get caught!","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that you can safely use @stable over all of these cases, it will simply be ignored. Although, if you use @stable internally in some of these cases, like calling @stable within a function on a closure, such as directly on the xi -> xi^2, then it can still apply.","category":"page"},{"location":"#Eliminating-Type-Instabilities","page":"Home","title":"Eliminating Type Instabilities","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Say that you start using @stable and you run into a type instability error. What then? How should you fix it?","category":"page"},{"location":"","page":"Home","title":"Home","text":"The first thing you can try is using @code_warntype on the function in question, which will highlight each individual variable's type with a special color for any instabilities.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that some of the lines you will see are from DispatchDoctor's inserted code. If those are bothersome, you can disable the checking with Preferences.set_preferences!(\"MyPackage\", \"instability_check\" => \"disable\") followed by restarting Julia.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Other, much more powerful options to try include Cthulhu.jl and JET.jl, which can provide more detailed type instability reports in an easier-to-read format than @code_warntype. Both packages can also descend into your function calls to help you locate the source of the instability.","category":"page"},{"location":"#Caveats","page":"Home","title":"Caveats","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Using @stable is likely to increase precompilation time. (To reduce this effect, try the default_codegen_level above)\nUsing @stable over an entire package may result in flagging type instabilities on small functions that act as aliases and may otherwise be inlined by the Julia compiler. Try putting @unstable on any suspected such functions if needed.","category":"page"},{"location":"#Credits","page":"Home","title":"Credits","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Many thanks to @chriselrod and @thofma for tips on this discord thread.","category":"page"}]
}
