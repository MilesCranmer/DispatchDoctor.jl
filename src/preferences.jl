"""This module interfaces with Preferences.jl"""
module _Preferences

using Preferences: load_preference, get_uuid

function get_preferred_mode(mode, calling_module)
    try
        load_preference(get_uuid(calling_module)::Base.UUID, "instability_check", mode)
    catch
        mode
    end
end

end
