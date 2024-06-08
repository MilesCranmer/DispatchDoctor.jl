"""This module interfaces with Preferences.jl"""
module _Preferences

using Preferences: load_preference, has_preference, get_uuid

struct StabilizationOptions
    mode::String
    codegen_level::String
    union_limit::Int
end

const GLOBAL_DEFAULT_MODE = "error"
const GLOBAL_DEFAULT_CODEGEN_LEVEL = "debug"
const GLOBAL_DEFAULT_UNION_LIMIT = 1

# (Just so we can test with custom UUID types)
uuid_type(_) = Base.UUID

function get_preferred(default, calling_module, key, deprecated_key=nothing)
    try
        uuid = get_uuid(calling_module)::uuid_type(calling_module)
        if has_preference(uuid, key)
            return load_preference(uuid, key, default)
        elseif deprecated_key !== nothing && has_preference(uuid, deprecated_key)
            return load_preference(uuid, deprecated_key, default)
        else
            return default
        end
    catch
        default
    end
end
function get_all_preferred(options::StabilizationOptions, calling_module)
    #! format: off
    return StabilizationOptions(
        get_preferred(options.mode, calling_module, "instability_check"),
        get_preferred(options.codegen_level, calling_module, "instability_check_codegen_level", "instability_check_codegen"),
        get_preferred(options.union_limit, calling_module, "instability_check_union_limit"),
    )
    #! format: on
    # TODO: formally deprecate "instability_check_codegen
end

end
