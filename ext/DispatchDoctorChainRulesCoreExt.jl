module DispatchDoctorChainRulesCoreExt

using ChainRulesCore: @ignore_derivatives, @non_differentiable
import DispatchDoctor._Stabilization: _show_warning, _construct_pairs

@non_differentiable _show_warning(::Any...)
@non_differentiable _construct_pairs(::Any...)

end
