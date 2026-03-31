module _Printing

using .._Utils: specializing_typeof, Unknown
using .._Errors: AllowUnstableDataRace, TypeInstabilityError, TypeInstabilityWarning

Base.showerror(io::IO, e::AllowUnstableDataRace) = print(io, e.msg)

typeinfo(x) = specializing_typeof(x)
typeinfo(u::Unknown) = u

function _print_instability_details(
    io::IO, e::Union{TypeInstabilityError,TypeInstabilityWarning}
)
    printstyled(io, e.f; bold=true)
    if e.source_info !== nothing
        printstyled(io, " defined at "; color=:light_black)
        printstyled(io, e.source_info; color=:light_black)
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
    print(io, ". Inferred to be ")
    printstyled(io, "`", e.return_type, "`"; color=:yellow)
    return print(io, ", which is not a concrete type.")
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
        n = length(chain)
        for (i, frame) in enumerate(chain)
            is_last = i == n
            connector = is_last ? " └── " : " ├── "
            print(io, "\n")
            printstyled(io, connector; color=:light_black)
            printstyled(io, "[", i, "]"; bold=true)
            print(io, " ")
            _print_instability_details(io, frame)
        end
    else
        print(
            io,
            "DispatchDoctor.TypeInstability",
            e isa TypeInstabilityError ? "Error" : "Warning",
            ": Instability detected in ",
        )
        _print_instability_details(io, e)
    end
end

Base.showerror(io::IO, e::TypeInstabilityError) = _print_msg(io, e)
Base.show(io::IO, w::TypeInstabilityWarning) = _print_msg(io, w)

Base.show(io::IO, u::Unknown) = print(io, string("[", u.msg, "]"))

end
