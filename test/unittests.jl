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
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)
    @test f(2.0) == 2.0
end
@testitem "with kwargs" begin
    using DispatchDoctor
    @stable f(x; a=1, b=2) = x + a + b
    @test f(1) == 4
    @stable g(; a=1) = a > 0 ? a : 1.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g(a=1)
    @test g(; a=2.0) == 2.0
end
@testitem "tuple args" begin
    using DispatchDoctor
    @stable f((x, y); a=1, b=2) = x + y + a + b
    @test f((1, 2)) == 6
    @test f((1, 2); b=3) == 7
    @stable g((x, y), z=1.0; c=2.0) = x > 0 ? y : c + z
    @test g((1, 2.0)) == 2.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g((1, 2))
end
@testitem ":: args" begin
    using DispatchDoctor

    @stable f(x::Int) = x
    @test f(1) == 1
    @stable g(; x::Int) = x
    @test g(; x=1) == 1
    @stable h(x::Number; y::Number) = x > y ? x : y
    @test h(1; y=2) == 2
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError h(1; y=2.0)
end
@testitem "Type specialization" begin
    using DispatchDoctor
    @stable f(a, ::Type{T}) where {T} = sum(a; init=zero(T))
    @test f([1.0f0, 1.0f0], Float32) == 2.0f0
end
@testitem "args and kwargs" begin
    using DispatchDoctor
    # Without the dots
    @stable f1(a, args::Vararg) = sum(args) + a
    @test f1(1, 1, 2, 3) == 7

    # Without the dots, with curly on Vararg
    @stable f1(a, args::Vararg{Any,M}) where {M} = sum(args) + a
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
@testitem "complex arg without symbol" begin
    using DispatchDoctor: DispatchDoctor as DD
    struct Undefined end
    DD.@stable function f(::Type{T1}=Undefined) where {T1}
        return T1
    end
    @test f() == Undefined
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
    if DispatchDoctor.JULIA_OK
        @test_throws TypeInstabilityError f1()
        @test_throws TypeInstabilityError f2(0)
        @test_throws TypeInstabilityError f3(a=0)
        @test_throws TypeInstabilityError f4(0; a=0.0)

        @test_throws(
            "Inferred to be `Union{Float64, Int64}`, which is not a concrete type.", f1()
        )
        @test_throws(
            "with arguments `(Int64,)`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
            f2(0)
        )

        @test_throws(
            "TypeInstabilityError: Instability detected in `f4` defined at ", f4(0; a=0.0)
        )
        if VERSION >= v"1.10.0-DEV.0"
            @test_throws(
                "with keyword arguments `@NamedTuple{a::Int64}`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
                f3(a=0)
            )
            @test_throws(
                "with arguments `(Int64,)` and keyword arguments `@NamedTuple{a::Float64}`. Inferred to be `Union{Float64, Int64}`, which is not a concrete type.",
                f4(0; a=0.0)
            )
        end
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
    using DispatchDoctor
    @stable f(x, ::Type{T}) where {T} = rand(Bool) ? T : Float64
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1.0, Float32)
    if VERSION >= v"1.9"
        @test_throws("Instability detected in `f` defined at", f(1.0, Float32))
        @test_throws(
            "with arguments `(Float64, Type{Float32})` and parameters `(:T => Float32,)`.",
            f(1.0, Float32)
        )
    end
end
@testitem "showing whereparams" begin
    using DispatchDoctor
    @stable f(::Type{T}, ::A) where {T,G,A<:AbstractArray{G}} =
        rand(Bool) ? Float32 : Float64

    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(Int, [1.0, 2.0])
    if VERSION >= v"1.9"
        @test_throws "and parameters `(:T => Int64, :G => Float64, :A => Vector{Float64})`" f(
            Int, [1.0, 2.0]
        )
    end
end
@testitem "skip parameterized functions" begin
    using DispatchDoctor
    struct MyType{T} end
    @stable function MyType{T}() where {T}
        return rand(Bool) ? T : one(T)
    end
    @test MyType{Int}() in (Int, 1)
end
@testitem "skip expression-based function names" begin
    using DispatchDoctor
    using MacroTools: splitdef, @expand
    abstract type AbstractMyType{T} end
    struct MyType2{T} <: AbstractMyType{T} end
    @stable function (::Type{A})() where {A<:AbstractMyType}
        return rand(Bool) ? "blah" : 1
    end
    @test MyType2() in ("blah", 1)
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
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Amodules.f2(a=1)
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Amodules.f3()
end
@testitem "single-line module" begin
    using DispatchDoctor
    @stable module Asingleline
    f(x) = x > 0 ? x : 0.0
    end

    @test Asingleline.f(1.0) == 1.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Asingleline.f(1)
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
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Amodulewithinclude.f(1)
end
@testitem "nested modules with include" begin
    using DispatchDoctor
    (path, io) = mktemp()
    println(io, "f(x) = x > 0 ? x : 0.0")
    close(io)

    #! format: off
    @eval @stable module Anestedmoduleswithinclude
        module B
            include($path)
            h(x) = x > 0 ? x : 0.0
        end
    end
    #! format: on

    @test Anestedmoduleswithinclude.B.f(1.0) == 1.0
    @test Anestedmoduleswithinclude.B.h(1.0) == 1.0
    DispatchDoctor.JULIA_OK &&
        @test_throws TypeInstabilityError Anestedmoduleswithinclude.B.f(1)
    DispatchDoctor.JULIA_OK &&
        @test_throws TypeInstabilityError Anestedmoduleswithinclude.B.h(1)
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
    using DispatchDoctor: _stabilize_module
    using MacroTools: postwalk, @capture

    #! format: off
    ex = _stabilize_module(:(module Aavoiddouble
        using DispatchDoctor: @stable

        @stable f(x) = x > 0 ? x : 0.0
        g(x, y) = x > 0 ? y : 0.0
    end), Ref(0))
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

    # We should be able to find a g_simulator, but NOT
    # an f_simulator (indicating the `@stable` has not
    # been expanded yet)
    @test length(f_defs) == 3

    @test any(e -> occursin("g_simulator", string(e)), f_defs)
    @test !any(e -> occursin("f_simulator", string(e)), f_defs)

    eval(ex)

    @test Aavoiddouble.f(1.0) == 1.0
    @test Aavoiddouble.g(1.0, 0.0) == 0.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Aavoiddouble.f(0)
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Aavoiddouble.g(1.0, 0)
end
@testitem "allow unstable within module" begin
    using DispatchDoctor

    @stable module Aallowunstable
    using DispatchDoctor: @unstable

    g() = f()
    @unstable f() = rand(Bool) ? 0 : 1.0
    end

    @test Aallowunstable.f() in (0, 1.0)
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError Aallowunstable.g()
end
@testitem "anonymous functions" begin
    using DispatchDoctor
    using DispatchDoctor: _stabilize_fnc

    @stable f = () -> rand(Bool) ? Float32 : Float64
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f()
    if VERSION >= v"1.9"
        @test_throws " anonymous function defined at " f()
    end

    # Without source info, we just get "anonymous function"
    f2 = eval(_stabilize_fnc(:(() -> rand(Bool) ? Float32 : Float64), Ref(0)))
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f2()
    if VERSION >= v"1.9"
        @test_throws "anonymous function. Inferred" f2()
    end
end
@testitem "skip empty functions" begin
    using DispatchDoctor: _stabilize_fnc, _stabilize_all

    @test _stabilize_all(:(function donothing end), Ref(0)) == :(function donothing end)

    # TODO: Fragile test of MacroTools internals
    @test_throws AssertionError _stabilize_fnc(:(function donothing end), Ref(0))
end
@testitem "underscore argument" begin
    using DispatchDoctor
    @stable f(_) = rand(Bool) ? Float32 : Float64
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)
    if VERSION >= v"1.9"
        @test_throws "with arguments `([_],)`" f(1)
    end
end
@testitem "skip closures inside macros" begin
    using DispatchDoctor: DispatchDoctor as DD

    stabilized = DD._stabilize_all(:(macro m(ex)
        f() = rand(Bool) ? Float32 : Float64
        f()
        return ex
    end), Ref(0))

    # Should skip the internal function
    @test !occursin("f_closure", string(stabilized))
end
@testitem "skip quoted code" begin
    using DispatchDoctor
    @stable eval(
        quote
            function f(x)
                return rand(Bool) ? 1 : 1.0
            end
        end,
    )
    @test f(1) == 1
end
@testitem "warnings" begin
    using DispatchDoctor
    using Suppressor: @capture_err
    #! format: off
    @stable default_mode="warn" function f(x)
        x > 0 ? x : 0.0
    end
    #! format: on

    if DispatchDoctor.JULIA_OK
        msg = @capture_err f(1)
        @test occursin("TypeInstabilityWarning", msg)
    end
end
@testitem "disable @stable using env variable" begin
    using DispatchDoctor
    ENV["__DISPATCH_DOCTOR_TESTING_VAR"] = "disable"

    @stable default_mode = ENV["__DISPATCH_DOCTOR_TESTING_VAR"] function f(x)
        return rand(Bool) ? 1 : 1.0
    end

    @test f(1) == 1
end
@testitem "bad macro option" begin
    using DispatchDoctor
    if DispatchDoctor.JULIA_OK
        @test_throws(LoadError, @eval @stable badoption = true f(x) = x^2)
        @test_throws("Unknown macro option", @eval @stable badoption = true f(x) = x^2)
    end
end
@testitem "bad choice of mode" begin
    using DispatchDoctor
    if DispatchDoctor.JULIA_OK
        @test_throws(LoadError, @eval @stable default_mode = "bad" f(x) = x^2)
        @test_throws("Unknown mode", @eval @stable default_mode = "bad" f(x) = x^2)
    end
end
@testitem "allow errors through" begin
    using DispatchDoctor

    @stable my_bad_function(x) = x / "blah"

    @test_throws MethodError my_bad_function(1)
end
@testitem "begin block" begin
    using DispatchDoctor

    @stable begin
        f(x) = x > 0 ? x : 0.0
        g(x) = x > 0 ? x : 0.0
    end

    @test f(1.0) == 1.0
    @test g(1.0) == 1.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g(1)
end
@testitem "include within begin" begin
    using DispatchDoctor
    using Suppressor: @capture_err

    (path, io) = mktemp()
    println(io, "f(x) = x > 0 ? x : 0.0")
    close(io)

    msg = @capture_err @eval @stable begin
        include(path)
    end

    @test f(1.0) == 1.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)

    @test !occursin("`@stable` found no compatible functions to stabilize", msg)
end
@testitem "stabilizing a class instantiation" begin
    using DispatchDoctor: DispatchDoctor as DD

    struct MyStruct
        x::Number
    end

    # (There used to be an issue because the func[:name] is not a symbol)
    @stable (::Type{MyStruct})() = MyStruct(1)
    @test MyStruct() == MyStruct(1)
end
@testitem "allow unstable" begin
    using DispatchDoctor
    @stable f() = rand(Bool) ? 1 : 1.0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f()
    @test allow_unstable(f) == 1

    # Should maintain type stability if not present
    @inferred allow_unstable(@stable () -> 1.0)
end
@testitem "allow unstable with error" begin
    using DispatchDoctor
    @stable f() = 1 / "blah"
    @test_throws MethodError f()
    @test_throws MethodError allow_unstable(f)

    # Should be safely turned back on, despite the early exit
    @test DispatchDoctor.INSTABILITY_CHECK_ENABLED.value[] == true
end
@testitem "nested allow unstable" begin
    using DispatchDoctor
    @stable f() = rand(Bool) ? 1 : 1.0
    g() = allow_unstable(f)
    h() = allow_unstable(g)
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f()
    @test g() == 1
    # Because we use a reentrant lock, nested
    # calls are allowed:
    @test h() == 1
end
@testitem "error on multiple tasks" begin
    using DispatchDoctor: DispatchDoctor as DD
    host_channel = Channel()
    task_channel = Channel()
    if islocked(DD.INSTABILITY_CHECK_ENABLED.lock)
        error("Can't run this test in parallel.")
    end
    t = @async begin
        try
            lock(DD.INSTABILITY_CHECK_ENABLED.lock)
            put!(task_channel, 1)
            take!(host_channel)
        finally
            unlock(DD.INSTABILITY_CHECK_ENABLED.lock)
            put!(task_channel, 1)
        end
    end
    take!(task_channel)    # now locked
    @test_throws DD.AllowUnstableDataRace DD.allow_unstable(() -> 1)
    if VERSION >= v"1.9"
        @test_throws "You cannot call `allow_unstable` from two tasks at once" DD.allow_unstable(
            () -> 1
        )
    end
    put!(host_channel, 1)  # ready for exit
    take!(task_channel)    # now unlocked
    @test DD.allow_unstable(() -> 1) == 1
end
@testitem "closures preventing specialization" begin
    using DispatchDoctor
    @stable function g(n)
        n = Int(n)::Int
        return n
    end
    @test g(1) == 1
end
@testitem "detect closure-induced instability" begin
    using DispatchDoctor
    @stable function f(x)
        function inner()
            x = x^2
            return x
        end
        return inner()
    end
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)
end
@testitem "compat with simple expression-based function names" begin
    using DispatchDoctor
    using MacroTools: @expand, splitdef
    MyType = gensym()
    @eval struct $MyType end
    @eval @stable function Base.count(x::$MyType)
        return rand(Bool) ? 1 : 1.0
    end
    DispatchDoctor.JULIA_OK && @eval @test_throws TypeInstabilityError Base.count($MyType())
    @eval @stable function Base.:+(x::$MyType, y::$MyType)
        return rand(Bool) ? 1 : 1.0
    end
    DispatchDoctor.JULIA_OK && @eval @test_throws TypeInstabilityError $MyType() + $MyType()
end
@testitem "skip generated" begin
    using DispatchDoctor

    @stable @generated function f(x)
        return :(rand(Bool) ? x : 0.0)
    end
    @test f(0) == 0
end
@testitem "skip @propagate_inbounds" begin
    using DispatchDoctor

    @stable Base.@propagate_inbounds function f()
        return rand(Bool) ? 1 : 1.0
    end
    @test f() == 1
end
@testitem "skip global" begin
    using DispatchDoctor
    @stable struct A
        x::Int

        global _A(x::Int) = new(x)
    end
    @test _A(1).x == 1
end
@testitem "step over docstring" begin
    using DispatchDoctor

    @stable module A
    """blah"""
    f() = rand(Bool) ? 1 : 1.0
    end

    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError A.f()
end
@testitem "code_warntype compat" begin
    using DispatchDoctor
    using InteractiveUtils: code_warntype
    @stable function f(x)
        y = Tuple(x)
        sum(y[1:2])
    end
    @test f([1, 2, 3]) == 3
    msg = sprint(code_warntype, f, typeof(([1, 2, 3],)))
    msg = lowercase(msg)
    @test occursin("tuple{vararg{int64}}", msg)
end
@testitem "warn on no matches" begin
    using DispatchDoctor
    using Suppressor: @capture_err
    if DispatchDoctor.JULIA_OK
        msg = @capture_err @eval @stable @generated function f(x)
            return :(x)
        end

        @test occursin("`@stable` found no compatible functions to stabilize", msg)
        @test occursin("source_info =", msg)
        @test occursin("calling_module =", msg)
    end
end
@testitem "deprecated options" begin
    using DispatchDoctor
    using Suppressor: @capture_err
    if DispatchDoctor.JULIA_OK
        msg = @capture_err @eval @stable warnonly = true enable = true function f(x)
            return x > 0 ? x : 0.0
        end

        @test occursin("The `enable` option is deprecated", msg)
        @test occursin("The `warnonly` option is deprecated", msg)
        msg2 = @capture_err f(1)

        @test occursin("TypeInstabilityWarning", msg2)

        @stable enable = false function f(x)
            return x > 0 ? x : 0.0
        end
        @test f(0) == 0.0
    end
end
@testitem "Miscellaneous" begin
    using DispatchDoctor: DispatchDoctor as DD

    @test DD.extract_symbol(:([1, 2])) == DD.Unknown(string(:([1, 2])))

    @test DD.is_precompiling() == false

    @test DD.specializing_typeof(Val(1)) <: Val{1}
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
    using DispatchDoctor
    using PerformanceTestTools: @include

    DispatchDoctor.JULIA_OK && @include("llvm_ir_tests.jl")
    # Important to run the LLVM IR tests in a new
    # julia process with things like --code-coverage disabled.
    # See https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697/14?u=milescranmer
end

@run_package_tests
