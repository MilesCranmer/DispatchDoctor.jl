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
    caused_by::Union{TypeInstabilityError,Nothing}

    TypeInstabilityError(
        f::String,
        source_info::Union{String,Nothing},
        args::Any,
        kwargs::Any,
        params::Any,
        return_type::Any,
        caused_by::Union{TypeInstabilityError,Nothing},
    ) = new(f, source_info, args, kwargs, params, return_type, caused_by)

    TypeInstabilityError(
        f::String,
        source_info::Union{String,Nothing},
        args::Any,
        kwargs::Any,
        params::Any,
        return_type::Any,
    ) = new(f, source_info, args, kwargs, params, return_type, nothing)
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
