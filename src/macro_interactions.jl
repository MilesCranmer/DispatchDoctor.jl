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
    table=Dict{Tuple{Symbol,Union{Module,Nothing}},MacroInteractions}([
        (Symbol("@stable"), nothing) => IncompatibleMacro,             # <self>
        # ^ We don't want to stabilize a function twice.
        (Symbol("@unstable"), nothing) => IncompatibleMacro,           # <self>
        # ^ This is the purpose of `@unstable`
        (Symbol("@doc"), nothing) => DontPropagateMacro,               # Core
        # ^ Base.@__doc__ takes care of this.
        (Symbol("@assume_effects"), nothing) => IncompatibleMacro,     # Base
        # ^ Some effects are incompatible, like
        #   :nothrow, so this requires much more
        #   work to get working. TODO.
        (Symbol("@enum"), nothing) => IncompatibleMacro,               # Base
        # ^ TODO. Seems to interact.
        (Symbol("@eval"), nothing) => IncompatibleMacro,               # Base
        # ^ Too much flexibility to apply,
        #   and user could always use `@eval`
        #   inside function.
        (Symbol("@deprecate"), nothing) => IncompatibleMacro,          # Base
        # ^ TODO. Seems to interact.
        (Symbol("@generated"), nothing) => IncompatibleMacro,          # Base
        # ^ In principle this is compatible but
        #   needs additional logic to work.
        (Symbol("@opaque"), nothing) => IncompatibleMacro,             # Base.Experimental
        # ^ TODO. Seems to interact.
        (Symbol("@kwdef"), nothing) => IncompatibleMacro,              # Base
        # ^ TODO. Seems to interact.
        (Symbol("@pure"), nothing) => IncompatibleMacro,               # Base
        # ^ See `@assume_effects`.
        (Symbol("@everywhere"), nothing) => DontPropagateMacro,        # Distributed
        # ^ Prefer to have block passed to workers
        #   only a single time. And `@everywhere`
        #   works with blocks of code, so it is
        #   fine.
        (Symbol("@model"), nothing) => IncompatibleMacro,              # Turing
        # ^ Fairly common macro used to define
        #   probabilistic models. The syntax is
        #   incompatible with `@stable`.
        (Symbol("@capture"), nothing) => IncompatibleMacro,            # MacroTools
        # ^ Similar to `@model`.
    ]),
    lock=Threads.SpinLock(),
)

function _normalize_scope(scope::Union{Module,Nothing})
    return scope === nothing ? nothing : Base.moduleroot(scope)
end

function get_macro_behavior(_, calling_module::Module)
    return CompatibleMacro
end
get_macro_behavior(ex) = get_macro_behavior(ex, Core.Main)
function get_macro_behavior(ex::Symbol, calling_module::Module)
    root = Base.moduleroot(calling_module)
    Base.@lock MACRO_BEHAVIOR.lock get(
        MACRO_BEHAVIOR.table,
        (ex, root),
        get(MACRO_BEHAVIOR.table, (ex, nothing), CompatibleMacro),
    )
end
function get_macro_behavior(ex::QuoteNode, calling_module::Module)
    return get_macro_behavior(ex.value, calling_module)
end
function get_macro_behavior(ex::Expr, calling_module::Module)
    parts = map(x -> get_macro_behavior(x, calling_module), ex.args)
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
    register_macro!(
        macro_name::Symbol,
        behavior::MacroInteractions,
        scope::Union{Module,Nothing}=nothing,
    )

Register a macro with a specified behavior in the `MACRO_BEHAVIOR` list.

This function adds a new macro and its associated behavior to the global list that
tracks how macros should be treated when encountered during the stabilization
process. The behavior can be one of `CompatibleMacro`, `IncompatibleMacro`, or `DontPropagateMacro`,
which influences how the `@stable` macro interacts with the registered macro.

The default behavior for `@stable` is to assume `CompatibleMacro` unless explicitly declared.

# Arguments
- `macro_name::Symbol`: The symbol representing the macro to register.
- `behavior::MacroInteractions`: The behavior to associate with the macro, which dictates how it should be handled.
- `scope::Union{Module,Nothing}=nothing`: The scope in which this behavior applies.
  - `scope=nothing`: Match all modules (global).
  - `scope::Module`: Match only within `Base.moduleroot(scope)` (and all of its submodules).

# Examples
```julia
using DispatchDoctor: register_macro!, IncompatibleMacro

register_macro!(Symbol("@mymacro"), IncompatibleMacro)

# Scoped to a particular package root:
register_macro!(Symbol("@mymacro"), IncompatibleMacro, @__MODULE__)
```
"""
function register_macro!(
    macro_name::Symbol,
    behavior::MacroInteractions,
    scope::Union{Module,Nothing}=nothing,
)
    scope = _normalize_scope(scope)
    Base.@lock MACRO_BEHAVIOR.lock begin
        if haskey(MACRO_BEHAVIOR.table, (macro_name, scope))
            error(
                "Macro `$macro_name` already registered with behavior $(MACRO_BEHAVIOR.table[(macro_name, scope)]).",
            )
        end
        MACRO_BEHAVIOR.table[(macro_name, scope)] = behavior
        MACRO_BEHAVIOR.table[(macro_name, scope)]
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
