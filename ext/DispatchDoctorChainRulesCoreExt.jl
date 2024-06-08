module DispatchDoctorChainRulesCoreExt

using ChainRulesCore: @ignore_derivatives, @non_differentiable
import DispatchDoctor._Errors: show_warning, TypeInstabilityWarning
import DispatchDoctor._Stabilization: _construct_pairs

show_warning(w::TypeInstabilityWarning, ::Int) = (@ignore_derivatives(@warn w); nothing)

@non_differentiable _construct_pairs(::Any...)

end
