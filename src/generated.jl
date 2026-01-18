"""Generated inference helpers for DispatchDoctor."""
module _Generated

using Core.Compiler

using .._Utils: type_instability, type_instability_limit_unions

struct DDInterpOwner end
Base.@kwdef struct DDInterp <: Compiler.AbstractInterpreter
    world::UInt = Base.get_world_counter()
    inf_params::Compiler.InferenceParams = Compiler.InferenceParams()
    opt_params::Compiler.OptimizationParams = Compiler.OptimizationParams()
    inf_cache::Vector{Compiler.InferenceResult} = Compiler.InferenceResult[]
    codegen_cache::IdDict{Core.CodeInstance,Core.CodeInfo} = IdDict{Core.CodeInstance,Core.CodeInfo}()
end
Base.Experimental.@MethodTable DDMT

struct GeneratedCfgTag{UnionLimit,HasKw} end

Compiler.InferenceParams(interp::DDInterp) = interp.inf_params
Compiler.OptimizationParams(interp::DDInterp) = interp.opt_params
Compiler.get_inference_world(interp::DDInterp) = interp.world
Compiler.get_inference_cache(interp::DDInterp) = interp.inf_cache
Compiler.cache_owner(::DDInterp) = DDInterpOwner()
Compiler.codegen_cache(interp::DDInterp) = interp.codegen_cache
Compiler.method_table(interp::DDInterp) = Compiler.OverlayMethodTable(interp.world, DDMT)

function _cfg_from_tag(::Type{GeneratedCfgTag{UnionLimit,HasKw}}) where {UnionLimit,HasKw}
    union_limit = UnionLimit::Int
    has_kwargs = HasKw::Bool
    return union_limit, has_kwargs
end

function _tt_cfg_from_sig(sig::DataType, world::UInt)
    @nospecialize sig
    tt = try
        Core.apply_type(Tuple, sig.parameters[2:end]...)
    catch
        sig
    end
    tt isa Type{<:Tuple} ||
        error("_generated_instability_info expected a config-tagged Tuple type; got $sig")
    union_limit, has_kwargs = _cfg_from_tag(sig.parameters[1]::Type{<:GeneratedCfgTag})
    return tt, union_limit, has_kwargs
end

function _inferred_return_type(tt::Type{<:Tuple}, has_kwargs::Bool, world::UInt)
    @nospecialize tt
    call_tt = if has_kwargs
        func_type = tt.parameters[1]
        kwtype = tt.parameters[2]
        argtypes = tt.parameters[3:end]
        Core.apply_type(Tuple, typeof(Core.kwcall), kwtype, func_type, argtypes...)
    else
        tt
    end

    matches = Base._methods_by_ftype(call_tt, -1, world)
    if isnothing(matches) || isempty(matches)
        return Union{}, matches
    end

    interp = DDInterp(world=world)
    inferred = Union{}
    for match in matches
        ret = Compiler.widenconst(Compiler.typeinf_type(interp, match))
        inferred = Compiler.tmerge(inferred, ret)
    end
    return inferred, matches
end

function _instability_info(
    tt::Type{<:Tuple}, union_limit::Int, has_kwargs::Bool, world::UInt
)
    rettype, matches = _inferred_return_type(tt, has_kwargs, world)
    unstable = if union_limit > 1
        type_instability_limit_unions(rettype, Val(union_limit))
    else
        type_instability(rettype)
    end
    return (unstable, rettype), matches
end

function _expr_to_codeinfo(m::Module, argnames, spnames, e::Expr, isva)
    body = Expr(:block, Expr(:return, Expr(:block, e)))
    scope = Expr(Symbol("scope-block"), body)
    lambda = Expr(:lambda, argnames, scope)
    ex = if isnothing(spnames) || isempty(spnames)
        lambda
    else
        Expr(Symbol("with-static-parameters"), lambda, spnames...)
    end
    ci = Base.generated_body_to_codeinfo(ex, @__MODULE__(), isva)
    @assert ci isa Core.CodeInfo "Failed to create a CodeInfo from the given expression. This might mean it contains a closure or comprehension?\n Offending expression: $e"
    return ci
end

function _generated_instability_info_body(world::UInt, lnn, this, sig)
    sig = sig.parameters[1]
    tt, union_limit, has_kwargs = _tt_cfg_from_sig(sig, world)
    (unstable, rettype), matches = _instability_info(tt, union_limit, has_kwargs, world)

    ci = _expr_to_codeinfo(
        @__MODULE__(),
        [Symbol("#self#"), :sig],
        [],
        :(return ($unstable, $(QuoteNode(rettype)))),
        false,
    )

    if !isnothing(matches)
        ci.edges = Any[]
        for match in matches
            mi = Base.specialize_method(match)
            push!(ci.edges, mi)
        end
    end
    return ci
end

#! format: off
function _refresh_generated_instability_info()
    @eval function _generated_instability_info(sig::Type{<:Tuple{<:GeneratedCfgTag,Vararg{Any}}})
        $(Expr(:meta, :generated_only))
        $(Expr(:meta, :generated, _generated_instability_info_body))
    end

    @eval Base.Experimental.@overlay DDMT _generated_instability_info(sig) = (false, Union{})
end
#! format: on

_refresh_generated_instability_info()

end
