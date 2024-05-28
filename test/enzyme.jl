"""Test that `@stable` is compatible with Enzyme"""
module EnzymeTest

using DispatchDoctor: @stable, TypeInstabilityError
using Enzyme: autodiff, Reverse, Active, Duplicated
using Suppressor: @capture_err
using Test: @testset, @test, @test_throws

@testset "basic" begin
    @stable f1(x) = x * x
    @test first(autodiff(Reverse, f1, Active(1.0))[1]) ≈ 2.0
end

@testset "arrays" begin
    @stable f_caller(x::Array{Float64}) = x[1] * x[1] + x[2] * x[1]
    @stable f(x::Array{Float64}, y::Array{Float64}) = (y[1] = f_caller(x); nothing)
    @test let x = [2.0, 2.0], bx = [0.0, 0.0], y = [0.0], by = [1.0]
        autodiff(Reverse, f, Duplicated(x, bx), Duplicated(y, by))[1]
        bx ≈ [6.0, 2.0]
    end
end

@testset "with unstable" begin
    @stable f2(x) = rand(Bool) ? x : 1.0 * x
    @test_throws TypeInstabilityError begin
        @capture_err begin
            autodiff(Reverse, f2, Active(1.0f0))
        end
    end
end

end
