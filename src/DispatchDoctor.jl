module DispatchDoctor

export @stable

using MacroTools: combinedef, splitdef
using Test: Test
using TestItems: @testitem

macro stable(fex)
    fdef = splitdef(fex)

    # We create a second f with the actual body
    fdef2 = splitdef(fex)
    fdef2_name = gensym("f2")
    fdef2_args = fdef2[:args]
    fdef2_kwargs = fdef2[:kwargs]
    fdef2_body = :($(fdef2_name)($(fdef2_args)...; $(fdef2_kwargs)...))

    fdef2[:name] = fdef2_name
    
    # And call this from the primary function, with the _inferred
    fdef[:body] = Test._inferred(fdef2_body, __module__)

    return quote
        $(combinedef(fdef2))
        $(combinedef(fdef))
    end
end

@testitem "stable" begin
    using MacroTools: splitdef

    @show splitdef(:(f(x::Int; a, b, c::Float32=1., kws...) = x))
end

end
