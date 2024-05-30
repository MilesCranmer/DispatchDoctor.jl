var documenterSearchIndex = {"docs":
[{"location":"reference/#Reference","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/#Macros","page":"Reference","title":"Macros","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"@stable\n@unstable","category":"page"},{"location":"reference/#DispatchDoctor._Macros.@stable","page":"Reference","title":"DispatchDoctor._Macros.@stable","text":"@stable [options...] [code_block]\n\nA macro to enforce type stability in functions. When applied, it ensures that the return type of the function is concrete. If type instability is detected, a TypeInstabilityError is thrown.\n\nOptions\n\ndefault_mode::String=\"error\": Change the default mode to \"warn\" to only emit a warning, or  \"disable\" to disable type instability checks by default. To locally set the mode for  a package that uses DispatchDoctor, you can use the \"instability_check\" key in your  LocalPreferences.toml (typically configured with Preferences.jl)\n\nExample\n\nusing DispatchDoctor: @stable\n\n@stable function relu(x)\n    if x > 0\n        return x\n    else\n        return 0.0\n    end\nend\n\nwhich will automatically flag any type instability:\n\njulia> relu(1.0)\n1.0\n\njulia> relu(0)\nERROR: TypeInstabilityError: Instability detected in function `relu`\nwith arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,\nwhich is not a concrete type.\n\nExtended help\n\nYou may also apply @stable to arbitrary blocks of code, such as begin or module, and have it be applied to all functions. (Just note that this skips closure functions.)\n\nusing DispatchDoctor: @stable\n\n@stable begin\n    f(x) = x\n    g(x) = x > 0 ? x : 0.0\n    @unstable begin\n        g(x::Int) = x > 0 ? x : 0.0\n    end\n    module A\n        h(x) = x\n        include(\"myfile.jl\")\n    end\nend\n\nThis @stable will apply to f, g, h, as well as all functions within myfile.jl. It skips the definition g(x::Int), meaning that when Int input is provided to g, type instability is not detected.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#DispatchDoctor._Macros.@unstable","page":"Reference","title":"DispatchDoctor._Macros.@unstable","text":"@unstable [code_block]\n\nA no-op macro to hide blocks of code from @stable.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#Utilities","page":"Reference","title":"Utilities","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"If you wish to turn off @stable for a single function call, you can use allow_unstable:","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"allow_unstable","category":"page"},{"location":"reference/#DispatchDoctor._RuntimeChecks.allow_unstable","page":"Reference","title":"DispatchDoctor._RuntimeChecks.allow_unstable","text":"allow_unstable(f::F) where {F<:Function}\n\nGlobally disable type DispatchDoctor instability checks within the provided function f.\n\nThis function allows you to execute a block of code where type instability checks are disabled. It ensures that the checks are re-enabled after the block is executed, even if an error occurs.\n\nThis function uses a ReentrantLock and will throw an error if used from two tasks at once.\n\nUsage\n\nallow_unstable() do\n    # do unstable stuff\nend\n\nArguments\n\nf::F: A function to be executed with type instability checks disabled.\n\nReturns\n\nThe result of the function f.\n\nNotes\n\nYou cannot call allow_unstable from two tasks at once. An error will be thrown if you try to do so.\n\n\n\n\n\n","category":"function"},{"location":"reference/","page":"Reference","title":"Reference","text":"@stable will normally interact with macros by propagating them to the function definition as well as the function simulator. If you would like to change this behavior, or declare a macro as being incompatible with @stable, you can use register_macro!:","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"register_macro!","category":"page"},{"location":"reference/#DispatchDoctor._MacroInteractions.register_macro!","page":"Reference","title":"DispatchDoctor._MacroInteractions.register_macro!","text":"register_macro!(macro_name::Symbol, behavior::MacroInteractions)\n\nRegister a macro with a specified behavior in the MACRO_BEHAVIOR list.\n\nThis function adds a new macro and its associated behavior to the global list that tracks how macros should be treated when encountered during the stabilization process. The behavior can be one of CompatibleMacro, IncompatibleMacro, or DontPropagateMacro, which influences how the @stable macro interacts with the registered macro.\n\nThe default behavior for @stable is to assume CompatibleMacro unless explicitly declared.\n\nArguments\n\nmacro_name::Symbol: The symbol representing the macro to register.\nbehavior::MacroInteractions: The behavior to associate with the macro, which dictates how it should be handled.\n\nExamples\n\nusing DispatchDoctor: register_macro!, IncompatibleMacro\n\nregister_macro!(Symbol(\"@mymacro\"), IncompatibleMacro)\n\n\n\n\n\n","category":"function"},{"location":"reference/#Internals","page":"Reference","title":"Internals","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"DispatchDoctor.type_instability","category":"page"},{"location":"reference/#DispatchDoctor._Utils.type_instability","page":"Reference","title":"DispatchDoctor._Utils.type_instability","text":"type_instability(T::Type)\n\nReturns true if this type is not concrete. Will also return false for Union{}, so that errors can propagate.\n\n\n\n\n\n","category":"function"},{"location":"#DispatchDoctor","page":"Home","title":"DispatchDoctor 🩺","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The doctor's orders: no type instability allowed!","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: Dev) (Image: Build Status) (Image: Coverage) (Image: Aqua QA) (Image: )","category":"page"},{"location":"#Usage","page":"Home","title":"Usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package provides the @stable macro to enforce that functions have type stable return values.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using DispatchDoctor: @stable\n\n@stable function relu(x)\n    if x > 0\n        return x\n    else\n        return 0.0\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Calling this function will throw an error for any type instability:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> relu(1.0)\n1.0\n\njulia> relu(0)\nERROR: TypeInstabilityError: Instability detected in function `relu`\nwith arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`,\nwhich is not a concrete type.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Code which is type stable should safely compile away the check:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @stable f(x) = x;","category":"page"},{"location":"","page":"Home","title":"Home","text":"with @code_llvm f(1):","category":"page"},{"location":"","page":"Home","title":"Home","text":"define i64 @julia_f_12055(i64 signext %\"x::Int64\") #0 {\ntop:\n  ret i64 %\"x::Int64\"\n}","category":"page"},{"location":"","page":"Home","title":"Home","text":"Meaning there is zero overhead on this type stability check.","category":"page"},{"location":"","page":"Home","title":"Home","text":"You can also use @stable on blocks of code, including begin-end blocks, module, and anonymous functions. The inverse of @stable is @unstable which turns it off:","category":"page"},{"location":"","page":"Home","title":"Home","text":"@stable begin\n\n    f() = rand(Bool) ? 0 : 1.0\n    f(x) = x\n\n    module A\n        # Will apply to code inside modules:\n        g(; a, b) = a + b\n\n        # Will recursively apply to included files:\n        include(\"myfile.jl\")\n\n        module B\n            # as well as nested submodules!\n\n            # `@unstable` inverts `@stable`:\n            using DispatchDoctor: @unstable\n            @unstable h() = rand(Bool) ? 0 : 1.0\n\n            # This can also apply to code blocks:\n            @unstable begin\n                h(x::Int) = rand(Bool) ? 0 : 1.0\n                # ^ And target specific methods\n            end\n        end\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"All methods in the block will be wrapped with the type stability check:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> f()\nERROR: TypeInstabilityError: Instability detected in function `f`.\nInferred to be `Union{Float64, Int64}`, which is not a concrete type.","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Tip: you cannot import or define macros within a begin...end block, unless it is at the \"top level\" of a submodule. So, if you are wrapping the contents of a package, you should either import any macros outside of @stable begin...end, or put them into a submodule.)","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Tip 2: in the REPL, you must wrap modules with @eval, because the REPL has special handling of the module keyword.)","category":"page"},{"location":"","page":"Home","title":"Home","text":"You might find it useful to only enable @stable during unit-testing, to have it check every function in a library, but not throw errors for downstream users. For this, you can use the default_mode keyword to set the default behavior:","category":"page"},{"location":"","page":"Home","title":"Home","text":"module MyPackage\nusing DispatchDoctor\n@stable default_mode=\"disable\" begin\n\n# Entire package code\n\nend\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"This sets the default behavior, but the mode is configurable via Preferences.jl:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Preferences: set_preferences!\n\nset_preferences!(\"MyPackage\", \"instability_check\" => \"error\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"which you might like to add at the beginning of your test/runtests.jl. You can also set to be \"warn\" if you would just like warnings.","category":"page"},{"location":"","page":"Home","title":"Home","text":"You can also disable stability errors for a single scope with the allow_unstable context:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> @stable f(x) = x > 0 ? x : 0.0\n\njulia> allow_unstable() do\n           f(1)\n       end\n1","category":"page"},{"location":"","page":"Home","title":"Home","text":"although this will error if you try to use it simultaneously from two separate threads.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that instability errors are automatically skipped during precompilation.","category":"page"},{"location":"","page":"Home","title":"Home","text":"[!NOTE] @stable will have no effect on code if it is:Within an @unstable block\nWithin a macro\nA function inside another function (a closure)\nA generated function\nWithin an @eval statement\nWithin a quote block\nIf the function name is an expression (such as parameterized functions like MyType{T}(args...) = ...)You can safely use @stable over all of these cases, it will simply be ignored. Although, if you use @stable internally in any of these cases, (like calling @stable within a function on a closure), then it might still apply.Also, @stable has no effect on code in unsupported Julia versions.","category":"page"},{"location":"#Credits","page":"Home","title":"Credits","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Many thanks to @chriselrod and @thofma for tips on this discord thread.","category":"page"}]
}
