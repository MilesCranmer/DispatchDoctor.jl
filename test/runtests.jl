using TestItems: @testitem
using TestItemRunner

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
