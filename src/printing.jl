module _Printing

using .._Utils: Unknown
using .._Errors: AllowUnstableDataRace, TypeInstabilityError, TypeInstabilityWarning

Base.showerror(io::IO, e::AllowUnstableDataRace) = print(io, e.msg)

function _print_msg(io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning})
    print(
        io,
        "DispatchDoctor.TypeInstability",
        e isa TypeInstabilityError ? "Error" : "Warning",
        ": Instability detected in ",
        e.f,
    )
    if e.source_info !== nothing
        print(io, " defined at ", e.source_info)
    end
    parts = []
    if !isempty(e.arg_types)
        push!(parts, "arguments `$(e.arg_types)`")
    end
    if fieldcount(e.kwarg_types) > 0
        push!(parts, "keyword arguments `$(e.kwarg_types)`")
    end
    if !isempty(e.params)
        push!(parts, "parameters `$(e.params)`")
    end
    if !isempty(parts)
        print(io, " with ")
        join(io, parts, " and ")
    end
    print(io, ". ")
    return print(io, "Inferred to be `", e.return_type, "`, which is not a concrete type.")
end

Base.showerror(io::IO, e::TypeInstabilityError) = _print_msg(io, e)
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

Base.show(io::IO, u::Unknown) = print(io, string("[", u.msg, "]"))

end
