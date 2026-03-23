# Changelog

## [0.4.28](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.27...v0.4.28) (2026-02-01)

### Features

* allow specifying scope for registered macros ([241be7b](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/241be7b459574ad8df493c6bce8c7fa69f033b12))
* allow specifying scope for registered macros ([d89fa4f](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/d89fa4f5750242286f9beda278055fae8949376e))

## [0.4.27](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.26...v0.4.27) (2026-01-16)

## [0.4.26](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.25...v0.4.26) (2025-07-05)

### Bug Fixes

* skip `@opaque` closures ([87109c5](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/87109c5db341986d91ab4d2cf216c3ee6e4c35c1))
* skip `@opaque` closures ([f778f52](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/f778f5265f590e48927c0e2d2f467ac65dfe6e14))

## [0.4.25](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.24...v0.4.25) (2025-07-05)

### Bug Fixes

* issue with closures self-referencing ([ffb15e0](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/ffb15e0b5530995589527ff046c7d00613b0b7fa))
* issue with closures self-referencing ([25722c6](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/25722c626a2aff0628b22dcaed83413d81c3592e))
* nested allow_unstable ([f664652](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/f66465212927a67519ac6799696f8f71702b1088))
* nested allow_unstable ([489a0c2](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/489a0c2a9c580169d0ee950a5b3bd45e18bf743f))

## [0.4.24](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.23...v0.4.24) (2025-07-04)

### Bug Fixes

* deal with unbound args in signature ([83707ef](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/83707ef72150f37de6c7e97fd87311e6fe1a8609))
* deal with unbound args in signature ([48bec1f](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/48bec1f1d472c5fb4dcdb8c1083e907686b64bad))

## [0.4.23](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.22...v0.4.23) (2025-07-04)

### Bug Fixes

* duplicate LineNumberNodes in simulator function ([54db72d](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/54db72d862a16e09be2c57460e9d81c928b6e010))
* duplicate LineNumberNodes in simulator function ([0d4a517](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/0d4a5175aeac4d9b64ff99661cd802586e9eafeb))

## [0.4.22](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.21...v0.4.22) (2025-06-30)

## [0.4.21](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.20...v0.4.21) (2025-06-28)

### Bug Fixes

* Vararg detection in type instability ([8563149](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/85631497b0b71de9a1b1c6442d9b2c916a932c0b))
* Vararg detection in type instability ([590f2ae](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/590f2ae438da2019d3e3de30eaf0de107ce56fee))

## [0.4.20](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.19...v0.4.20) (2025-06-27)

### Features

* create Mooncake extension to prevent foreigncall derivative ([546a268](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/546a268a35e87761ec897a7f19d25932c8a42830))

## [0.4.19](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.18...v0.4.19) (2025-01-03)

### ⚠ BREAKING CHANGES

* update preference keys with soft deprecation ([#72](https://github.com/MilesCranmer/DispatchDoctor.jl/issues/72))

### Features

* update preference keys with soft deprecation ([#72](https://github.com/MilesCranmer/DispatchDoctor.jl/issues/72)) ([1e9a5e4](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/1e9a5e4e83748b2a3bb65b0338b63e957853d1d3))

## [0.4.18](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.17...v0.4.18) (2025-01-02)

### Bug Fixes

* behavior for Core.TypeofBottom ([#70](https://github.com/MilesCranmer/DispatchDoctor.jl/issues/70)) ([f413681](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/f413681fd3a7981889c57a0bfa4dd79b1d096037))

## [0.4.17](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.16...v0.4.17) (2024-10-27)

### Bug Fixes

* avoid `@nospecialize` methods ([1a9e51c](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/1a9e51cc493a5f3a06df572c9f22fdf6ff9ef428))
* avoid `@nospecialize` methods ([d12e684](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/d12e6846bae7386d9ee635592f7a2297a1e592aa))

## [0.4.16](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.15...v0.4.16) (2024-10-16)

### Bug Fixes

* issue with underscore arguments and min codegen ([2ef1556](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/2ef1556f92c50282a8a8b5b23d151275ebfbda28))

## [0.4.15](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.14...v0.4.15) (2024-09-23)

## [0.4.14](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.13...v0.4.14) (2024-08-14)

### Bug Fixes

* issue with union of tuples ([3eeb7c9](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/3eeb7c9ff70e5b92d3aa03d65a57bc15a902148c))

## [0.4.13](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.12...v0.4.13) (2024-08-04)

### Features

* mark DispatchDoctor functions as inactive to Enzyme ([e0132bf](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/e0132bf9356ecb3a97f18cfa800ea4cb4bcec5d4))
* mark DispatchDoctor functions as inactive to Enzyme ([6e4be29](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/6e4be298b2c22f4ae08c66cafbd98d607406dca1))
* use `EnzymeRules.inactive_noinl` for perf ([9e9a589](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/9e9a589815662db7839ef5aa2d83e3cd4baeb000))

## [0.4.12](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.11...v0.4.12) (2024-07-21)

## [0.4.11](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.10...v0.4.11) (2024-07-18)

### Bug Fixes

* absolute fix for precompilation segfault ([8431ab3](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/8431ab3fb2cbb86460bfe73289b5fdb7fa5b57e3))
* edge-case precompilation segfault on Julia 1.11 ([094b165](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/094b1651eeef3fb2017be46a48f0da13724e1123))

## [0.4.10](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.9...v0.4.10) (2024-07-10)

### Bug Fixes

* mark certain foreigncall expressions as nondifferentiable ([70fa5a8](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/70fa5a85d506184c360d5385f8336f4cb78f55d5))
* mark certain foreigncall expressions as nondifferentiable ([24e58ee](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/24e58ee2ad182e03d8c8e7f2b46a74d3b3910fff))

## [0.4.9](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.8...v0.4.9) (2024-07-09)

### Bug Fixes

* handle splatting in args ([054b482](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/054b4824869b95cb4c9b6cbb9a09328e22951222))
* handle splatting in args ([558f74c](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/558f74c0e07f6c5b09c582838c212e1d24b8aebe))
* instability induced in Zygote gradient; fixes [#46](https://github.com/MilesCranmer/DispatchDoctor.jl/issues/46) ([e71c61b](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/e71c61bf8ef660faab8956f9e797af81e4a123d1))

## [0.4.8](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.7...v0.4.8) (2024-07-05)

### Bug Fixes

* remove unused TestItems.jl import ([f3bdb32](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/f3bdb32aedf82c6aa06df439181e4aaee66cd9d5))

## [0.4.7](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.6...v0.4.7) (2024-06-09)

## [0.4.6](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.5...v0.4.6) (2024-06-08)

### Features

* ignore getproperty and setproperty! ([b8b281e](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/b8b281ee347aa28f21a5a02aba8691d34af59cfa))

## [0.4.5](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.4...v0.4.5) (2024-06-08)

## [0.4.4](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.3...v0.4.4) (2024-06-01)

## [0.4.3](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.2...v0.4.3) (2024-06-01)

## [0.4.2](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.1...v0.4.2) (2024-05-31)

## [0.4.1](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.4.0...v0.4.1) (2024-05-31)

## [0.4.0](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.3.1...v0.4.0) (2024-05-30)

## [0.3.1](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.3.0...v0.3.1) (2024-05-29)

## [0.3.0](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.2.1...v0.3.0) (2024-05-29)

## [0.2.1](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.2.0...v0.2.1) (2024-05-29)

## [0.2.0](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.1.2...v0.2.0) (2024-05-28)

## [0.1.2](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.1.1...v0.1.2) (2024-05-28)

## [0.1.1](https://github.com/MilesCranmer/DispatchDoctor.jl/compare/v0.1.0...v0.1.1) (2024-05-28)

## [0.1.0](https://github.com/MilesCranmer/DispatchDoctor.jl/releases/tag/v0.1.0) (2024-05-28)

### ⚠ BREAKING CHANGES

* avoid instability errors during precompilation

### Features

* always print source info for errors ([99ff00d](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/99ff00dbad672b854bf5805c6e3a19e5ad40e5cb))
* avoid instability errors during precompilation ([e8947ae](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/e8947ae3e4900b27076846a333366bc3d23b716d))
* create `allow_unstable` ([8e3b910](https://github.com/MilesCranmer/DispatchDoctor.jl/commit/8e3b910c4c6167f469113b59d6a9e82fbef0174e))
