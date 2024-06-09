"""Test that `@stable` is compatible with Zygote"""
module ZygoteTest

using DispatchDoctor: @stable, TypeInstabilityError
using Zygote: gradient
using Test

# Issue https://github.com/MilesCranmer/DispatchDoctor.jl/issues/32
@stable default_mode = "warn" f(x) = x * x

@test gradient(f, 1.0) == (2.0,)

# Still want errors to show up:
@stable default_mode = "error" g(x) = x > 0 ? x : 0
@test_throws TypeInstabilityError gradient(g, 1.0)

end
