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

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
