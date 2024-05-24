using TestItems: @testitem
using TestItemRunner

# @testitem "Code quality (Aqua.jl)" begin
#     using DispatchDoctor
#     using Aqua

#     Aqua.test_all(DispatchDoctor)
# end
@testitem "Code linting (JET.jl)" begin
    using DispatchDoctor
    using JET

    JET.test_package(DispatchDoctor; target_defined_modules = true)
end

@run_package_tests
