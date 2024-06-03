module _ParseOptions

using .._Preferences:
    get_preferred,
    GLOBAL_DEFAULT_MODE,
    GLOBAL_DEFAULT_CODEGEN_LEVEL,
    GLOBAL_DEFAULT_IGNORE_UNION

struct StabilizationOptions
    mode::String
    codegen_level::String
    ignore_union::Bool
end

function parse_options(options, calling_module)
    # Standard defaults:
    mode = GLOBAL_DEFAULT_MODE
    codegen_level = GLOBAL_DEFAULT_CODEGEN_LEVEL
    ignore_union = GLOBAL_DEFAULT_IGNORE_UNION

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
            elseif option.args[1] == :default_ignore_union
                ignore_union = option.args[2]
                continue
            end
        end
        error("Unknown macro option: $option")
    end

    # Load in any expression-based options
    #! format: off
    mode = mode isa Expr ? Core.eval(calling_module, mode) : (mode isa QuoteNode ? mode.value : mode)
    codegen_level = codegen_level isa QuoteNode ? codegen_level.value : codegen_level
    ignore_union = ignore_union isa QuoteNode ? ignore_union.value : ignore_union
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
    ignore_union::Bool

    # Deprecated
    warnonly = warnonly isa Expr ? Core.eval(calling_module, warnonly) : warnonly
    enable = enable isa Expr ? Core.eval(calling_module, enable) : enable

    if calling_module != Core.Main
        # Local setting from Preferences.jl overrides defaults
        #! format: off
        mode = get_preferred(mode, calling_module, "instability_check")
        codegen_level = get_preferred(codegen_level, calling_module, "instability_check_codegen")
        ignore_union = get_preferred(ignore_union, calling_module, "instability_check_ignore_union")
        #! format: on
        # TODO: Why do we need this try-catch? Seems like its used by e.g.,
        # https://github.com/JuliaLang/PrecompileTools.jl/blob/a99446373f9a4a46d62a2889b7efb242b4ad7471/src/workloads.jl#L2C10-L11
    end
    if enable !== nothing
        @warn "The `enable` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
        if warnonly !== nothing
            @warn "The `warnonly` option is deprecated. Please use `default_mode` instead, either \"error\", \"warn\", or \"disable\"."
            mode = warnonly ? "warn" : (enable ? "error" : "disable")
        else
            mode = enable ? "error" : "disable"
        end
    end
    return StabilizationOptions(mode, codegen_level, ignore_union)
end

end
