using DispatchDoctor
using Test
using Aqua
using JET

@testset "DispatchDoctor.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(DispatchDoctor)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(DispatchDoctor; target_defined_modules = true)
    end
    # Write your tests here.
end
