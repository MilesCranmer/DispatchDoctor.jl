using BenchmarkTools
using DispatchDoctor: DispatchDoctor, _stable, @stable

const SUITE = BenchmarkGroup()

ex = quote
    f() = rand(Bool) ? 0 : 1.0
    f(x) = x
    module A
    function g(; a, b)
        return a + b
    end

    module B
        $(DispatchDoctor).@unstable begin
            h() = rand(Bool) ? 0 : 1.0
        end
    end
    end
end

for mode in ("error", "warn", "disable")
    options = Any[:(default_mode = $mode)]
    SUITE["_stable"]["mode=$mode"] = @benchmarkable(
        $_stable(options..., ex; calling_module=nothing, source_info=nothing),
        setup = (ex = $(QuoteNode(ex)); options = $options)
    )
end

@stable type_arg(::Type{T}, x) where {T} = T(x)
SUITE["call"]["Type argument"] = @benchmarkable(map(x -> type_arg(Int, x), 1:10^4))

@eval @stable wide($([Symbol(:x, i) for i in 1:36]...)) = x1 + x36
@eval call_wide() = wide($(1:36...))
SUITE["call"]["36 arguments"] = @benchmarkable(call_wide())
