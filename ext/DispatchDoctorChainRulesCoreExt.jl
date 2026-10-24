module DispatchDoctorChainRulesCoreExt

using ChainRulesCore: @ignore_derivatives, @non_differentiable
import DispatchDoctor._RuntimeChecks: is_precompiling, checking_enabled
import DispatchDoctor._Stabilization: _show_warning, _construct_pairs
import DispatchDoctor._Utils:
    specializing_typeof,
    map_specializing_typeof,
    _promote_op,
    type_instability,
    type_instability_limit_unions

# Issue #32
@non_differentiable _show_warning(::Any...)
@non_differentiable _construct_pairs(::Any...)

# Issue #46
@non_differentiable specializing_typeof(::Any)
@non_differentiable map_specializing_typeof(::Any...)
@non_differentiable _promote_op(::Any...)
@non_differentiable type_instability(::Any...)
@non_differentiable type_instability_limit_unions(::Any...)

# foreigncall expressions
@non_differentiable is_precompiling()
@non_differentiable checking_enabled()

end
