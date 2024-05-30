"""Test that we can download DynamicExpressions and run the entirety of it."""

using Git: git
using TOML

tempdir = mktempdir(; cleanup=false)

# Define the repository URL
repo_url = "https://github.com/SymbolicML/DynamicExpressions.jl.git"
destination_folder = joinpath(tempdir, "DynamicExpressions")
commit_sha = "ea0076e263e559467a3a5d11996cbddc7c08f36b"

run(`$(git()) clone --depth=1 "$repo_url" "$destination_folder"`)

# Make edits to use DispatchDoctor:
let
    dynamic_expressions_path = joinpath(destination_folder, "src", "DynamicExpressions.jl")

    contents = read(dynamic_expressions_path, String)
    lines = split(contents, "\n")

    insert!(lines, 2, "using DispatchDoctor: @stable, @unstable")
    insert!(lines, 3, "@stable default_mode=\"warn\" begin")

    # Find the index of the line to insert 'end' after 'include("Random.jl")'
    index = findfirst(isequal("include(\"Random.jl\")"), lines)
    insert!(lines, index + 1, "end")

    # Prepend '@unstable' to 'include("Simplify.jl")'
    index_simplify = findfirst(isequal("include(\"Simplify.jl\")"), lines)
    lines[index_simplify] = "@unstable " * lines[index_simplify]

    # Prepend '@unstable' to 'include("OperatorEnumConstruction.jl")'
    index_operator = findfirst(isequal("include(\"OperatorEnumConstruction.jl\")"), lines)
    lines[index_operator] = "@unstable " * lines[index_operator]

    new_contents = join(lines, "\n")

    write(dynamic_expressions_path, new_contents)
end

# Add the current package
let
    dispatch_doctor_dir = dirname(dirname(@__FILE__))
    julia_command_develop = Cmd([
        "-e",
        "using Pkg; Pkg.activate(\"$destination_folder\"); Pkg.develop(PackageSpec(path=\"$dispatch_doctor_dir\"))",
    ])
    run(`$(Base.julia_cmd()) $julia_command_develop`)

    # Now, tweak the Project.toml to set the compat to 0.0.0-999.999.999:
    project_toml_path = joinpath(destination_folder, "Project.toml")
    project_toml = TOML.parsefile(project_toml_path)
    project_toml["compat"]["DispatchDoctor"] = "0.0.0 - 999.999.999"
    open(project_toml_path, "w") do io
        TOML.print(io, project_toml)
    end
end

# Finally, run the test:
let
    julia_command_test = Cmd([
        "-e",
        "using Pkg; Pkg.activate(\"$destination_folder\"); Pkg.test(\"DynamicExpressions\")",
    ])
    run(`$(Base.julia_cmd()) $julia_command_test`)
end
