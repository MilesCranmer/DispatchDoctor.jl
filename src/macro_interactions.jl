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
        (Main => Symbol("@stable")) => IncompatibleMacro,             # <self>
        # ^ We don't want to stabilize a function twice.
        (Main => Symbol("@unstable")) => IncompatibleMacro,           # <self>
        # ^ This is the purpose of `@unstable`
        (Main => Symbol("@doc")) => DontPropagateMacro,               # Core
        # ^ Base.@__doc__ takes care of this.
        (Main => Symbol("@assume_effects")) => IncompatibleMacro,     # Base
        # ^ Some effects are incompatible, like
        #   :nothrow, so this requires much more
        #   work to get working. TODO.
        (Main => Symbol("@enum")) => IncompatibleMacro,               # Base
        # ^ TODO. Seems to interact.
        (Main => Symbol("@eval")) => IncompatibleMacro,               # Base
        # ^ Too much flexibility to apply,
        #   and user could always use `@eval`
        #   inside function.
        (Main => Symbol("@deprecate")) => IncompatibleMacro,          # Base
        # ^ TODO. Seems to interact.
        (Main => Symbol("@generated")) => IncompatibleMacro,          # Base
        # ^ In principle this is compatible but
        #   needs additional logic to work.
        (Main => Symbol("@kwdef")) => IncompatibleMacro,              # Base
        # ^ TODO. Seems to interact.
        (Main => Symbol("@pure")) => IncompatibleMacro,               # Base
        # ^ See `@assume_effects`.
        (Main => Symbol("@everywhere")) => DontPropagateMacro,        # Distributed
        # ^ Prefer to have block passed to workers
        #   only a single time. And `@everywhere`
        #   works with blocks of code, so it is
        #   fine.
        (Main => Symbol("@model")) => IncompatibleMacro,              # Turing
        # ^ Fairly common macro used to define
        #   probabilistic models. The syntax is
        #   incompatible with `@stable`.
        (Main => Symbol("@capture")) => IncompatibleMacro,            # MacroTools
        # ^ Similar to `@model`.
    ]),
    lock=Threads.SpinLock(),
)
get_macro_behavior(_, _) = CompatibleMacro
function get_macro_behavior(m::Module, ex::Symbol)
    default = get(MACRO_BEHAVIOR.table, Main => ex, CompatibleMacro)
    return get(MACRO_BEHAVIOR.table, m => ex, default)
end
get_macro_behavior(m::Module, ex::QuoteNode) = get_macro_behavior(m, ex.value)
function get_macro_behavior(m::Module, ex::Expr)
    parts = map(arg -> get_macro_behavior(m, arg), ex.args)
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
