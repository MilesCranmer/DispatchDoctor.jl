"""This module contains various utility functions"""
module _Utils

using MacroTools: @capture

# Compatible Julia versions
const JULIA_OK = let
    JULIA_LOWER_BOUND = v"1.10.0-DEV.0"
    JULIA_UPPER_BOUND = v"1.12.0-DEV.0"
    # TODO: Get exact lower/upper bounds

    VERSION >= JULIA_LOWER_BOUND && VERSION < JULIA_UPPER_BOUND
end

struct Unknown
    msg::String
end

# Used to check if a function name is compatible with `@stable`
is_function_name_compatible(ex) = false
is_function_name_compatible(ex::Symbol) = true
is_function_name_compatible(ex::Expr) = ex.head == :(.) && all(is_symbol_like, ex.args)
is_symbol_like(ex) = false
is_symbol_like(ex::QuoteNode) = is_symbol_like(ex.value)
is_symbol_like(ex::Symbol) = true

function extract_symbol(ex::Symbol, fullex=ex)
    if ex == Symbol("_")
        return Unknown("_")
    else
        return ex
    end
end
function extract_symbol(ex::Expr, fullex=ex)
    #! format: off
    if ex.head == :(::) && length(ex.args) > 1 && @capture(ex.args[2], Vararg | Vararg{_} | Vararg{_,_})
        return :($(ex.args[1])...)
    elseif ex.head in (:kw, :(::), :(<:))
        out = extract_symbol(ex.args[1], ex)
        return out isa Unknown ? Unknown(string(ex)) : out
    elseif ex.head == :(...) && ex.args[1] isa Expr && ex.args[1].head == :(::)
        # Such as `a::Int...`
        return :($(ex.args[1].args[1])...)
    elseif ex.head in (:tuple, :(...))
        return ex
    else
        return Unknown(string(ex))
    end
    #! format: on
end

"""
Fix args that do not have a symbol or are destructured in the signature. Return gensymmed
arg expression and, if needed, an equivalent destructuring assignment for the body.
"""
function inject_symbol_to_arg(ex::Symbol)::Tuple{Union{Expr,Symbol},Union{Expr,Nothing}}
    return ex, nothing
end
function inject_symbol_to_arg(ex::Expr)::Tuple{Union{Expr,Symbol},Union{Expr,Nothing}}
    if ex.head == :(tuple)
        # Base case: matches things like (x,) and (; x)
        arg = gensym("arg")
        return arg, Expr(:(=), ex, arg)
    elseif ex.head == :(::) && length(ex.args) == 1
        # Base case: matches things like `::T`
        arg = gensym("arg")
        return Expr(:(::), arg, ex.args[1]), nothing
    elseif ex.head == :(::) && length(ex.args) == 2
        # Composite case: matches things like `(x,)::T` and `(; x)::T`
        arg_ex, destructure_ex = inject_symbol_to_arg(ex.args[1])
        return Expr(:(::), arg_ex, ex.args[2]), destructure_ex
    elseif ex.head == :(kw) && length(ex.args) == 2
        # Composite case: matches things like `::Type{T}=MyType`
        arg_ex, destructure_ex = inject_symbol_to_arg(ex.args[1])
        return Expr(:(kw), arg_ex, ex.args[2]), destructure_ex
    elseif ex.head == :(...) && length(ex.args) == 1
        # Composite case: matches things like `::Int...`
        arg_ex, destructure_ex = inject_symbol_to_arg(ex.args[1])
        return Expr(:(...), arg_ex), destructure_ex
    else
        return ex, nothing
    end
end

get_first_source_info(ex) = nothing
get_first_source_info(l::LineNumberNode) = l
function get_first_source_info(s::Expr)
    for arg in s.args
        extracted_arg = get_first_source_info(arg)
        if extracted_arg isa LineNumberNode
            return extracted_arg
        end
    end
    return nothing
end

# typeof but returns Type{T} for a type T input
specializing_typeof(::T) where {T} = T
specializing_typeof(::Type{T}) where {T} = Type{T}
specializing_typeof(::Val{T}) where {T} = Val{T}
map_specializing_typeof(args::Tuple) = map(specializing_typeof, args)

function _promote_op(f, S::Vararg{Type})
    if @generated
        # TODO: Remove once if this compilation issue is fixed within Julia:
        # https://github.com/MilesCranmer/DispatchDoctor.jl/issues/51
        :(Base.promote_op(f, S...))
    else
        Base.promote_op(f, S...)
    end
end
@static if isdefined(Core, :kwcall)
    function _promote_op(
        ::typeof(Core.kwcall), ::Type{Kwargs}, ::Type{F}, S::Tuple
    ) where {Kwargs,F}
        return Base.promote_op(Core.kwcall, Kwargs, F, S...)
    end
end

"""
    type_instability(T::Type)

Returns true if this type is not concrete. Will also
return false for `Union{}`, so that errors can propagate.
"""
@inline type_instability(::Type{T}) where {T} = !Base.isconcretetype(T)
@inline type_instability(::Type{Union{}}) = false

# Weirdly, Base.isconcretetype flags Type{T} itself as not concrete,
# so we implement a workaround.
@inline type_instability(::Type{Type{T}}) where {T} = type_instability(T)

@generated function type_instability_limit_unions(
    ::Type{T}, ::Val{union_limit}
) where {T,union_limit}
    if T isa UnionAll
        return true
    elseif T <: Tuple
        # So that Tuple{Union{Float32,Float64}} works as expected
        return any(Base.Fix2(type_instability_limit_unions, Val(union_limit)), T.types)
    else
        return _type_instability_recurse_unions(T) || _count_unions(T) > union_limit
    end
end

_count_unions(::Type{T}) where {T} = T isa Union ? (1 + _count_unions(T.b)) : 1

function _type_instability_recurse_unions(::Type{T}) where {T}
    if T isa Union
        type_instability(T.a) || _type_instability_recurse_unions(T.b)
    else
        type_instability(T)
    end
end

end
