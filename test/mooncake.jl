using DispatchDoctor: @stable, allow_unstable, TypeInstabilityError
using Mooncake: @zero_adjoint, DefaultCtx
using DifferentiationInterface: derivative, AutoMooncake
using Test

# Test that @stable functions can be defined without errors when Mooncake is loaded
@stable default_mode = "error" function foo(x)
    @noinline
    out = [x^2 for _ in 1:10]
    return rand(Bool) ? out : Float32.(out)
end
bar(x) = sum(Float64.(foo(x)))  # == 10 * x^2

@test allow_unstable(() -> foo(2.0)) == [2.0^2 for _ in 1:10]
@test allow_unstable(() -> bar(2.0)) == 10 * 2.0^2

# Should be safe to differentiate _through_ the @stable function
@test allow_unstable(() -> derivative(bar, AutoMooncake(), 2.0)) == 20 * 2.0

# We should still get instabilities detected, even with Mooncake derivatives
@test_throws TypeInstabilityError derivative(bar, AutoMooncake(), 2.0)
