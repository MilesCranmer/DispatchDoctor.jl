if parse(Bool, get(ENV, "DISPATCH_DOCTOR_UNITTESTS", "true"))
    include("unittests.jl")
end
