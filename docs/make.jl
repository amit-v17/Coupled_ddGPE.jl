using Documenter
using Coupled_ddGPE

makedocs(
    sitename = "Coupled_ddGPE.jl",
    format = Documenter.HTML(),
    modules = [Coupled_ddGPE],
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/amit-v17/Coupled_ddGPE.jl",
    devbranch = "main",
)