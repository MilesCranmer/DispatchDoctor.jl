module DispatchDoctor

export @stable, @unstable, allow_unstable, TypeInstabilityError, register_macro!

include("utils.jl")
include("errors.jl")
include("printing.jl")
include("runtime_checks.jl")
include("preferences.jl")
include("macro_interactions.jl")
include("parse_options.jl")
include("stabilization.jl")
include("macros.jl")

#! format: off
using ._Utils: extract_symbol, JULIA_OK, Unknown, specializing_typeof, type_instability, type_instability_limit_unions
using ._Errors: TypeInstabilityError, TypeInstabilityWarning, AllowUnstableDataRace
using ._Preferences
using ._Printing
using ._Interactions: MACRO_BEHAVIOR, MacroInteractions, CompatibleMacro, IncompatibleMacro, DontPropagateMacro, register_macro!, get_macro_behavior, ignore_function
using ._RuntimeChecks: INSTABILITY_CHECK_ENABLED, allow_unstable, is_precompiling
using ._Stabilization: _stable, _stabilize_all, _stabilize_fnc, _stabilize_module
using ._Macros: @stable, @unstable
#! format: on

end
