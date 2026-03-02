module _Printing

using .._Utils: specializing_typeof, Unknown
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

function _print_instability_chain(io::IO, e::TypeInstabilityError)
    chain = TypeInstabilityError[]
    cur = e
    while cur !== nothing
        push!(chain, cur)
        cur = cur.caused_by
    end

    chain = reverse(chain)  # innermost -> outermost
    print(io, "\n\nInstability chain (innermost -> outermost):\n")
    for (i, current) in enumerate(chain)
        prefix = i == 1 ? "innermost" : (i == length(chain) ? "outermost" : "caused by")
        print(io, "  [", i, "] ", prefix, ": ", current.f)
        i < length(chain) && print(io, "\n")
    end
end

typeinfo(x) = specializing_typeof(x)
typeinfo(u::Unknown) = u

Base.showerror(io::IO, e::TypeInstabilityError) = begin
    _print_msg(io, e)
    e.caused_by === nothing || _print_instability_chain(io, e)
end
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

Base.show(io::IO, u::Unknown) = print(io, string("[", u.msg, "]"))

end
