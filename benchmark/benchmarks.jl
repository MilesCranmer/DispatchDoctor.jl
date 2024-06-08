using BenchmarkTools
using DispatchDoctor: _stabilize_all

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

module EmptyModule
end

for mode in ("error", "warn", "disable")
    options = Any[:(default_mode=$mode)]
    SUITE["_stable"]["mode=$mode"] = @benchmarkable(
        $_stable(ex, options; calling_module, source_info=nothing),
        setup=(ex=$ex; options=$options; calling_module=EmptyModule)
    )
end