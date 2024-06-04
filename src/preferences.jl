"""This module interfaces with Preferences.jl"""
module _Preferences

using Preferences: load_preference, get_uuid

struct StabilizationOptions
    mode::String
    codegen_level::String
    union_limit::Int
end

const GLOBAL_DEFAULT_MODE = "error"
const GLOBAL_DEFAULT_CODEGEN_LEVEL = "debug"
const GLOBAL_DEFAULT_UNION_LIMIT = 1

function get_preferred(default, calling_module, key)
    try
        load_preference(get_uuid(calling_module)::Base.UUID, key, default)
    catch
        default
    end
end
function get_all_preferred(options::StabilizationOptions, calling_module)
    return StabilizationOptions(
        get_preferred(options.mode, calling_module, "instability_check"),
        get_preferred(options.codegen_level, calling_module, "instability_check_codegen"),
        get_preferred(options.union_limit, calling_module, "instability_check_union_limit"),
    )
end

end
