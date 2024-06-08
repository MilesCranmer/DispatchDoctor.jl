module DispatchDoctorChainRulesCoreExt

using ChainRulesCore: @ignore_derivatives
import DispatchDoctor._Errors: show_warning, TypeInstabilityWarning

show_warning(w::TypeInstabilityWarning, ::Int) = (@ignore_derivatives(@warn w); nothing)

end
