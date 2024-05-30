"""This module holds the main processing functions for `@stable`"""
module _Stabilization

using MacroTools: @capture, combinedef, splitdef, isdef, longdef

using .._Utils:
    specializing_typeof,
    is_function_name_compatible,
    get_first_source_info,
    inject_symbol_to_arg,
    extract_symbol,
    type_instability
using .._Errors: TypeInstabilityError, TypeInstabilityWarning
using .._Preferences: get_preferred_mode
using .._MacroInteractions:
    get_macro_behavior, IncompatibleMacro, CompatibleMacro, DontPropagateMacro
using .._RuntimeChecks: is_precompiling, checking_enabled

function _stable(args...; calling_module, source_info, kws...)
    options, ex = args[begin:(end - 1)], args[end]

    # Standard defaults:
    mode = "error"

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
            end
        end
        error("Unknown macro option: $option")
    end

    # Load in any expression-based options
    mode = if mode isa Expr
        Core.eval(calling_module, mode)
    else
        (mode isa QuoteNode ? mode.value : mode)
    end

    # Deprecated
    warnonly = warnonly isa Expr ? Core.eval(calling_module, warnonly) : warnonly
    enable = enable isa Expr ? Core.eval(calling_module, enable) : enable

    if calling_module != Core.Main
        # Local setting from Preferences.jl overrides defaults
        mode = get_preferred_mode(mode, calling_module)
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
    if mode in ("error", "warn")
        num_matches = Ref(0)
        out = _stabilize_all(ex, num_matches; source_info, kws..., mode)
        if num_matches[] == 0
            @warn(
                "`@stable` found no compatible functions to stabilize",
                source_info = source_info,
                calling_module = calling_module,
            )
        end
        return out
    elseif mode == "disable"
        return ex
    else
        error("Unknown mode: $mode. Please use \"error\", \"warn\", or \"disable\".")
    end
end

function _stabilize_all(ex, num_matches::Ref{Int}, macro_stack::Vector{Any}=Any[]; kws...)
    return ex
end
function _stabilize_all(
    ex::Expr, num_matches::Ref{Int}, macro_stack::Vector{Any}=Any[]; kws...
)
    #! format: off
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@unstable")
        # Allow disabling
        return ex
    elseif ex.head == :macrocall
        macro_behavior = get_macro_behavior(ex.args[1])
        if macro_behavior == IncompatibleMacro
            return ex
        elseif macro_behavior == CompatibleMacro
            # We build up a stack of macros to propagate to the function call
            push!(macro_stack, ex.args[1:end-1])
            return _stabilize_all(ex.args[end], num_matches, macro_stack; kws...)
        else
            @assert macro_behavior == DontPropagateMacro
            return Expr(:macrocall, ex.args[1], map(e -> _stabilize_all(e, num_matches; kws...), ex.args[2:end])...)
        end
    elseif ex.head == :macro
        # Do nothing inside macros (in case of closure)
        return ex
    elseif ex.head == :quote
        # Do nothing inside of quotes
        return ex
    elseif ex.head == :global
        # Incompatible with two functions
        return ex
    elseif ex.head == :module
        return _stabilize_module(ex, num_matches; kws...)
    elseif ex.head == :call && ex.args[1] == Symbol("include") && length(ex.args) == 2
        # We can't track the matches in includes, so just assume
        # there are some matches. TODO: However, this is not a great solution.
        num_matches[] += 1
        # Replace include with DispatchDoctor version
        return :($(_stabilizing_include)(@__MODULE__, $(ex.args[2]), $num_matches; $(kws)...))
    elseif isdef(ex) && @capture(longdef(ex), function (fcall_ | fcall_) body_ end)
        #               ^ This is the same check done by `splitdef`
        # TODO: Should report `isdef` to MacroTools as not capturing all cases
        return _stabilize_fnc(ex, num_matches, macro_stack; kws...)
    else
        return Expr(ex.head, map(e -> _stabilize_all(e, num_matches; kws...), ex.args)...)
    end
    #! format: on
end

function _stabilizing_include(m::Module, path, num_matches::Ref{Int}; kws...)
    return m.include(ex -> _stabilize_all(ex, num_matches; kws...), path)
end

function _stabilize_module(ex, num_matches::Ref{Int}; kws...)
    ex = Expr(
        :module,
        ex.args[1],
        ex.args[2],
        Expr(:block, map(e -> _stabilize_all(e, num_matches; kws...), ex.args[3].args)...),
    )
    return ex
end

function _stabilize_fnc(
    fex::Expr,
    num_matches::Ref{Int},
    macro_stack::Vector{Any}=Any[];
    mode::String="error",
    source_info::Union{LineNumberNode,Nothing}=nothing,
)
    func = splitdef(fex)

    if haskey(func, :params) && length(func[:params]) > 0
        # Incompatible with parameterized functions
        return fex
    elseif haskey(func, :name) && !is_function_name_compatible(func[:name])
        return fex
    end

    # It's a match, so increment the number of matches
    num_matches[] += 1

    func_simulator = splitdef(deepcopy(fex))

    # Load any information about the source
    searched_source_info = get_first_source_info(fex)
    source_info = if searched_source_info isa LineNumberNode
        string(searched_source_info.file, ":", searched_source_info.line)
    elseif source_info isa LineNumberNode
        string(source_info.file, ":", source_info.line)
    else
        nothing
    end

    if haskey(func, :name)
        name = string(func[:name])
        print_name = string("`", name, "`")
    else
        name = "anonymous_function"
        print_name = "anonymous function"
    end

    args = map(inject_symbol_to_arg, func[:args])
    kwargs = func[:kwargs]
    where_params = func[:whereparams]

    func[:args] = args
    func_simulator[:args] = deepcopy(args)

    arg_symbols = map(extract_symbol, args)
    kwarg_symbols = map(extract_symbol, kwargs)
    where_param_symbols = map(extract_symbol, where_params)

    simulator = gensym(string(name, "_simulator"))
    T = gensym(string(name, "_return_type"))

    err = if mode == "error"
        :(throw(
            $(TypeInstabilityError)(
                $(print_name),
                $(source_info),
                ($(arg_symbols...),),
                (; $(kwarg_symbols...)),
                ($(where_param_symbols) .=> ($(where_param_symbols...),)),
                $T,
            ),
        ))
    elseif mode == "warn"
        :(@warn(
            $(TypeInstabilityWarning)(
                $(print_name),
                $(source_info),
                ($(arg_symbols...),),
                (; $(kwarg_symbols...)),
                ($(where_param_symbols) .=> ($(where_param_symbols...),)),
                $T,
            ),
        ))
    else
        error("Unknown mode: $mode. Please use \"error\" or \"warn\".")
    end

    checker = if isempty(kwarg_symbols)
        :($(Base).promote_op($simulator, map($specializing_typeof, ($(arg_symbols...),))...))
    else
        :($(Base).promote_op(
            Core.kwcall,
            typeof((; $(kwarg_symbols...))),
            typeof($simulator),
            map($specializing_typeof, ($(arg_symbols...),))...,
        ))
    end

    func_simulator[:name] = simulator
    func[:body] = quote
        $T = $checker
        if $(type_instability)($T) && !$(is_precompiling)() && $(checking_enabled)()
            $err
        end

        $(func[:body])
    end

    func_simulator_ex = combinedef(func_simulator)
    func_ex = combinedef(func)

    # We apply other macros to both the function and the simulator
    for macro_element in macro_stack
        func_ex = Expr(:macrocall, macro_element..., func_ex)
        func_simulator_ex = Expr(:macrocall, macro_element..., func_simulator_ex)
    end

    return quote
        $(func_simulator_ex)
        $(Base).@__doc__ $(func_ex)
    end
end

end
