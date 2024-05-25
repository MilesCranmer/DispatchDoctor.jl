using DispatchDoctor
using InteractiveUtils: code_llvm
using Test: @test

@stable f(x) = x
# Test that the LLVM IR is only 4 SLOC and
# therefore doesn't include the check
llvm_ir = sprint((args...) -> code_llvm(args...; debuginfo=:none), f, (Int,))

lines = split(llvm_ir, "\n")
filter!(l -> !isempty(l), lines)
filter!(l -> !startswith(l, ";"), lines)

# If Julia failed to optimize the code, we should expect
# to see some GC pool allocations:
@test !occursin(llvm_ir, "gc_pool_alloc")

# We can also test explicit number of lines:
if length(lines) != 4
    @show lines
end
@test length(lines) == 4
