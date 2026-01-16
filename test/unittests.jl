using TestItems: @testitem
using TestItemRunner

@testitem "smoke test" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level f(x) = x
        @test f(1) == 1
    end
end
@testitem "with error" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level f(x) = x > 0 ? x : 1.0
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)
        @test f(2.0) == 2.0
    end
end
@testitem "with kwargs" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level f(x; a=1, b=2) = x + a + b
        @test f(1) == 4
        @eval @stable default_codegen_level = $codegen_level g(; a=1) = a > 0 ? a : 1.0
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g(a=1)
        @test g(; a=2.0) == 2.0
    end
end
@testitem "tuple args" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level f((x, y); a=1, b=2) =
            x + y + a + b
        @test f((1, 2)) == 6
        @test f((1, 2); b=3) == 7
        @eval @stable default_codegen_level = $codegen_level g((x, y), z=1.0; c=2.0) =
            x > 0 ? y : c + z
        @test g((1, 2.0)) == 2.0
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g((1, 2))
    end
end
@testitem ":: args" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level f(x::Int) = x
        @test f(1) == 1
        @eval @stable default_codegen_level = $codegen_level g(; x::Int) = x
        @test g(; x=1) == 1
        @eval @stable default_codegen_level = $codegen_level h(x::Number; y::Number) =
            x > y ? x : y
        @test h(1; y=2) == 2
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError h(1; y=2.0)
    end
end
@testitem ":: tuple args" begin
    using DispatchDoctor

    for codegen_level in ("debug", "min")
        #! format: off
        f_expanded = @eval @macroexpand @stable(
            default_codegen_level = $codegen_level,
            function f((x,)::Vector)
                return x
            end
        )
        #! format: on

        expected_code_snippets = [
            # Original signature preserved in simulator:
            r"function var\"[#0-9]*f_simulator[#0-9]*\"\(\(x,\)::Vector[,; ]*\)$"m,
            # Gensymmed arg used in new signature:
            r"function f\(var\"[#0-9]*arg[#0-9]*\"::Vector[,; ]*\)$"m,
            # Gensymmed arg used in instability check:
            r"_promote_op.*var\"[#0-9]*arg[#0-9]*\"",
        ]

        # Destructuring assignment in body:
        codegen_level == "debug" &&
            push!(expected_code_snippets, r"\(x,\) = var\"[#0-9]*arg[#0-9]*\"$"m)

        # Simulator called with gensymmed arg
        codegen_level == "min" && push!(
            expected_code_snippets,
            r"var\"[#0-9]*f_simulator[#0-9]*\"\(var\"[#0-9]*arg[#0-9]*\"[,; ]*\)$"m,
        )

        DispatchDoctor.JULIA_OK && for expected_code in expected_code_snippets
            @test occursin(expected_code, string(f_expanded))
        end

        eval(f_expanded)

        call_f(args...) = Base.invokelatest(f, args...)

        @test call_f([1]) == 1
        @test_throws MethodError call_f((1,)) == 1
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError call_f(Any[1])
    end
end
@testitem "multiple tuple args" begin
    using DispatchDoctor

    for codegen_level in ("debug", "min")
        #! format: off
        @eval @stable(
            default_codegen_level = $codegen_level,
            f((x, y)::Vector) = x + y,
        )
        @eval @stable(
            default_codegen_level = $codegen_level,
            g((x, y)::Vector, (z,)) = x + y + z,
        )
        #! format: on

        @test f([1, 2]) == 3
        @test g([1, 2], (3,)) == 6

        @test_throws MethodError f((1, 2))
        @test_throws MethodError g((1, 2), (3,))

        if DispatchDoctor.JULIA_OK
            @test_throws TypeInstabilityError f(Any[1, 2])
            @test_throws TypeInstabilityError g(Any[1, 2], (3,))
        end
    end
end
@testitem "property destructuring" begin
    using DispatchDoctor

    if v"1.7-" <= VERSION  # property destructuring introduced in 1.7
        abstract type MyAbstractType end
        struct StableType <: MyAbstractType
            x::Int
            y::Float64
        end
        struct UnstableType <: MyAbstractType
            x
            y
        end
        for codegen_level in ("debug", "min")
            #! format: off
            fex = @eval @macroexpand @stable(
                default_codegen_level = $codegen_level,
                f((; x)::MyAbstractType) = x
            )
            #! format: on

            expected_code_snippets = [
                # Original signature preserved in simulator
                r"function var\"[#0-9]*f_simulator[#0-9]*\"\(\(; x\)::MyAbstractType[,; ]*\)$"m,
                # Gensymmed arg used in new signature
                r"function f\(var\"[#0-9]*arg[#0-9]*\"::MyAbstractType[,; ]*\)$"m,
                # Gensymmed arg used in instability check
                r"_promote_op.*var\"[#0-9]*arg[#0-9]*\"",
            ]
            codegen_level == "debug" &&
                push!(expected_code_snippets, r"\(; x\) = var\"[#0-9]*arg[#0-9]*\"$"m)
            codegen_level == "min" && push!(
                expected_code_snippets,
                r"var\"[#0-9]*f_simulator[#0-9]*\"\(var\"[#0-9]*arg[#0-9]*\"[,; ]*\)$"m,
            )

            DispatchDoctor.JULIA_OK && for expected_code in expected_code_snippets
                @test occursin(expected_code, string(fex))
            end

            eval(fex)

            call_f(args...) = Base.invokelatest(f, args...)

            @test call_f(StableType(1, 2.0)) == 1
            @test_throws MethodError call_f((; x=1))
            DispatchDoctor.JULIA_OK &&
                @test_throws TypeInstabilityError call_f(UnstableType(1, 2.0))
        end
    end
end
@testitem "multiple property destructuring" begin
    using DispatchDoctor

    if v"1.7-" <= VERSION  # property destructuring introduced in 1.7
        abstract type MyAbstractType2 end
        struct StableType2 <: MyAbstractType2
            x::Int
            y::Float64
        end
        struct UnstableType2 <: MyAbstractType2
            x
            y
        end
        for codegen_level in ("debug", "min")
            #! format: off
            @eval @stable(
                default_codegen_level = $codegen_level,
                f((; x, y)::MyAbstractType2) = x + y,
            )
            @eval @stable(
                default_codegen_level = $codegen_level,
                g((; x, y)::MyAbstractType2, (; z)) = x + y + z,
            )
            @eval @stable(
                default_codegen_level = $codegen_level,
                h((a, b)::Vector, (; x, y)::MyAbstractType2) = a + b + x + y,
            )
            @eval @stable(
                default_codegen_level = $codegen_level,
                k(a, (; x, y)=(; z=1, x=a, y=3)) = x + y,
            )
            #! format: on

            @test f(StableType2(1, 2.0)) == 3.0
            @test g(StableType2(1, 2.0), (; z=3)) == 6.0
            @test h([3, 4], StableType2(1, 2.0)) == 10.0
            @test k(1) == 4
            @test k(nothing, StableType2(1, 2.0)) == 3.0

            @test_throws MethodError f((; x=1, y=2.0))
            @test_throws MethodError g((; x=1, y=2.0), (; z=3))
            @test_throws MethodError h([3, 4], (; x=1, y=2.0))
            @test_throws MethodError h((3, 4), StableType2(1, 2.0))

            if DispatchDoctor.JULIA_OK
                @test_throws TypeInstabilityError f(UnstableType2(1, 2.0))
                @test_throws TypeInstabilityError g(UnstableType2(1, 2.0), (; z=3))
                @test_throws TypeInstabilityError h([3, 4], UnstableType2(1, 2.0))
                @test_throws TypeInstabilityError h(Any[3, 4], UnstableType2(1, 2.0))
                @test_throws TypeInstabilityError k(nothing, UnstableType2(1, 2.0))
            end
        end
    end
end
@testitem "detect duplicate LineNumberNode in @stable expansion" begin
    using DispatchDoctor

    # Basically we want to verify that the simulator function
    # doesn't duplicate any LineNumberNodes, which can
    # mess with stacktraces and coverage.
    ex = @macroexpand(@stable(function f(x)
        return x
    end))

    function collect_line_nodes!(line_nodes, expr)
        if expr isa LineNumberNode
            push!(line_nodes, expr)
        elseif expr isa Expr
            for arg in expr.args
                collect_line_nodes!(line_nodes, arg)
            end
        end
        return line_nodes
    end

    line_nodes = collect_line_nodes!([], ex)

    @test length(line_nodes) > 1
    @test length(unique(line_nodes)) == length(line_nodes)  # No dupes!
end
@testitem "Type specialization" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level f(a, ::Type{T}) where {T} =
            sum(a; init=zero(T))
        @test f([1.0f0, 1.0f0], Float32) == 2.0f0
    end
end
@testitem "args and kwargs" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        # Without the dots
        @eval @stable default_codegen_level = $codegen_level f1(a, args::Vararg) =
            sum(args) + a
        @test f1(1, 1, 2, 3) == 7

        # Without the dots, with curly on Vararg
        @eval @stable default_codegen_level = $codegen_level f1(
            a, args::Vararg{Any,M}
        ) where {M} = sum(args) + a
        @test f1(1, 1, 2, 3) == 7

        # With the dots
        @eval @stable default_codegen_level = $codegen_level f2(a, args...) = sum(args) + a
        @test f2(1, 1, 2, 3) == 7

        # With kwargs
        @eval @stable default_codegen_level = $codegen_level f3(c; kwargs...) =
            sum(values(kwargs)) + c
        @test f3(1; a=1, b=2, c=3) == 7

        # With both
        @eval @stable default_codegen_level = $codegen_level f4(a, args...; d, kwargs...) =
            sum(args) + sum(values(kwargs)) + a + d
        @test f4(1, 1, 2, 3; d=0, a=1, b=2, c=3) == sum((1, 1, 2, 3, 0, 1, 2, 3))
    end
end
@testitem "string macro" begin
    using DispatchDoctor

    @test @stable(v"1.10.0") == v"1.10.0"
end
@testitem "complex arg without symbol" begin
    using DispatchDoctor: DispatchDoctor as DD
    struct Undefined end
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level function f(
            ::Type{T1}=Undefined
        ) where {T1}
            return T1
        end
        @test f() == Undefined
    end
end
@testitem "vararg with type" begin
    using DispatchDoctor
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level function f(::Int...)
            return rand(Bool) ? 0 : 0.0
        end
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1, 2, 3)

        @eval @stable default_codegen_level = $codegen_level function f2(a::Int...)
            return rand(Bool) ? 0 : 0.0
        end
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f2(1, 2, 3)

        @eval @stable default_codegen_level = $codegen_level function f3(a, ::Int...)
            return rand(Bool) ? 0 : 0.0
        end
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f3(1, 2, 3)

        # With expression-based type
        @eval @stable default_codegen_level = $codegen_level function g(::typeof(*)...)
            return rand(Bool) ? 0 : 0.0
        end
        DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g(*, *)
    end
end
@testitem "QuoteNode in options" begin
    using DispatchDoctor
    using DispatchDoctor: _ParseOptions as DDPO
    default_mode = "disable"
    @eval @stable default_mode = $default_mode f() = Val(rand())
    @test f() isa Val
    @test DDPO._parse(QuoteNode(default_mode), String) == "disable"

    # Edge case
    @test DDPO._parse(nothing, String) == nothing
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

    ex = first(
        _stabilize_module(
            :(module Aavoiddouble
            using DispatchDoctor: @stable

            @stable f(x) = x > 0 ? x : 0.0
            g(x, y) = x > 0 ? y : 0.0
            end),
            DispatchDoctor._Stabilization.DownwardMetadata(),
        ),
    )

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
    # an f_simulator (indicating the `@stable` has
    # not been expanded yet)
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
end
@testitem "skip empty functions" begin
    using DispatchDoctor: _stabilize_fnc, _stabilize_all

    ex = _stabilize_all(
        :(function donothing end), DispatchDoctor._Stabilization.DownwardMetadata()
    )[1]
    @test ex == :(function donothing end)

    # TODO: Fragile test of MacroTools internals
    @test_throws AssertionError _stabilize_fnc(
        :(function donothing end), DispatchDoctor._Stabilization.DownwardMetadata()
    )
end
@testitem "underscore argument" begin
    using DispatchDoctor
    @stable f(_) = rand(Bool) ? Float32 : Float64
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(1)
    if VERSION >= v"1.9"
        @test_throws "with arguments `(Int64,)`" f(1)
    end
end
@testitem "skip closures inside macros" begin
    using DispatchDoctor: DispatchDoctor as DD

    stabilized = DD._stabilize_all(
        :(macro m(ex)
            f() = rand(Bool) ? Float32 : Float64
            f()
            return ex
        end),
        DispatchDoctor._Stabilization.DownwardMetadata(),
    )

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
        @test occursin("DispatchDoctor.TypeInstabilityWarning", msg)
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
@testitem "bad choice of codegen level" begin
    using DispatchDoctor
    if DispatchDoctor.JULIA_OK
        @test_throws(LoadError, @eval @stable default_codegen_level = "bad" f(x) = x^2)
        @test_throws(
            "Unknown codegen level", @eval @stable default_codegen_level = "bad" f(x) = x^2
        )
    end
end
@testitem "allow errors through" begin
    using DispatchDoctor

    @stable my_bad_function(x) = x / "blah"

    @test_throws MethodError my_bad_function(1)
end
@testitem "dont flag Type{T} as not concrete" begin
    using DispatchDoctor

    @stable function f(t)
        return t
    end

    @test f(Float32) == Float32

    @test !Base.isconcretetype(Type{Float32})

    # We have a special method to fix this:
    @test !DispatchDoctor.type_instability(Type{Float32})

    # Will work recursively
    @test !DispatchDoctor.type_instability(Type{Type{Float32}})
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
@testitem "allow unstable preserves stability" begin
    using DispatchDoctor
    f(x) = sum(x)
    g(x) = allow_unstable(() -> f(x))
    @inferred g([1, 2, 3])
    @test g([1, 2, 3]) == 6
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
@testitem "propagate macros" begin
    using DispatchDoctor: _stabilize_all, JULIA_OK
    ex = _stabilize_all(
        :(Base.@propagate_inbounds function f(x)
            return x > 0 ? x : 0.0
        end),
        DispatchDoctor._Stabilization.DownwardMetadata(),
    )
    JULIA_OK && @test occursin("propagate_inbounds", string(ex))
end
@testitem "register custom macros" begin
    using DispatchDoctor

    macro mymacro(ex)
        return esc(ex)
    end
    if !haskey(DispatchDoctor.MACRO_BEHAVIOR.table, Symbol("@mymacro"))
        register_macro!(Symbol("@mymacro"), DispatchDoctor.IncompatibleMacro)
    end
    @test DispatchDoctor.get_macro_behavior(:(@mymacro x = 1)) ==
        DispatchDoctor.IncompatibleMacro

    # Trying to register again should fail with a useful error
    if VERSION >= v"1.9"
        @test_throws "Macro `@mymacro` already registered" register_macro!(
            Symbol("@mymacro"), DispatchDoctor.IncompatibleMacro
        )
    end

    if DispatchDoctor.JULIA_OK
        @eval @stable @mymacro function f(x)
            return x > 0 ? x : 0.0
        end
        @test f(0) == 0
    end
end
@testitem "merging behavior of registered macros" begin
    using DispatchDoctor
    using DispatchDoctor: _Interactions as DDI

    macro compatiblemacro(ex, option)
        return esc(ex)
    end
    macro incompatiblemacro(ex)
        return esc(ex)
    end
    macro dontpropagatemacro(ex)
        return esc(ex)
    end
    if !haskey(DDI.MACRO_BEHAVIOR.table, Symbol("@compatiblemacro"))
        register_macro!(Symbol("@compatiblemacro"), DDI.CompatibleMacro)
    end
    if !haskey(DDI.MACRO_BEHAVIOR.table, Symbol("@incompatiblemacro"))
        register_macro!(Symbol("@incompatiblemacro"), DDI.IncompatibleMacro)
    end
    if !haskey(DDI.MACRO_BEHAVIOR.table, Symbol("@dontpropagatemacro"))
        register_macro!(Symbol("@dontpropagatemacro"), DDI.DontPropagateMacro)
    end
    @test DDI.get_macro_behavior(:(@compatiblemacro true x = 1)) == DDI.CompatibleMacro
    @test DDI.get_macro_behavior(:(@incompatiblemacro x = 1)) == DDI.IncompatibleMacro
    @test DDI.get_macro_behavior(:(@dontpropagatemacro x = 1)) == DDI.DontPropagateMacro

    @test DDI.combine_behavior(DDI.CompatibleMacro, DDI.CompatibleMacro) ==
        DDI.CompatibleMacro
    @test DDI.combine_behavior(DDI.CompatibleMacro, DDI.IncompatibleMacro) ==
        DDI.IncompatibleMacro
    @test DDI.combine_behavior(DDI.CompatibleMacro, DDI.DontPropagateMacro) ==
        DDI.DontPropagateMacro
    @test DDI.combine_behavior(DDI.IncompatibleMacro, DDI.CompatibleMacro) ==
        DDI.IncompatibleMacro
    @test DDI.combine_behavior(DDI.IncompatibleMacro, DDI.IncompatibleMacro) ==
        DDI.IncompatibleMacro
    @test DDI.combine_behavior(DDI.IncompatibleMacro, DDI.DontPropagateMacro) ==
        DDI.IncompatibleMacro
    @test DDI.combine_behavior(DDI.DontPropagateMacro, DDI.CompatibleMacro) ==
        DDI.DontPropagateMacro
    @test DDI.combine_behavior(DDI.DontPropagateMacro, DDI.IncompatibleMacro) ==
        DDI.IncompatibleMacro
    @test DDI.combine_behavior(DDI.DontPropagateMacro, DDI.DontPropagateMacro) ==
        DDI.DontPropagateMacro

    ex = quote
        @compatiblemacro(
            false,
            @dontpropagatemacro(
                @dontpropagatemacro(
                    @compatiblemacro(
                        @incompatiblemacro(true),
                        @dontpropagatemacro(komodo(x) = x)  # Will only take last arg
                    )
                )
            )
        )
    end
    if DispatchDoctor.JULIA_OK
        new_ex, upward_metadata = DispatchDoctor._stabilize_all(
            ex, DispatchDoctor._Stabilization.DownwardMetadata()
        )
        # We should expect:
        #   1. All of the `@dontpropagatemacro`'s to be on the outside of the block.
        #   2. The `@compatiblemacro`'s to be duplicated on both the simulator function,
        #      as well as the regular function.
        #   3. The `@incompatiblemacro` will be unaffected, as it is operating on
        #      the first argument of a multi-arg macro.
        # Note that this changes the order of the macros.
        s = replace(string(new_ex), "\n" => "")
        @test count("@dontpropagatemacro", s) == 3
        @test count("@compatiblemacro", s) == 4
        @test count("@incompatiblemacro", s) == 2

        # We test the exact sequence of macros
        outer = r"@dontpropagatemacro.*@dontpropagatemacro.*@dontpropagatemacro.*begin"
        function_def = r"@compatiblemacro.*false.*@compatiblemacro.*@incompatiblemacro.*true.*komodo"
        simulator = function_def * r"_simulator.*end"

        @test occursin(outer * r".*" * simulator * r".*" * function_def, s)
    end
end
@testitem "stack multiple complex macros" begin
    using DispatchDoctor
    using MacroTools

    macro mymacro1(ex)
        return esc(ex)
    end
    macro mymacro2(ex)
        return esc(ex)
    end
    macro mymacro3(option1, option2, ex)
        return esc(ex)
    end

    l = LineNumberNode(1, @__FILE__)
    downward_metadata = DispatchDoctor._Stabilization.DownwardMetadata(;
        macros_to_use=[[Symbol("@mymacro4"), l]], macro_keys=[gensym()]
    )
    ex, upward_metadata = DispatchDoctor._stabilize_all(
        :(@mymacro3 true false @mymacro2 @mymacro1 function foobar(x)
            return x > 0 ? x : 0.0
        end),
        downward_metadata,
    )
    @test upward_metadata.matching_function
    @test isempty(upward_metadata.unused_macros)
    @test isempty(upward_metadata.macro_keys)

    s = string(ex)
    s = replace(s, "\n" => "")

    # Applied once to the simulator:
    @test occursin(
        r"@mymacro4.*@mymacro3\(true, false.*@mymacro2.*@mymacro1.*foobar_simulator", s
    )

    # And again to the regular foobar, with the docs added:
    @test occursin(
        r"foobar_simulator.*\(Base\).@__doc__.*.*@mymacro4.*@mymacro3\(true, false.*@mymacro2.*@mymacro1.*foobar",
        s,
    )
end
@testitem "multiple macro chaining takes least compatible" begin
    using DispatchDoctor
    @stable @inline @generated function f(x)
        return :(x > 0 ? x : 0.0)
    end
    @test f(0) == 0
end
@testitem "skip assume effects" begin
    using DispatchDoctor
    if DispatchDoctor.JULIA_OK && VERSION >= v"1.8.0-DEV.0"
        @eval begin
            @stable Base.@assume_effects :nothrow function f(x)
                return x > 0 ? x : 0.0
            end
            @test f(0) == 0
        end
    end
end
@testitem "skip certain functions" begin
    using DispatchDoctor
    using DispatchDoctor: _Interactions as DDI

    @test DDI.ignore_function(+) == false
    @test DDI.ignore_function(iterate) == true

    struct MyTypeIterate end
    @stable begin
        f() = Val(rand())
        Base.iterate(::MyTypeIterate) = Val(rand())
        Base.getproperty(::MyTypeIterate, ::Symbol) = Val(rand())
        Base.setproperty!(::MyTypeIterate, ::Symbol, _) = Val(rand())
    end
    if DispatchDoctor.JULIA_OK
        @test_throws TypeInstabilityError f()
        @test iterate(MyTypeIterate()) isa Val
        @test getproperty(MyTypeIterate(), :x) isa Val
        @test setproperty!(MyTypeIterate(), :x, 1) isa Val
    end
end
@testitem "conditionally allow union instabilities" begin
    using DispatchDoctor
    @stable default_union_limit = 2 begin
        # Just a union:
        f(x) = x > 0 ? x : 0.0
        # Full-blown type instability:
        g() = Val(rand())
    end
    @test f(0) == 0
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError g()
end
@testitem "disallow union if any element is unstable" begin
    using DispatchDoctor
    @stable default_union_limit = 2 function f(x)
        return x > 0 ? Val(rand()) : x
    end
    # This should still fail because one of the elements is unstable!
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(0)
end
@testitem "unionall within union" begin
    using DispatchDoctor
    @stable default_union_limit = 2 function f(x)
        return [x > 0 ? Val(rand()) : x]
    end
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(0)
end
@testitem "larger union limit" begin
    using DispatchDoctor

    # Breaks with 4 unions:
    @stable default_union_limit = 3 function f(x)
        x = Union{Float16,Float32,Float64,BigFloat}[
            one(Float16), one(Float32), one(Float64), one(BigFloat)
        ]
        return x[rand(1:4)]
    end
    DispatchDoctor.JULIA_OK && @test_throws TypeInstabilityError f(0)

    # But, now it works:
    @stable default_union_limit = 4 function f(x)
        x = Union{Float16,Float32,Float64,BigFloat}[
            one(Float16), one(Float32), one(Float64), one(BigFloat)
        ]
        return x[rand(1:4)]
    end
    @test f(0) == 1
end
@testitem "union limit respects tuple" begin
    import DispatchDoctor as DD

    U2 = Union{Float32,Float64}
    U3 = Union{Float16,U2}
    @test DD.type_instability(U2) == true
    @test DD.type_instability_limit_unions(U2, Val(2)) == false
    # Limit will also apply to tuples:
    @test DD.type_instability(Tuple{U2,Bool}) == true
    @test DD.type_instability_limit_unions(Tuple{U2,Bool}, Val(2)) == false

    # Multiple unions – only max union split taken:
    @test DD.type_instability_limit_unions(Tuple{U2,U2,Bool}, Val(2)) == false
    @test DD.type_instability_limit_unions(Tuple{U2,U2,Bool}, Val(2)) == false
    @test DD.type_instability_limit_unions(Tuple{U2,U3,Bool}, Val(2)) == true

    # TypeVar should still be unstable
    @test DD.type_instability_limit_unions(Tuple{U2,T} where {T}, Val(2)) == true
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
    # if we use `default_codegen_level="min"`, this won't work!
    for codegen_level in ("debug", "min")
        @eval @stable default_codegen_level = $codegen_level function f(x)
            y = Tuple(x)
            return sum(y[1:2])
        end
        @test f([1, 2, 3]) == 3
        msg = sprint(code_warntype, f, typeof(([1, 2, 3],)))
        msg = lowercase(msg)
        if DispatchDoctor.JULIA_OK
            if codegen_level == "min"
                @test !occursin("tuple{vararg{int64}}", msg)
            else
                # No longer has the body!
                @test occursin("tuple{vararg{int64}}", msg)
            end
        end
    end
end
@testitem "Preferences.jl" begin
    using DispatchDoctor
    import DispatchDoctor._Preferences as DDP
    import DispatchDoctor._ParseOptions as DDPO
    import Preferences: set_preferences!, load_preference, has_preference, get_uuid

    push!(LOAD_PATH, joinpath(@__DIR__, "FakePackage1"))
    push!(LOAD_PATH, joinpath(@__DIR__, "FakePackage2"))
    push!(LOAD_PATH, joinpath(@__DIR__, "FakePackage3"))

    # These packages have `LocalPreferences.toml` with
    # various settings
    using FakePackage1

    options = DDP.StabilizationOptions("d", "e", 6)
    @test DDP.get_all_preferred(options, FakePackage1) ==
        DDP.StabilizationOptions("a", "b", 3)

    using FakePackage2
    options = DDP.StabilizationOptions("d", "e", 6)
    @test DDP.get_all_preferred(options, FakePackage2) ==
        DDP.StabilizationOptions("d", "alpha", 6)

    # FakePackage3 has no preferences
    using FakePackage3
    FakePackage3.eval(:($(DispatchDoctor).@stable f() = Val(rand())))
    if DispatchDoctor.JULIA_OK
        @test_throws TypeInstabilityError FakePackage3.f()
    end

    # By default, passing Main will just return all the options:
    @test DDPO.parse_options(Any[], Main) == DDP.StabilizationOptions(
        DDP.GLOBAL_DEFAULT_MODE,
        DDP.GLOBAL_DEFAULT_CODEGEN_LEVEL,
        DDP.GLOBAL_DEFAULT_UNION_LIMIT,
    )
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
@testitem "issue #64" begin
    using DispatchDoctor

    @stable default_union_limit = 2 function f(x)
        return x > 0 ? (nothing, 1) : (1.0, 1)
    end

    @test f(2) == (nothing, 1)
end
@testitem "issue with underscore function and min codegen" begin
    #! format: off
    using DispatchDoctor

    @stable g_debug(_::Int) = 1
    @test g_debug(1) == 1
    @stable default_codegen_level = "min" g_min(_::Int) = 1
    @test g_min(1) == 1

    @stable f_debug(_::Int, _::Float64) = 1
    @test f_debug(1, 2.0) == 1
    @stable default_codegen_level = "min" f_min(_::Int, _::Float64) = 1
    @test f_min(1, 2.0) == 1

    @stable default_codegen_level = "min" f_min_with_error(_::Int, _::Float64) = Val(rand())
    if DispatchDoctor.JULIA_OK
        @test_throws TypeInstabilityError f_min_with_error(1, 2.0)
    end
    # ! format: on
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

        @test occursin("DispatchDoctor.TypeInstabilityWarning", msg2)

        @stable enable = false function f(x)
            return x > 0 ? x : 0.0
        end
        @test f(0) == 0.0
    end
end
@testitem "Miscellaneous" begin
    using DispatchDoctor: DispatchDoctor as DD
    using DispatchDoctor: _Utils as DDU

    @test DD.extract_symbol(:([1, 2])) == DD.Unknown(string(:([1, 2])))

    @test DD.is_precompiling() == false

    @test DD.specializing_typeof(Val(1)) <: Val{1}

    @test DDU.is_function_name_compatible(1.0) == false
    @test DDU.is_symbol_like(1.0) == false

    if Base.isdefined(Core, :TypeofBottom)
        @test DD.type_instability(Core.TypeofBottom) == false
        @test DD.type_instability_limit_unions(Core.TypeofBottom, Val(1)) == false
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
    using DispatchDoctor
    using PerformanceTestTools: @include

    DispatchDoctor.JULIA_OK && @include("llvm_ir_tests.jl")
    # Important to run the LLVM IR tests in a new
    # julia process with things like --code-coverage disabled.
    # See https://discourse.julialang.org/t/improving-speed-of-runtime-dispatch-detector/114697/14?u=milescranmer
end
@testitem "nospecialize tests" begin
    using DispatchDoctor

    @stable begin
        # Will ignore everything that has a @nospecialize macro:
        function test_nospecialize(@nospecialize(x))
            return x > 0 ? x : 0.0
        end
        function test_nospecialize_with_type(@nospecialize(x::Integer))
            return x > 0 ? x : 0.0
        end
        function test_nospecialize_with_default(@nospecialize(x)=1)
            return x > 0 ? x : 0.0
        end
        # Including keywords:
        function test_nospecialize_kwarg(x; @nospecialize(y))
            return x > 0 ? y : 0.0
        end
        function test_nospecialize_kwarg_typed(x; @nospecialize(y::Integer))
            return x > 0 ? y : 0.0
        end
        function test_nospecialize_kwarg_default(x; @nospecialize(y = 1))
            return x > 0 ? y : 0.0
        end
        # This will not stop other functions from being stabilized:
        f() = Val(rand())
    end
    @test test_nospecialize(1) == 1
    @test test_nospecialize_with_type(1) == 1
    @test test_nospecialize_with_default() == 1
    @test test_nospecialize_kwarg(1; y=2) == 2
    @test test_nospecialize_kwarg_typed(1; y=2) == 2
    @test test_nospecialize_kwarg_default(1) == 1
    @test_throws TypeInstabilityError f()
end
@testitem "issue with Vararg union limit" begin
    using DispatchDoctor
    using DispatchDoctor: @stable

    @stable default_union_limit = 2 function tuple_from_vector(v::Vector{Int})
        # Converting a vector with unknown length to a tuple yields
        # `Tuple{Vararg{Int64}}`, which internally stores `Core.TypeofVararg`.
        # This hits the missing method in `type_instability_limit_unions`.
        return Tuple(v)
    end

    DispatchDoctor.JULIA_OK &&
        @test_throws TypeInstabilityError tuple_from_vector([1, 2, 3])

    @stable function tuple_from_vector2(v::Vector{Int})
        return Tuple(v)
    end
    DispatchDoctor.JULIA_OK &&
        @test_throws TypeInstabilityError tuple_from_vector2([1, 2, 3])
end
@testitem "issue with specializing_typeof on unbound type parameters" begin
    using DispatchDoctor

    @stable function test_function(arg::Type{<:Type})
        return nothing
    end

    # This should trigger the error
    P = (Type{T} where {T}).body
    @test test_function(P) === nothing
end
@testitem "issue with closures causing instability" begin
    using DispatchDoctor

    @stable function f(x)
        @stable g() = x
        return g
    end

    @test_nowarn f(1.0)()
    @test f(1.0)() == 1.0
end
@testitem "issue with nested allow_unstable" begin
    using DispatchDoctor

    @stable f() = Val(rand())

    # Issue was that the `allow_unstable` would set the
    # `INSTABILITY_CHECK_ENABLED` to `false` and then the
    # `f` would throw an error, _even though_ we are still
    # within another `allow_unstable` block.
    @test_nowarn allow_unstable(() -> (allow_unstable(f); f()))
    @test_throws TypeInstabilityError f()
end

@run_package_tests
