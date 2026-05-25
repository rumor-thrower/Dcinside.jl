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

# ╔═╡ d32c25d4-960c-475d-8c55-5daa238e2a8c
module Kiwi

using PyCall

# Kiwi 인스턴스 참조 (싱글톤 패턴)
const _instance = Ref{Union{PyObject,Nothing}}(nothing)

"""
    instance() -> PyObject

kiwipiepy.Kiwi 싱글톤 인스턴스 반환 (첫 호출 시 초기화).
"""
function instance()
    if isnothing(_instance[])
        _instance[] = pyimport("kiwipiepy").Kiwi()
    end
    _instance[]
end

"""
    tokenize(text) -> PyObject (list of Token)

형태소 분석 결과 토큰 목록.
각 토큰: `.form` (형태), `.tag` (품사), `.start`, `.len`
"""
tokenize(text::AbstractString) = instance().tokenize(text)

"""
    morphemes(text) -> Dict{String,String}

`form => tag` 사전으로 반환 (`형태소_분석기_팩토리` 동일).
"""
morphemes(text::AbstractString) =
    Dict(string(t.form) => string(t.tag) for t in tokenize(text))

"""
    nouns(text) -> Vector{String}

명사류(NNG · NNP)만 추출해 형태 목록으로 반환.
"""
nouns(text::AbstractString) =
    [string(t.form) for t in tokenize(text) if string(t.tag) in ("NNG", "NNP")]

# 사전별 마지막 로드 시각 (mtime 기반 재로드 방지)
const _dict_mtime = Dict{String,Float64}()

"""
    load_user_dict!(path) -> Int

외부 `.dict` 파일을 Kiwi 인스턴스에 로드한다.
형식: 탭 구분 `단어\t품사` (한 줄에 하나).
파일이 수정되지 않았으면 재로드를 생략한다 (`kiwi_parser.jl` 동일 패턴).
반환: 새로 추가된 단어 수 (생략 시 0).
"""
function load_user_dict!(path::AbstractString)::Int
    ispath(path) || return 0
    mt = mtime(path)
    mt == get(_dict_mtime, path, typemin(Float64)) && return 0
    _dict_mtime[path] = mt
    n = instance().load_user_dictionary(path)
    @info "Kiwi 사용자 사전 로드" path n
    return n
end

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

"""
    parse_titles!(df, parse_fn) -> DataFrame

`title` 열의 각 값에 `parse_fn` 을 적용하여 `:morphemes` 열을 추가한다.
`parse_fn` 은 `String -> Any` 형태 (e.g. `Kiwi.morphemes`, `Kiwi.nouns`).
"""
parse_titles!(df::DataFrame, parse_fn::Function) =
    transform!(df, :title => ByRow(parse_fn) => :morphemes)

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
# ╟─a1f3c2d0-0001-4000-8000-000000000001
# ╠═d8b7dad9-867f-400d-87cc-e184d47f9880
# ╟─a43c857b-3162-49fb-9163-b25e6c93d6d2
# ╟─d32c25d4-960c-475d-8c55-5daa238e2a8c
# ╠═d9be15e6-11d4-4e56-af91-99a60befe7ef
# ╠═c708a4f0-2482-4d84-94f7-cc734cc1a5c0
# ╠═a31efb28-a068-471c-af22-1d670b0b01ce
# ╠═9c9e951d-b26f-4469-a34e-befce57a9338
