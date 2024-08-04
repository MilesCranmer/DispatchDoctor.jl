module DispatchDoctorEnzymeCoreExt

using EnzymeCore: EnzymeRules as ER
using DispatchDoctor._RuntimeChecks: is_precompiling, checking_enabled
using DispatchDoctor._Stabilization: _show_warning, _construct_pairs
using DispatchDoctor._Utils:
    specializing_typeof,
    map_specializing_typeof,
    _promote_op,
    type_instability,
    type_instability_limit_unions

ER.inactive_noinl(::typeof(_show_warning), ::Any...) = nothing
ER.inactive_noinl(::typeof(_construct_pairs), ::Any...) = nothing

ER.inactive_noinl(::typeof(specializing_typeof), ::Any) = nothing
ER.inactive_noinl(::typeof(map_specializing_typeof), ::Any...) = nothing
ER.inactive_noinl(::typeof(_promote_op), ::Any...) = nothing
ER.inactive_noinl(::typeof(type_instability), ::Any...) = nothing
ER.inactive_noinl(::typeof(type_instability_limit_unions), ::Any...) = nothing

ER.inactive_noinl(::typeof(is_precompiling), ::Any...) = nothing
ER.inactive_noinl(::typeof(checking_enabled), ::Any...) = nothing

end
