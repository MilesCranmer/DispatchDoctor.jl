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

@enum IsCached::Bool begin
    Cached
    NotCached
end
struct Cache{A,B}
    cache::Dict{A,B}
    lock::Threads.SpinLock

    Cache{A,B}() where {A,B} = new{A,B}(Dict{A,B}(), Threads.SpinLock())
end

const UUID_CACHE = Cache{UInt64,Base.UUID}()
const PREFERENCE_CACHE = (;
    mode=Cache{Base.UUID,Tuple{String,IsCached}}(),
    codegen_level=Cache{Base.UUID,Tuple{String,IsCached}}(),
    union_limit=Cache{Base.UUID,Tuple{Int,IsCached}}(),
)
# All of our preferences are compile-time only, so we can safely cache them

function _cached_call(f::F, cache::Cache, key) where {F}
    lock(cache.lock) do
        get!(cache.cache, key) do
            f()
        end
    end
end
function _cached_get_uuid(m)
    _cached_call(UUID_CACHE, objectid(m)) do
        try
            get_uuid(m)
        catch
            Base.UUID(0)
        end
    end
end

function get_preferred(
    default, cache, calling_module, key, deprecated_keys::Vector{String}=String[]
)
    uuid = _cached_get_uuid(calling_module)
    # ^Surprisingly it takes 600 us to get the UUID, so its worth the cache!
    # TODO: Though, this might need to be changed if Revise.jl becomes compatible
    (value, cached) = _cached_call(cache, uuid) do
        if has_preference(uuid, key)
            (load_preference(uuid, key), Cached)
        elseif (i = findfirst(Base.Fix1(has_preference, uuid), deprecated_keys)) !== nothing
            Base.depwarn(
                "The preference key `$(deprecated_keys[i])` is deprecated. Please use `$key` instead.",
                :get_preferred,
            )
            (load_preference(uuid, deprecated_keys[i]), Cached)
        else
            (default, NotCached)
        end
    end
    if cached == Cached
        return value
    else
        return default
    end
end
function get_all_preferred(options::StabilizationOptions, calling_module)
    mode = get_preferred(
        options.mode,
        PREFERENCE_CACHE.mode,
        calling_module,
        "dispatch_doctor_mode",
        ["instability_check"],
    )
    if mode == "disable"
        # Short circuit and quit early
        return StabilizationOptions("disable", options.codegen_level, options.union_limit)
    end
    return StabilizationOptions(
        mode,
        get_preferred(
            options.codegen_level,
            PREFERENCE_CACHE.codegen_level,
            calling_module,
            "dispatch_doctor_codegen_level",
            ["instability_check_codegen_level", "instability_check_codegen"],
        ),
        get_preferred(
            options.union_limit,
            PREFERENCE_CACHE.union_limit,
            calling_module,
            "dispatch_doctor_union_limit",
            ["instability_check_union_limit"],
        ),
    )
end

end
