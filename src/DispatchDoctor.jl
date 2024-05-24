module DispatchDoctor

export @stable

using MacroTools: combinedef, splitdef
using Test: Test
using TestItems: @testitem

macro stable(fex)
    return esc(_stable(fex))
end

function _stable(fex::Expr)
    fdef = splitdef(fex)
    closure_func = gensym("closure_func")
    fdef[:body] = quote
        let $(closure_func)() = $(fdef[:body])
            $(Test).@inferred $(closure_func)()
        end
    end

    return combinedef(fdef)
end

@testitem "smoke test" begin
    using DispatchDoctor
    @stable f(x) = x
    @test f(1) == 1
end
@testitem "with error" begin
    using DispatchDoctor
    @stable f(x) = x > 0 ? x : 1.0

    # Will catch type instability:
    @test_throws ErrorException f(1)
    @test f(2.0) == 2.0
end
@testitem "with kwargs" begin
    using DispatchDoctor
    @stable f(x; a=1, b=2) = x + a + b
    @test f(1) == 4
    @stable g(; a=1) = a > 0 ? a : 1.0
    @test_throws ErrorException g()
    @test g(; a=2.0) == 2.0
end

end
