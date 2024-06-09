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

Base.@kwdef struct Cache{A,B}
    cache::Dict{A,B} = Dict{A,B}()
    lock::Threads.SpinLock = Threads.SpinLock()
end
const UUID_CACHE = Cache{UInt64,Base.UUID}()
const HAS_PREFERENCE_CACHE = Cache{Tuple{Base.UUID,String},Bool}()
const PREFERENCE_CACHE = Cache{Tuple{Base.UUID,String},String}()

function _cached_call(f::F, cache::Cache, key) where {F}
    lock(cache.lock) do
        get!(cache.cache, key) do
            f()
        end
    end
end
# Surprisingly it takes 600 us to get the UUID, so its worth the cache!
function _cached_get_uuid(m)
    _cached_call(UUID_CACHE, objectid(m)) do
        try
            get_uuid(m)
        catch
            Base.UUID(0)
        end
    end
end
function _cached_has_preference(uuid, key)
    _cached_call(HAS_PREFERENCE_CACHE, (uuid, key)) do
        has_preference(uuid, key)
    end
end
function _cached_load_preference(uuid, key)
    _cached_call(PREFERENCE_CACHE, (uuid, key)) do
        load_preference(uuid, key)
    end
end

function get_preferred(default, calling_module, key, deprecated_key=nothing)
    uuid = _cached_get_uuid(calling_module)
    if _cached_has_preference(uuid, key)
        return _cached_load_preference(uuid, key)
    elseif deprecated_key !== nothing && _cached_has_preference(uuid, deprecated_key)
        return _cached_load_preference(uuid, deprecated_key)
    else
        return default
    end
end
function get_all_preferred(options::StabilizationOptions, m)
    #! format: off
    return StabilizationOptions(
        get_preferred(options.mode, m, "instability_check"),
        get_preferred(options.codegen_level, m, "instability_check_codegen_level", "instability_check_codegen"),
        get_preferred(options.union_limit, m, "instability_check_union_limit"),
    )
    #! format: on
end

end
