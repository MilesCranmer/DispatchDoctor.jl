module DispatchDoctor

export @stable, @unstable, allow_unstable, TypeInstabilityError, register_macro!

include("utils.jl")
include("errors.jl")
include("printing.jl")
include("runtime_checks.jl")
include("preferences.jl")
include("macro_behavior.jl")
include("stabilization.jl")
include("macros.jl")

using ._Utils: extract_symbol, JULIA_OK, Unknown, specializing_typeof
using ._Errors: TypeInstabilityError, TypeInstabilityWarning, AllowUnstableDataRace
using ._Preferences
using ._Printing
using ._MacroBehavior:
    MACRO_BEHAVIOR,
    MacroBehavior,
    CompatibleMacro,
    IncompatibleMacro,
    DontPropagateMacro,
    register_macro!,
    get_macro_behavior
using ._RuntimeChecks: INSTABILITY_CHECK_ENABLED, allow_unstable, is_precompiling
using ._Stabilization: _stable, _stabilize_all, _stabilize_fnc, _stabilize_module
using ._Macros: @stable, @unstable

using TestItems: @testitem

end
