"""This module describes interactions between `@stable` and other macros and functions"""
module _Interactions

"""
An enum to describe the behavior of macros when interacting with `@stable`.

- `CompatibleMacro`: Propagate macro through to both function and simulator.
- `DontPropagateMacro`: Do not propagate macro; leave it at the outer block.
- `IncompatibleMacro`: Skip the contents of this macro completely.
"""
@enum MacroInteractions begin
    CompatibleMacro
    DontPropagateMacro
    IncompatibleMacro
end

# Macros we dont want to propagate
const MACRO_BEHAVIOR = (;
    table=Dict([
        Symbol("@stable") => IncompatibleMacro,             # <self>
        # ^ We don't want to stabilize a function twice.
        Symbol("@unstable") => IncompatibleMacro,           # <self>
        # ^ This is the purpose of `@unstable`
        Symbol("@doc") => DontPropagateMacro,               # Core
        # ^ Base.@__doc__ takes care of this.
        Symbol("@assume_effects") => IncompatibleMacro,     # Base
        # ^ Some effects are incompatible, like
        #   :nothrow, so this requires much more
        #   work to get working. TODO.
        Symbol("@enum") => IncompatibleMacro,               # Base
        # ^ TODO. Seems to interact.
        Symbol("@eval") => IncompatibleMacro,               # Base
        # ^ Too much flexibility to apply,
        #   and user could always use `@eval`
        #   inside function.
        Symbol("@deprecate") => IncompatibleMacro,          # Base
        # ^ TODO. Seems to interact.
        Symbol("@generated") => IncompatibleMacro,          # Base
        # ^ In principle this is compatible but
        #   needs additional logic to work.
        Symbol("@opaque") => IncompatibleMacro,             # Base.Experimental
        # ^ TODO. Seems to interact.
        Symbol("@kwdef") => IncompatibleMacro,              # Base
        # ^ TODO. Seems to interact.
        Symbol("@pure") => IncompatibleMacro,               # Base
        # ^ See `@assume_effects`.
        Symbol("@everywhere") => DontPropagateMacro,        # Distributed
        # ^ Prefer to have block passed to workers
        #   only a single time. And `@everywhere`
        #   works with blocks of code, so it is
        #   fine.
        Symbol("@model") => IncompatibleMacro,              # Turing
        # ^ Fairly common macro used to define
        #   probabilistic models. The syntax is
        #   incompatible with `@stable`.
        Symbol("@capture") => IncompatibleMacro,            # MacroTools
        # ^ Similar to `@model`.
    ]),
    lock=Threads.SpinLock(),
)
function get_macro_behavior(_)
    return CompatibleMacro
end
function get_macro_behavior(ex::Symbol)
    Base.@lock MACRO_BEHAVIOR.lock get(MACRO_BEHAVIOR.table, ex, CompatibleMacro)
end
function get_macro_behavior(ex::QuoteNode)
    return get_macro_behavior(ex.value)
end
function get_macro_behavior(ex::Expr)
    parts = map(get_macro_behavior, ex.args)
    return reduce(combine_behavior, parts; init=CompatibleMacro)
end

function combine_behavior(a::MacroInteractions, b::MacroInteractions)
    if a == CompatibleMacro && b == CompatibleMacro
        return CompatibleMacro
    elseif a == IncompatibleMacro || b == IncompatibleMacro
        return IncompatibleMacro
    else
        return DontPropagateMacro
    end
end

"""
    register_macro!(macro_name::Symbol, behavior::MacroInteractions)

Register a macro with a specified behavior in the `MACRO_BEHAVIOR` list.

This function adds a new macro and its associated behavior to the global list that
tracks how macros should be treated when encountered during the stabilization
process. The behavior can be one of `CompatibleMacro`, `IncompatibleMacro`, or `DontPropagateMacro`,
which influences how the `@stable` macro interacts with the registered macro.

The default behavior for `@stable` is to assume `CompatibleMacro` unless explicitly declared.

# Arguments
- `macro_name::Symbol`: The symbol representing the macro to register.
- `behavior::MacroInteractions`: The behavior to associate with the macro, which dictates how it should be handled.

# Examples
```julia
using DispatchDoctor: register_macro!, IncompatibleMacro

register_macro!(Symbol("@mymacro"), IncompatibleMacro)
```
"""
function register_macro!(macro_name::Symbol, behavior::MacroInteractions)
    Base.@lock MACRO_BEHAVIOR.lock begin
        if haskey(MACRO_BEHAVIOR.table, macro_name)
            error(
                "Macro `$macro_name` already registered with behavior $(MACRO_BEHAVIOR.table[macro_name]).",
            )
        end
        MACRO_BEHAVIOR.table[macro_name] = behavior
        MACRO_BEHAVIOR.table[macro_name]
    end
end

"""
    ignore_function(f)

Globally ignore certain functions when stabilizing.
By default, a few functions in Base are ignored, as they are meant to
be unstable, and will (hopefully) always be inlined by the compiler.
"""
@inline ignore_function(f) = false
@inline function ignore_function(
    ::Union{map(typeof, (iterate, getproperty, setproperty!))...}
)
    return true
end

end
