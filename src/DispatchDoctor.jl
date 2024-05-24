module DispatchDoctor

export @stable

using MacroTools: combinedef, splitdef
using Test: _inferred
using TestItems: @testitem

macro stable(fdef)
    fdef = splitdef(esc(fdef))

    fdef_caller = deepcopy(fdef)

    fdef[:body] = _inferred(fdef[:body], __module__)

    return combinedef(fdef)
end

@testitem "stable" begin
    using MacroTools: splitdef
    @show splitdef(:(f(x) = x))
end

end
