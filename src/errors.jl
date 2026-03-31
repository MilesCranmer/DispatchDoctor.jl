"""This module defines the main exceptions returned by DispatchDoctor"""
module _Errors

struct AllowUnstableDataRace <: Exception
    msg::String
end

struct TypeInstabilityError <: Exception
    f::String
    source_info::Union{String,Nothing}
    args::Any
    kwargs::Any
    params::Any
    return_type::Any
    cause::Union{TypeInstabilityError,Nothing}
end

function TypeInstabilityError(f, source_info, args, kwargs, params, return_type)
    return TypeInstabilityError(f, source_info, args, kwargs, params, return_type, nothing)
end

struct TypeInstabilityWarning
    f::String
    source_info::Union{String,Nothing}
    args::Any
    kwargs::Any
    params::Any
    return_type::Any
end

end
