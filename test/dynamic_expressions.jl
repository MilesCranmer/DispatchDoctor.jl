using Pkg
using Git
using TOML

mktempdir() do tempdir
    # Clone DynamicExpressions.jl at a fixed version
    repo_url = "https://github.com/SymbolicML/DynamicExpressions.jl.git"
    dest_dir = joinpath(tempdir, "DynamicExpressions")
    run(`$(git()) clone $repo_url $dest_dir`)
    run(`$(git()) -C $dest_dir checkout v2.2.0`)

    dd_path = dirname(dirname(@__FILE__))
    dd_toml_content = TOML.parsefile(joinpath(dd_path, "Project.toml"))
    dd_version = dd_toml_content["version"]

    # Modify compat in Project.toml
    project_toml_path = joinpath(dest_dir, "Project.toml")
    toml_content = TOML.parsefile(project_toml_path)
    toml_content["compat"]["DispatchDoctor"] = "=$dd_version"
    open(project_toml_path, "w") do io
        TOML.print(io, toml_content)
    end

    # Julia 1.12 world-age workaround:
    #
    # DynamicExpressions’ `@extend_operators` defines methods via `eval` during execution.
    # When this happens inside a single top-level expression (e.g. inside a `let` block),
    # calling the newly-extended operator in the same expression can dispatch to the old
    # method due to world age. This causes the upstream tests to execute the operator body
    # instead of building a `Node`.
    chainrules_path = joinpath(dest_dir, "test", "test_chainrules.jl")
    if isfile(chainrules_path)
        s = read(chainrules_path, String)
        s = replace(s, "nan_forward = bad_op(x1 + 0.5)" => "nan_forward = Base.invokelatest(bad_op, x1 + 0.5)")
        s = replace(s, "undefined_grad = undefined_grad_op(x1 + 0.5)" => "undefined_grad = Base.invokelatest(undefined_grad_op, x1 + 0.5)")
        s = replace(s, "nan_grad = bad_grad_op(x1)" => "nan_grad = Base.invokelatest(bad_grad_op, x1)")
        write(chainrules_path, s)
    end

    # Aqua.jl piracy check currently relies on internals that changed in Julia 1.12.
    # Keep the rest of Aqua checks enabled, but disable piracy on Julia ≥ 1.12 so
    # that DynamicExpressions' test suite can run in our CI matrix.
    aqua_path = joinpath(dest_dir, "test", "test_aqua.jl")
    if isfile(aqua_path)
        s = read(aqua_path, String)
        s = replace(
            s,
            "Aqua.test_all(DynamicExpressions; project_toml_formatting=false)" =>
                "Aqua.test_all(DynamicExpressions; project_toml_formatting=false, piracy = VERSION < v\"1.12.0\")",
        )
        write(aqua_path, s)
    end

    # Activate the environment
    Pkg.activate(dest_dir)
    Pkg.develop(; path=dd_path)
    Pkg.instantiate()

    # Run upstream tests
    Pkg.test()
end
