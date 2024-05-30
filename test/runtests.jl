const TEST = get(ENV, "DISPATCH_DOCTOR_TEST", "unit")

@static if occursin(TEST, "unit")
    include("unittests.jl")
elseif occursin(TEST, "enzyme")
    include("enzyme.jl")
elseif occursin(TEST, "dynamic-expressions")
    include("dynamicexpressions.jl")
end
