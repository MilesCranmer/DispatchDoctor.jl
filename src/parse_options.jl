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

    # Load in any expression-based options
    #! format: off
    mode = mode isa Expr ? Core.eval(calling_module, mode) : (mode isa QuoteNode ? mode.value : mode)
    codegen_level = codegen_level isa QuoteNode ? codegen_level.value : codegen_level
    union_limit = union_limit isa QuoteNode ? union_limit.value : union_limit
    #! format: on
    # TODO: Deprecate passing expression here.

    if mode ∉ ("error", "warn", "disable")
        error("Unknown mode: $mode. Please use \"error\", \"warn\", or \"disable\".")
    end
    if codegen_level ∉ ("debug", "min")
        error("Unknown codegen level: $codegen_level. Please use \"debug\" or \"min\".")
    end

    mode::String
    codegen_level::String
    union_limit::Int

    # Deprecated
    warnonly = warnonly isa Expr ? Core.eval(calling_module, warnonly) : warnonly
    enable = enable isa Expr ? Core.eval(calling_module, enable) : enable

    if enable !== nothing
        @warn "The `enable` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
        if warnonly !== nothing
            @warn "The `warnonly` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
            mode = warnonly ? "warn" : (enable ? "error" : "disable")
        else
            mode = enable ? "error" : "disable"
        end
    end

    options = StabilizationOptions(mode, codegen_level, union_limit)

    if calling_module != Core.Main
        # Local setting from Preferences.jl overrides defaults
        return get_all_preferred(options, calling_module)
    else
        return options
    end
end

end
