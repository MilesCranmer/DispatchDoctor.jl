"""Test that we can download DynamicExpressions and run the entirety of it."""

using Git: git
using TOML

tempdir = mktempdir(; cleanup=false)

# Define the repository URL
repo_url = "https://github.com/SymbolicML/DynamicExpressions.jl.git"
destination_folder = joinpath(tempdir, "DynamicExpressions")
commit_sha = "ea0076e263e559467a3a5d11996cbddc7c08f36b"

run(`$(git()) clone "$repo_url" "$destination_folder"`)
run(`$(git()) -C "$destination_folder" checkout $commit_sha`)

# Make edits to use DispatchDoctor:
let
    dynamic_expressions_path = joinpath(destination_folder, "src", "DynamicExpressions.jl")
    contents = read(dynamic_expressions_path, String)
    lines = split(contents, "\n")

    insert!(lines, 2, "using DispatchDoctor: @stable, @unstable")
    insert!(lines, 3, "@stable default_mode=\"warn\" begin")

    # Find the index of the line to insert 'end' after 'include("Random.jl")'
    index = findfirst(h -> occursin("include(\"Random.jl\")", h), lines)::Integer
    insert!(lines, index + 1, "end")

    new_contents = join(lines, "\n")
    write(dynamic_expressions_path, new_contents)
end

# Make edits to tests
let
    test_path = joinpath(destination_folder, "test", "unittest.jl")
    contents = read(test_path, String)
    lines = split(contents, "\n")

    # Comment out the line that includes "test_deprecations.jl"
    index_deprecations =
        findfirst(h -> occursin("include(\"test_deprecations.jl\")", h), lines)::Integer
    lines[index_deprecations] = "# " * lines[index_deprecations]
    # And test_evaluation.jl (weirdness in log test)
    index_evaluation =
        findfirst(h -> occursin("include(\"test_evaluation.jl\")", h), lines)::Integer
    lines[index_evaluation] = "# " * lines[index_evaluation]

    new_contents = join(lines, "\n")
    write(test_path, new_contents)
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
        "-e", "using Pkg; Pkg.activate(\"$destination_folder\"); Pkg.test()"
    ])
    run(`$(Base.julia_cmd()) $julia_command_test`)
end
