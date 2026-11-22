"""This module defines the main exceptions returned by DispatchDoctor"""
module _Errors

using .._Utils: specializing_typeof, Unknown

struct AllowUnstableDataRace <: Exception
    msg::String
end

# An instability report keeps the types of the call's arguments, never their values. It can
# be shown after the call has unwound (`Test` records an error with `sprint(show, err)`),
# when the values may be gone: showing a GPU array whose memory the unwinding freed reads
# that memory.

struct TypeInstabilityError <: Exception
    f::String
    source_info::Union{String,Nothing}
    arg_types::Tuple
    kwarg_types::Type{<:NamedTuple}
    params::Any
    return_type::Any
end

struct TypeInstabilityWarning
    f::String
    source_info::Union{String,Nothing}
    arg_types::Tuple
    kwarg_types::Type{<:NamedTuple}
    params::Any
    return_type::Any
end

"""
    argument_types(args::Tuple)

The types of a call's arguments `args`, as an instability report keeps them: the types
that inference specializes on (`Type{T}` for a type `T`), and an `Unknown` as it is.
"""
argument_types(args::Tuple) = map(typeinfo, args)
typeinfo(x) = specializing_typeof(x)
typeinfo(u::Unknown) = u

end
