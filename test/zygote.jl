"""Test that `@stable` is compatible with Zygote"""
module ZygoteTest

using DispatchDoctor: @stable, TypeInstabilityError, _RuntimeChecks
using Zygote: gradient
using Test

# Issue https://github.com/MilesCranmer/DispatchDoctor.jl/issues/32
@stable default_mode = "warn" f(x) = x * x

@test gradient(f, 1.0) == (2.0,)

# Still want errors to show up:
@stable default_mode = "error" g(x) = x > 0 ? x : 0
@test_throws TypeInstabilityError gradient(g, 1.0)

# Issue https://github.com/MilesCranmer/DispatchDoctor.jl/issues/46
@stable h(x) = 1
@test_skip (@inferred gradient(h, 1.0))
# TODO: Fix Zygote inference

# Test foreign call expressions doesn't lead to errors
is_precompiling(x) = _RuntimeChecks.is_precompiling()
@test only(gradient(is_precompiling, 1.0)) === nothing

checking_enabled(x) = _RuntimeChecks.checking_enabled()
@test only(gradient(checking_enabled, 1.0)) === nothing

end
