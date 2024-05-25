using TestItems: @testitem
using TestItemRunner

@testitem "smoke test" begin
    using DispatchDoctor
    @stable f(x) = x
    @test f(1) == 1
end
@testitem "with error" begin
    using DispatchDoctor
    @stable f(x) = x > 0 ? x : 1.0

    # Will catch type instability:
    if VERSION >= DispatchDoctor.JULIA_LOWER_BOUND &&
        VERSION < DispatchDoctor.JULIA_UPPER_BOUND
        @test_throws TypeInstabilityError f(1)
    else
        @test f(1) == 1
    end
    @test f(2.0) == 2.0
end
@testitem "with kwargs" begin
    using DispatchDoctor
    @stable f(x; a=1, b=2) = x + a + b
    @test f(1) == 4
    @stable g(; a=1) = a > 0 ? a : 1.0
    if VERSION >= DispatchDoctor.JULIA_LOWER_BOUND &&
        VERSION < DispatchDoctor.JULIA_UPPER_BOUND
        @test_throws TypeInstabilityError g()
    else
        @test g() == 1
    end
    @test g(; a=2.0) == 2.0
end
@testitem "tuple args" begin
    using DispatchDoctor
    @stable f((x, y); a=1, b=2) = x + y + a + b
    @test f((1, 2)) == 6
    @test f((1, 2); b=3) == 7
    @stable g((x, y), z=1.0; c=2.0) = x > 0 ? y : c + z
    @test g((1, 2.0)) == 2.0
    if VERSION >= DispatchDoctor.JULIA_LOWER_BOUND &&
        VERSION < DispatchDoctor.JULIA_UPPER_BOUND
        @test_throws TypeInstabilityError g((1, 2))
    else
        @test g((1, 2)) == 2.0
    end
end
@testitem "showerror" begin
    using DispatchDoctor

    # no args or kwargs
    @stable f1() = rand() > 0 ? 1.0 : 0

    # only args:
    @stable f2(x) = x > 0 ? x : 0.0

    # only kwargs:
    @stable f3(; a) = a > 0 ? a : 0.0

    # args and kwargs:
    @stable f4(x; a) = x > 0 ? x : a

    # Stable calls:
    @test f2(1.0) == 1.0
    @test f3(; a=1.0) == 1.0
    @test f4(2.0; a=1.0) == 2.0
    if VERSION >= v"1.9" &&
        VERSION >= DispatchDoctor.JULIA_LOWER_BOUND &&
        VERSION < DispatchDoctor.JULIA_UPPER_BOUND
        @test_throws TypeInstabilityError f1()
        @test_throws TypeInstabilityError f2(0)
        @test_throws TypeInstabilityError f3(a=0)
        @test_throws TypeInstabilityError f4(0; a=0.0)

        @test_throws(
            "TypeInstabilityError: Type instability detected in function `f1`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f1()
        )
        @test_throws(
            "TypeInstabilityError: Type instability detected in function `f2` with arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f2(0)
        )

        @test_throws(
            "TypeInstabilityError: Type instability detected in function `f3` with keyword arguments `@NamedTuple{a::Int64}`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f3(a=0)
        )

        @test_throws(
            "TypeInstabilityError: Type instability detected in function `f4` with arguments `(Int64,)` and keyword arguments `@NamedTuple{a::Float64}`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f4(0; a=0.0)
        )
    end
end
@testitem "Miscellaneous" begin
    using DispatchDoctor: DispatchDoctor as DD
    @test_throws ErrorException DD.extract_symb(:([1, 2]))
    if VERSION >= v"1.9"
        @test_throws "Unexpected: head=" DD.extract_symb(:([1, 2]))
    end
end
@testitem "Code quality (Aqua.jl)" begin
    using DispatchDoctor
    using Aqua

    Aqua.test_all(DispatchDoctor)
end
@testitem "Code linting (JET.jl)" begin
    using DispatchDoctor
    using JET

    if VERSION >= v"1.10"
        JET.test_package(DispatchDoctor; target_defined_modules=true)
    end
end
@testitem "llvm ir" begin
    using PerformanceTestTools: @include

    @include("llvm_ir_tests.jl")
    # Important to run the LLVM IR tests in a new
    # julia process with things like --code-coverage disabled.
    # See https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697/14?u=milescranmer
end

@run_package_tests
