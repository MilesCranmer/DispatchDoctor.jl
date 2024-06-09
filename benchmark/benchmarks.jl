using BenchmarkTools
using DispatchDoctor: DispatchDoctor, _stable

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
