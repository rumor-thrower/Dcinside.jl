### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# ╔═╡ a1f3c2d0-0001-4000-8000-000000000001
begin
    import Pkg
    Pkg.activate(@__DIR__)  # src/Project.toml — 노트북 전용 환경
    Pkg.instantiate()
end

# ╔═╡ d8b7dad9-867f-400d-87cc-e184d47f9880
include("Dcinside.jl")

# ╔═╡ eae23363-86ef-465b-a15b-9be3d352a906
using DataFrames

# ╔═╡ c708a4f0-2482-4d84-94f7-cc734cc1a5c0
const gallery_name = "genrenovel"

# ╔═╡ 9c9e951d-b26f-4469-a34e-befce57a9338


# ╔═╡ Cell order:
# ╠═a1f3c2d0-0001-4000-8000-000000000001
# ╠═d8b7dad9-867f-400d-87cc-e184d47f9880
# ╠═eae23363-86ef-465b-a15b-9be3d352a906
# ╠═c708a4f0-2482-4d84-94f7-cc734cc1a5c0
# ╠═9c9e951d-b26f-4469-a34e-befce57a9338
