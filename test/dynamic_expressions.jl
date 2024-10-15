using Pkg
using Git
using TOML

mktempdir() do tempdir
    # Clone DynamicExpressions.jl at version v1.2.0
    repo_url = "https://github.com/SymbolicML/DynamicExpressions.jl.git"
    dest_dir = joinpath(tempdir, "DynamicExpressions")
    run(`$(git()) clone $repo_url $dest_dir`)
    run(`$(git()) -C $dest_dir checkout v1.2.0`)

    # Modify compat in Project.toml
    project_toml_path = joinpath(dest_dir, "Project.toml")
    toml_content = TOML.parsefile(project_toml_path)
    delete!(toml_content["compat"], "DispatchDoctor")
    open(project_toml_path, "w") do io
        TOML.print(io, toml_content)
    end

    # Activate the environment
    Pkg.activate(dest_dir)
    Pkg.develop(; path=dirname(dirname(@__FILE__)))
    Pkg.instantiate()

    # Run tests
    Pkg.test()
end
