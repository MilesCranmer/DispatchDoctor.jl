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
    @test_throws TypeInstabilityError f(1)
    @test f(2.0) == 2.0
end
@testitem "with kwargs" begin
    using DispatchDoctor
    @stable f(x; a=1, b=2) = x + a + b
    @test f(1) == 4
    @stable g(; a=1) = a > 0 ? a : 1.0
    @test_throws TypeInstabilityError g(a=1)
    @test g(; a=2.0) == 2.0
end
@testitem "tuple args" begin
    using DispatchDoctor
    @stable f((x, y); a=1, b=2) = x + y + a + b
    @test f((1, 2)) == 6
    @test f((1, 2); b=3) == 7
    @stable g((x, y), z=1.0; c=2.0) = x > 0 ? y : c + z
    @test g((1, 2.0)) == 2.0
    @test_throws TypeInstabilityError g((1, 2))
end
@testitem ":: args" begin
    using DispatchDoctor

    @stable f(x::Int) = x
    @test f(1) == 1
    @stable g(; x::Int) = x
    @test g(; x=1) == 1
    @stable h(x::Number; y::Number) = x > y ? x : y
    @test h(1; y=2) == 2
    @test_throws TypeInstabilityError h(1; y=2.0)
end
@testitem "Type specialization" begin
    using DispatchDoctor
    @stable f(a, t::Type{T}) where {T} = sum(a; init=zero(T))
    @test f([1.0f0, 1.0f0], Float32) == 2.0f0
end
@testitem "args and kwargs" begin
    using DispatchDoctor
    # Without the dots
    @stable f1(a, args::Vararg) = sum(args) + a
    @test f1(1, 1, 2, 3) == 7

    # With the dots
    @stable f2(a, args...) = sum(args) + a
    @test f2(1, 1, 2, 3) == 7

    # With kwargs
    @stable f3(c; kwargs...) = sum(values(kwargs)) + c
    @test f3(1; a=1, b=2, c=3) == 7

    # With both
    @stable f4(a, args...; d, kwargs...) = sum(args) + sum(values(kwargs)) + a + d
    @test f4(1, 1, 2, 3; d=0, a=1, b=2, c=3) == sum((1, 1, 2, 3, 0, 1, 2, 3))
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
    if VERSION >= v"1.9"
        @test_throws TypeInstabilityError f1()
        @test_throws TypeInstabilityError f2(0)
        @test_throws TypeInstabilityError f3(a=0)
        @test_throws TypeInstabilityError f4(0; a=0.0)

        @test_throws(
            "TypeInstabilityError: Instability detected in function `f1`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f1()
        )
        @test_throws(
            "TypeInstabilityError: Instability detected in function `f2` with arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f2(0)
        )

        @test_throws(
            "TypeInstabilityError: Instability detected in function `f3` with keyword arguments `@NamedTuple{a::Int64}`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f3(a=0)
        )

        @test_throws(
            "TypeInstabilityError: Instability detected in function `f4` with arguments `(Int64,)` and keyword arguments `@NamedTuple{a::Float64}`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f4(0; a=0.0)
        )
    end
end
@testitem "Test forwarding documentation" begin
    using DispatchDoctor

    """Docs for my function."""
    function f1(x)
        return x
    end

    """Docs for my stable function."""
    @stable function f2(x)
        return x
    end

    # TODO: Julia 1.11's @doc acting weird so we skip it
    if VERSION < v"1.11.0-DEV.0"
        @test strip(string(@doc(f1))) == "Docs for my function."
        @test strip(string(@doc(f2))) == "Docs for my stable function."
    end
end
@testitem "Signature without symbol" begin
    using DispatchDoctor: DispatchDoctor as DD
    @stable f(::Type{T}) where {T} = rand(Bool) ? 0.0 : 1
    @test_throws TypeInstabilityError f(Int)
    if VERSION >= v"1.9"
        @test_throws "TypeInstabilityError: Instability detected in function `f` with arguments `([undefined symbol],)`." f(
            Int
        )
    end
end
@testitem "modules" begin
    using DispatchDoctor
    @stable module Amodules
    f1(x) = x
    f2(; a=1) = a > 0 ? a : 0.0
    function f3()
        return rand(Bool) ? 0.0 : 1
    end
    end

    @test Amodules.f1(1) == 1
    @test Amodules.f2(; a=1.0) == 1.0
    @test_throws TypeInstabilityError Amodules.f2(a=1)
    @test_throws TypeInstabilityError Amodules.f3()
end
@testitem "module with include" begin
    using DispatchDoctor
    (path, io) = mktemp()
    println(io, "f(x) = x > 0 ? x : 0.0")
    close(io)

    @eval @stable module Amodulewithinclude
    include($path)
    end

    @test Amodulewithinclude.f(1.0) == 1.0
    @test_throws TypeInstabilityError Amodulewithinclude.f(1)
end
@testitem "closures not wrapped in module version" begin
    using DispatchDoctor: @stable
    @stable module Aclosuresunwrapped
    function f(x)
        closure() = rand(Bool) ? 0 : 1.0
        print(devnull, closure())
        return x
    end
    end

    # If it wrapped the closure, this would have thrown an error!
    @test Aclosuresunwrapped.f(1) == 1
end
@testitem "avoid double stable in module" begin
    using DispatchDoctor: _stable_module
    using MacroTools: postwalk, @capture

    #! format: off
    ex = _stable_module(:(module Aavoiddouble
        using DispatchDoctor: @stable

        @stable f(x) = x > 0 ? x : 0.0
        g(x, y) = x > 0 ? y : 0.0
    end), warnonly=false)
    #! format: on

    # First, we capture `f` using postwalk and `@capture`
    f_defs = []
    #! format: off
    postwalk(ex) do ex_part
        if @capture(ex_part, (f_(args__) = body_) | (function f_(args__) body_ end))
            push!(f_defs, ex_part)
        end
        ex_part
    end
    #! format: on

    # We should be able to find a g_closure, but NOT
    # an f_closure (indicating the `@stable` has not
    # been expanded yet)
    @test length(f_defs) == 4  # The 4th is the `include`

    @test any(e -> occursin("g_closure", string(e)), f_defs)
    @test !any(e -> occursin("f_closure", string(e)), f_defs)

    eval(ex)

    @test Aavoiddouble.f(1.0) == 1.0
    @test Aavoiddouble.g(1.0, 0.0) == 0.0
    @test_throws TypeInstabilityError Aavoiddouble.f(0)
    @test_throws TypeInstabilityError Aavoiddouble.g(1.0, 0)
end
@testitem "allow unstable within module" begin
    using DispatchDoctor

    @stable module Aallowunstable
    using DispatchDoctor: @unstable

    g() = f()
    @unstable f() = rand(Bool) ? 0 : 1.0
    end

    @test Aallowunstable.f() in (0, 1.0)
    @test_throws TypeInstabilityError Aallowunstable.g()
end
@testitem "warnings" begin
    using DispatchDoctor
    using Suppressor: @capture_err
    #! format: off
    @stable warnonly=true function f(x)
        x > 0 ? x : 0.0
    end
    #! format: on

    msg = @capture_err f(1)
    @test occursin("TypeInstabilityWarning", msg)

    # The second call will not emit a warning,
    # as maxlog=1
    msg = @capture_err f(1)
    @test !occursin("TypeInstabilityWarning", msg)
end
@testitem "Miscellaneous" begin
    using DispatchDoctor: DispatchDoctor as DD
    @test DD.extract_symb(:([1, 2])) == DD.Unknown()
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
