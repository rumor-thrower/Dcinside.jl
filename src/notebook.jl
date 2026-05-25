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

# ╔═╡ eae23363-86ef-465b-a15b-9be3d352a906
using DataFrames

# ╔═╡ d8b7dad9-867f-400d-87cc-e184d47f9880
include("Dcinside.jl")

# ╔═╡ d9be15e6-11d4-4e56-af91-99a60befe7ef
const api = Dcinside.API()

# ╔═╡ c708a4f0-2482-4d84-94f7-cc734cc1a5c0
const gallery_name = "genrenovel"

# ╔═╡ a31efb28-a068-471c-af22-1d670b0b01ce
let ch = Dcinside.board(api, gallery_name; num=1)
	idx = take!(ch)
	@info fieldnames(Dcinside.DocumentIndex)
	@info idx
end

# ╔═╡ 9c9e951d-b26f-4469-a34e-befce57a9338
let ch = Dcinside.board(api, gallery_name; num=5)
	for idx in ch
		@show idx
	end
end

# ╔═╡ Cell order:
# ╠═a1f3c2d0-0001-4000-8000-000000000001
# ╠═d8b7dad9-867f-400d-87cc-e184d47f9880
# ╠═eae23363-86ef-465b-a15b-9be3d352a906
# ╠═d9be15e6-11d4-4e56-af91-99a60befe7ef
# ╠═c708a4f0-2482-4d84-94f7-cc734cc1a5c0
# ╠═a31efb28-a068-471c-af22-1d670b0b01ce
# ╠═9c9e951d-b26f-4469-a34e-befce57a9338
