push!(LOAD_PATH,"../src/")

using Documenter
using Coupled_ddGPE

makedocs(
    sitename = "Coupled_ddGPE.jl",
    format = Documenter.HTML(),
    modules = [Coupled_ddGPE],
    pages = [
        "Home" => "index.md",
        "Julia Package Reference" => "api.md",
        "REST API Reference" => "api_reference.md",
    ],
)

deploydocs(
    repo = "github.com/amit-v17/Coupled_ddGPE.jl.git",
    devbranch = "main"
)