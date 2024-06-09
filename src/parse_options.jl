"""This module parses the options for the `@stable` macro"""
module _ParseOptions

using .._Preferences:
    get_all_preferred,
    GLOBAL_DEFAULT_MODE,
    GLOBAL_DEFAULT_CODEGEN_LEVEL,
    GLOBAL_DEFAULT_UNION_LIMIT,
    StabilizationOptions

function parse_options(options, calling_module)
    # Standard defaults:
    mode = GLOBAL_DEFAULT_MODE
    codegen_level = GLOBAL_DEFAULT_CODEGEN_LEVEL
    union_limit = GLOBAL_DEFAULT_UNION_LIMIT

    # Deprecated
    warnonly = nothing
    enable = nothing

    for option in options
        if option isa Expr && option.head == :(=)
            if option.args[1] == :warnonly
                warnonly = option.args[2]
                continue
            elseif option.args[1] == :enable
                enable = option.args[2]
                continue
            elseif option.args[1] == :default_mode
                mode = option.args[2]
                continue
            elseif option.args[1] == :default_codegen_level
                codegen_level = option.args[2]
                continue
            elseif option.args[1] == :default_union_limit
                union_limit = option.args[2]
                continue
            end
        end
        error("Unknown macro option: $option")
    end

    mode = _parse_even_if_expr(mode, calling_module, String)
    codegen_level = _parse(codegen_level, String)
    union_limit = _parse(union_limit, Int)

    _validate_mode(mode)
    _validate_codegen_level(codegen_level)

    # Deprecated
    warnonly = _parse_even_if_expr(warnonly, calling_module, Bool)
    enable = _parse_even_if_expr(enable, calling_module, Bool)

    mode = if enable !== nothing
        @warn "The `enable` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
        if warnonly !== nothing
            @warn "The `warnonly` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
            warnonly ? "warn" : (enable ? "error" : "disable")
        else
            enable ? "error" : "disable"
        end
    else
        mode
    end

    options = StabilizationOptions(mode, codegen_level, union_limit)

    if calling_module != Core.Main
        # Local setting from Preferences.jl overrides defaults
        return get_all_preferred(options, calling_module)
    else
        return options
    end
end

function _validate_mode(mode)
    if mode ∉ ("error", "warn", "disable")
        error("Unknown mode: $mode. Please use \"error\", \"warn\", or \"disable\".")
    end
    return nothing
end
function _validate_codegen_level(codegen_level)
    if codegen_level ∉ ("debug", "min")
        error("Unknown codegen level: $codegen_level. Please use \"debug\" or \"min\".")
    end
    return nothing
end

# TODO: Deprecate passing expressions
function _parse_even_if_expr(ex::Expr, calling_module, ::Type{T}) where {T}
    return Core.eval(calling_module, ex)::T
end
_parse_even_if_expr(::Nothing, _, ::Type{T}) where {T} = nothing
_parse_even_if_expr(ex, _, ::Type{T}) where {T} = _parse(ex, T)
_parse(::Nothing, ::Type{T}) where {T} = nothing
_parse(ex::QuoteNode, ::Type{T}) where {T} = ex.value::T
_parse(ex, ::Type{T}) where {T} = ex::T

end
