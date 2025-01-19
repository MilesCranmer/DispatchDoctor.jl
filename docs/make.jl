using DispatchDoctor
using Documenter

DocMeta.setdocmeta!(DispatchDoctor, :DocTestSetup, :(using DispatchDoctor); recursive=true)

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# We replace every instance of <img src="IMAGE" ...> with ![](IMAGE).
readme = replace(readme, r"<img src=\"([^\"]+)\"[^>]+>.*" => s"![](\1)")

# Then, we remove any line with "<div" on it:
readme = replace(readme, r"<[/]?div.*" => s"")

# Finally, we read in file docs/src/index_base.md:
index_base = open(dirname(@__FILE__) * "/src/index_base.md") do io
    read(io, String)
end

# And then we create "/src/index.md":
open(dirname(@__FILE__) * "/src/index.md", "w") do io
    write(io, readme)
    write(io, "\n")
    write(io, index_base)
end

makedocs(;
    modules=[DispatchDoctor],
    authors="MilesCranmer <miles.cranmer@gmail.com> and contributors",
    repo="https://github.com/MilesCranmer/DispatchDoctor.jl/blob/{commit}{path}#{line}",
    sitename="DispatchDoctor.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ai.damtp.cam.ac.uk/dispatchdoctor",
        edit_link="main",
        assets=String[],
    ),
    pages=["Home" => "index.md", "Reference" => "reference.md"],
    warnonly=[:missing_docs],
)

deploydocs(; repo="github.com/MilesCranmer/DispatchDoctor.jl", devbranch="main")

# Mirror to DAMTP:
ENV["DOCUMENTER_KEY"] = ENV["DOCUMENTER_KEY_CAM"]
ENV["GITHUB_REPOSITORY"] = "ai-damtp-cam-ac-uk/dispatchdoctor.git"
deploydocs(;
    repo="github.com/ai-damtp-cam-ac-uk/dispatchdoctor.git",
    devbranch="main"
)
