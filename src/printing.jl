module _Printing

using .._Utils: specializing_typeof, Unknown
using .._Errors: AllowUnstableDataRace, TypeInstabilityError, TypeInstabilityWarning

Base.showerror(io::IO, e::AllowUnstableDataRace) = print(io, e.msg)

typeinfo(x) = specializing_typeof(x)
typeinfo(u::Unknown) = u

function _print_instability_details(
    io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning}
)
    print(io, "in ", e.f)
    if e.source_info !== nothing
        print(io, " defined at ", e.source_info)
    end
    parts = []
    if !isempty(e.args)
        push!(parts, "arguments `$(map(typeinfo, e.args))`")
    end
    if !isempty(e.kwargs)
        push!(parts, "keyword arguments `$(typeof(e.kwargs))`")
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

function _collect_chain(e::TypeInstabilityError)
    chain = TypeInstabilityError[]
    current = e
    while current !== nothing
        pushfirst!(chain, current)
        current = current.cause
    end
    return chain
end

function _print_msg(io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning})
    has_chain = e isa TypeInstabilityError && e.cause !== nothing
    if has_chain
        print(
            io,
            "DispatchDoctor.TypeInstabilityError",
            ": Instability detected with the following chain (innermost first):",
        )
        chain = _collect_chain(e)
        for (i, frame) in enumerate(chain)
            print(io, "\n [", i, "] ")
            _print_instability_details(io, frame)
        end
    else
        print(
            io,
            "DispatchDoctor.TypeInstability",
            e isa TypeInstabilityError ? "Error" : "Warning",
            ": Instability detected ",
        )
        _print_instability_details(io, e)
    end
end

Base.showerror(io::IO, e::TypeInstabilityError) = _print_msg(io, e)
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

Base.show(io::IO, u::Unknown) = print(io, string("[", u.msg, "]"))

end
