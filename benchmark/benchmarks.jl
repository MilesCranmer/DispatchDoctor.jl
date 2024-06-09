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
            using DispatchDoctor: @unstable
            @unstable h() = rand(Bool) ? 0 : 1.0

            @unstable begin
                h(x::Int) = rand(Bool) ? 0 : 1.0
            end
        end
    end
end

for mode in ("error", "warn", "disable")
    options = Any[:(default_mode=$mode)]
    SUITE["_stable"]["mode=$mode"] = @benchmarkable(
        $(_stable)(ex, options; calling_module=nothing, source_info=nothing),
        setup=(ex=$ex; options=$options)
    )
end
