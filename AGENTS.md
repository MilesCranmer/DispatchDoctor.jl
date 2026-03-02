## Cursor Cloud specific instructions

### Overview
DispatchDoctor.jl is a pure Julia package (no external services, databases, or Docker) that provides the `@stable` macro for enforcing type-stable return values in Julia functions.

### Prerequisites
- **Julia >= 1.10** must be installed. The VM snapshot includes Julia 1.10.8 at `/opt/julia-1.10.8/bin/julia` (symlinked to `/usr/local/bin/julia`).

### Running tests
- **Unit tests:** `DISPATCH_DOCTOR_TEST=unit julia --project=. -e 'using Pkg; Pkg.test()'`
- **Integration tests** (optional, slower): Set `DISPATCH_DOCTOR_TEST` to `enzyme`, `zygote`, or `dynamic-expressions`, then `Pkg.test()`.
- Tests use `TestItemRunner` and `TestItems`. All 325 unit tests should pass.

### Formatting / Linting
- Uses **JuliaFormatter v1** (NOT v2) with Blue style (configured in `.JuliaFormatter.toml`).
- Install: `julia -e 'using Pkg; Pkg.add(name="JuliaFormatter", version="1")'`
- Check: `julia -e 'using JuliaFormatter; format(".", overwrite=false)'`
- Note: Some existing source files have minor formatting deviations; this is pre-existing.

### Key caveats
- The first `Pkg.test()` run after `Pkg.instantiate()` will precompile ~70 dependencies and takes ~2 minutes. Subsequent runs are faster.
- `JuliaFormatter` is installed in the default global environment (`~/.julia/environments/v1.10/`), not in the project environment. Use `julia -e '...'` (no `--project`) to access it.
- The `@stable` macro warnings during tests (e.g., "found no compatible functions to stabilize") are expected and part of the test suite.
- `TypeInstabilityError` has a `cause` field for chaining nested instabilities. When error mode detects instability, it calls the simulator to capture inner `TypeInstabilityError`s; non-`TypeInstabilityError` exceptions are rethrown.
