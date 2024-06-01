"""This module interfaces with Preferences.jl"""
module _Preferences

using Preferences: load_preference, get_uuid

const GLOBAL_DEFAULT_MODE = "error"
const GLOBAL_DEFAULT_CODEGEN_LEVEL = "debug"

function get_preferred(default, calling_module, key)
    try
        load_preference(get_uuid(calling_module)::Base.UUID, key, default)
    catch
        default
    end
end

end
