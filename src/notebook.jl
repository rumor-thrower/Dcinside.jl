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

# ╔═╡ a43c857b-3162-49fb-9163-b25e6c93d6d2
module DcinsideDataFrames

import ..Dcinside
import DataFrames: DataFrame, transform!, ByRow

# Function 필드(comments, document)를 제외한 열 이름 (타입 기반, 1회 계산)
const _idx_fnames = Tuple(
    f for f in fieldnames(Dcinside.DocumentIndex)
    if fieldtype(Dcinside.DocumentIndex, f) != Function
)

_to_row(idx) = NamedTuple{_idx_fnames}(getfield(idx, f) for f in _idx_fnames)

_fix_types!(df::DataFrame) =
    transform!(df, :id => ByRow(s -> parse(Int, s)) => :id)

"""
    to_dataframe(iter) -> DataFrame

게시판 인덱스 이터러블을 받아 타입 보정된 `DataFrame` 으로 반환한다.
- `id` 열: `String` → `Int`
- `comments` / `document` Function 필드는 제외됨
"""
to_dataframe(iter) = _fix_types!(DataFrame([_to_row(idx) for idx in iter]))

end

# ╔═╡ d9be15e6-11d4-4e56-af91-99a60befe7ef
const api = Dcinside.API()

# ╔═╡ c708a4f0-2482-4d84-94f7-cc734cc1a5c0
const gallery_name = "genrenovel"

# ╔═╡ a31efb28-a068-471c-af22-1d670b0b01ce
let ch = Dcinside.board(api, gallery_name; num=1)
	df = DcinsideDataFrames.to_dataframe(ch)
end

# ╔═╡ 9c9e951d-b26f-4469-a34e-befce57a9338
let ch = Dcinside.board(api, gallery_name; num=5)
	df = DcinsideDataFrames.to_dataframe(ch)
end

# ╔═╡ Cell order:
# ╠═a1f3c2d0-0001-4000-8000-000000000001
# ╠═d8b7dad9-867f-400d-87cc-e184d47f9880
# ╠═a43c857b-3162-49fb-9163-b25e6c93d6d2
# ╠═d9be15e6-11d4-4e56-af91-99a60befe7ef
# ╠═c708a4f0-2482-4d84-94f7-cc734cc1a5c0
# ╠═a31efb28-a068-471c-af22-1d670b0b01ce
# ╠═9c9e951d-b26f-4469-a34e-befce57a9338
