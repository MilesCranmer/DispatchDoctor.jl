module DispatchDoctorChainRulesCoreExt

using ChainRulesCore: @non_differentiable
import DispatchDoctor._Generated: _generated_instability_info
import DispatchDoctor._RuntimeChecks: is_precompiling, checking_enabled
import DispatchDoctor._Stabilization: _show_warning, _construct_pairs
import DispatchDoctor._Utils:
    specializing_typeof,
    map_specializing_typeof,
    type_instability,
    type_instability_limit_unions

# Issue #32
@non_differentiable _show_warning(::Any...)
@non_differentiable _construct_pairs(::Any...)

# Issue #46
@non_differentiable specializing_typeof(::Any)
@non_differentiable map_specializing_typeof(::Any...)
@non_differentiable _generated_instability_info(::Any...)
@non_differentiable type_instability(::Any...)
@non_differentiable type_instability_limit_unions(::Any...)

# foreigncall expressions
@non_differentiable is_precompiling()
@non_differentiable checking_enabled()

end
