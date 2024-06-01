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
using .._Interactions:
    ignore_function,
    get_macro_behavior,
    IncompatibleMacro,
    CompatibleMacro,
    DontPropagateMacro
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
        out, metadata = _stabilize_all(ex, DownwardMetadata(); source_info, kws..., mode)
        if metadata.matching_function == 0
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

"""To communicate to the parent of the recursion."""
Base.@kwdef struct UpwardMetadata
    matching_function::Bool = false
    unused_macros::Vector{Any} = Any[]
    macro_keys::Vector{Symbol} = Symbol[]
end

function merge(a::UpwardMetadata, b::UpwardMetadata)
    @assert isempty(a.unused_macros) &&
        isempty(b.unused_macros) &&
        isempty(a.macro_keys) &&
        isempty(b.macro_keys)
    return UpwardMetadata(; matching_function=a.matching_function || b.matching_function)
end

"""To communicate to the leafs of the recursion."""
Base.@kwdef struct DownwardMetadata
    macros_to_use::Vector{Any} = Any[]
    macro_keys::Vector{Symbol} = Symbol[]
end

function UpwardMetadata(downward_metadata::DownwardMetadata; matching_function::Bool=false)
    return UpwardMetadata(;
        unused_macros=deepcopy(downward_metadata.macros_to_use),
        macro_keys=deepcopy(downward_metadata.macro_keys),
        matching_function,
    )
end

function _stabilize_all(ex, downward_metadata::DownwardMetadata; kws...)
    return ex, UpwardMetadata(downward_metadata)
end
function _stabilize_all(ex::Expr, downward_metadata::DownwardMetadata; kws...)
    #! format: off
    if ex.head == :macrocall && ex.args[1] == Symbol("@stable")
        # Avoid recursive tags
        return ex, UpwardMetadata(downward_metadata)
    elseif ex.head == :macrocall && ex.args[1] == Symbol("@unstable")
        # Allow disabling
        return ex, UpwardMetadata(downward_metadata)
    elseif ex.head == :macrocall
        macro_behavior = get_macro_behavior(ex.args[1])
        if macro_behavior == IncompatibleMacro
            return ex, UpwardMetadata(downward_metadata)
        elseif macro_behavior == CompatibleMacro
            # We build up a stack of macros to propagate to the function call
            # push!(macro_stack, ex.args[1:end-1])
            my_key = gensym()
            macros_to_use = deepcopy(downward_metadata.macros_to_use)
            macro_keys = deepcopy(downward_metadata.macro_keys)
            push!(macros_to_use, ex.args[1:end-1])
            push!(macro_keys, my_key)

            new_downward_metadata = DownwardMetadata(; macros_to_use, macro_keys)
            inner_ex, upward_metadata = _stabilize_all(ex.args[end], new_downward_metadata; kws...)

            if isempty(upward_metadata.unused_macros)
                # It has been applied! So we just return the inner part
                return inner_ex, upward_metadata
            else
                # Not applied, so we have to paste the macro back on
                @assert upward_metadata.macro_keys[end] == my_key
                @assert length(upward_metadata.unused_macros) == length(upward_metadata.macro_keys)

                new_ex = Expr(:macrocall, upward_metadata.unused_macros[end]..., inner_ex)
                new_upward_metadata = UpwardMetadata(; 
                    matching_function = upward_metadata.matching_function,
                    unused_macros = upward_metadata.unused_macros[1:end-1],
                    macro_keys = upward_metadata.macro_keys[1:end-1],
                )
                return new_ex, new_upward_metadata
            end
        else
            @assert macro_behavior == DontPropagateMacro

            # Apply to last argument only
            inner_ex, upward_metadata = _stabilize_all(ex.args[end], downward_metadata; kws...)
            new_ex = Expr(:macrocall, ex.args[1:end-1]..., inner_ex)
            return new_ex, upward_metadata
        end
    elseif ex.head == :macro
        # Do nothing inside macros (in case of closure)
        return ex, UpwardMetadata(downward_metadata)
    elseif ex.head == :quote
        # Do nothing inside of quotes
        return ex, UpwardMetadata(downward_metadata)
    elseif ex.head == :global
        # Incompatible with two functions
        return ex, UpwardMetadata(downward_metadata)
    elseif ex.head == :module
        return _stabilize_module(ex, downward_metadata; kws...)
    elseif ex.head == :call && ex.args[1] == Symbol("include") && length(ex.args) == 2
        # We can't track the matches in includes, so just assume
        # there are some matches. TODO: However, this is not a great solution.
        # Replace include with DispatchDoctor version
        matching_function = true
        return :($(_stabilizing_include)(@__MODULE__, $(ex.args[2]); $(kws)...)), UpwardMetadata(downward_metadata; matching_function)
    elseif isdef(ex) && @capture(longdef(ex), function (fcall_ | fcall_) body_ end)
        #               ^ This is the same check done by `splitdef`
        # TODO: Should report `isdef` to MacroTools as not capturing all cases
        return _stabilize_fnc(ex, downward_metadata; kws...)
    else
        stabilized_args = map(e -> _stabilize_all(e, DownwardMetadata(); kws...), ex.args)
        merged_upward_metadata = reduce(merge, map(last, stabilized_args); init=UpwardMetadata())
        new_ex = Expr(ex.head, map(first, stabilized_args)...)
        return new_ex, UpwardMetadata(downward_metadata; matching_function=merged_upward_metadata.matching_function)
    end
    #! format: on
end

function _stabilizing_include(m::Module, path; kws...)
    inner = let kws=kws
        (ex,) -> let
            new_ex, upward_metadata = _stabilize_all(ex, DownwardMetadata(); kws...)
            @assert isempty(upward_metadata.unused_macros)
            new_ex
        end
    end
    return m.include(inner, path)
end

function _stabilize_module(ex, downward_metadata; kws...)
    stabilized_args = map(
        e -> _stabilize_all(e, DownwardMetadata(); kws...), ex.args[3].args
    )
    merged_upward_metadata = reduce(
        merge, map(last, stabilized_args); init=UpwardMetadata()
    )
    new_ex = Expr(
        :module, ex.args[1], ex.args[2], Expr(:block, map(first, stabilized_args)...)
    )
    return new_ex,
    UpwardMetadata(
        downward_metadata; matching_function=merged_upward_metadata.matching_function
    )
end

function _stabilize_fnc(
    fex::Expr,
    downward_metadata::DownwardMetadata;
    mode::String="error",
    source_info::Union{LineNumberNode,Nothing}=nothing,
)
    func = splitdef(fex)

    if haskey(func, :params) && length(func[:params]) > 0
        # Incompatible with parameterized functions
        return fex, UpwardMetadata(downward_metadata)
    elseif haskey(func, :name) && !is_function_name_compatible(func[:name])
        return fex, UpwardMetadata(downward_metadata)
    end

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

    ignore_func = haskey(func, :name) ? :($(ignore_function)($(func[:name]))) : :(false)

    func_simulator[:name] = simulator
    func[:body] = quote
        $T = $checker
        if $(type_instability)($T) &&
            !$ignore_func &&
            !$(is_precompiling)() &&
            $(checking_enabled)()
            $err
        end

        $(func[:body])
    end

    func_simulator_ex = combinedef(func_simulator)
    func_ex = combinedef(func)

    # We apply other macros to both the function and the simulator
    for macro_element in Iterators.reverse(downward_metadata.macros_to_use)
        func_ex = Expr(:macrocall, macro_element..., func_ex)
        func_simulator_ex = Expr(:macrocall, macro_element..., func_simulator_ex)
    end

    final_ex = quote
        $(func_simulator_ex)
        $(Base).@__doc__ $(func_ex)
    end
    return final_ex, UpwardMetadata(; matching_function=true)  # Clean metadata – all macros were consumed
end

end
