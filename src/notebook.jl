### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

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

# ╔═╡ c03b12c8-ea24-4e68-a89a-a616db2b4798
begin
	using PlutoUI
	using DataFrames
end

# ╔═╡ d8b7dad9-867f-400d-87cc-e184d47f9880
# Dcinside.jl 모듈을 격리된 래퍼 모듈에 include 한 뒤 추출하여 `Dcinside` 변수에 바인딩.
# 이렇게 해야 `Dcinside` 가 Pluto 의존성 추적 대상이 되어, 이 셀이 항상 사용처보다
# 먼저 실행된다. (그냥 `include` 하면 추적 불가; `Dcinside = include(...)` 는 include 가
# 먼저 const Dcinside 를 정의해 "invalid assignment to constant" 에러 발생.)
Dcinside = let
	wrapper = Module(:DcinsideWrapper)
	Core.eval(wrapper, :(include(p) = Base.include($wrapper, p)))
	Core.eval(wrapper, :(include($(joinpath(@__DIR__, "Dcinside.jl")))))
	# Julia 1.12 엄격한 world age: 방금 eval로 정의한 바인딩을 같은 world 에서
	# 직접 읽으면 경고 → invokelatest 로 최신 world 에서 조회.
	Base.invokelatest(getglobal, wrapper, :Dcinside)
end

# ╔═╡ a43c857b-3162-49fb-9163-b25e6c93d6d2
module DcinsideDataFrames

import DataFrames: DataFrame, transform!, ByRow

# Function 필드(comments, document)를 제외한 열 이름 (타입 기반).
# `Dcinside` 모듈은 인자로 전달받는다 — Pluto 워크스페이스 전역을 서브모듈에서
# 직접 참조할 수 없으므로 호출부(to_dataframe)에서 넘겨준다.
_idx_fnames(Dcinside::Module) = Tuple(
    f for f in fieldnames(Dcinside.DocumentIndex)
    if fieldtype(Dcinside.DocumentIndex, f) != Function
)

_to_row(Dcinside::Module, idx) =
    (fns = _idx_fnames(Dcinside); NamedTuple{fns}(getfield(idx, f) for f in fns))

_fix_types!(df::DataFrame) =
    transform!(df, :id => ByRow(s -> parse(Int, s)) => :id)

"""
    to_dataframe(Dcinside, iter) -> DataFrame

게시판 인덱스 이터러블을 받아 타입 보정된 `DataFrame` 으로 반환한다.
- `id` 열: `String` → `Int`
- `comments` / `document` Function 필드는 제외됨
"""
to_dataframe(Dcinside::Module, iter) =
    _fix_types!(DataFrame([_to_row(Dcinside, idx) for idx in iter]))

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

# ╔═╡ 448bc7e4-5fff-4f16-9c28-7070f51083df
@bind time Clock()

# ╔═╡ fa9b0c1e-3d72-4a85-b6e8-2f5c8d1e0a34
let time
	Kiwi.load_user_dict!(joinpath(@__DIR__, "user_dict.dict"))
end

# ╔═╡ 9c9e951d-b26f-4469-a34e-befce57a9338
let ch = Dcinside.board(api, gallery_name; num=5)
	df = DcinsideDataFrames.to_dataframe(Dcinside, ch)
end

# ╔═╡ c1a2b3d4-e5f6-7890-abcd-ef1234567890
# title 열 → Kiwi 형태소 분석 (명사 추출) → id·title·morphemes 열만 출력
let time
	ch = Dcinside.board(api, gallery_name; num=10)
	df = DcinsideDataFrames.to_dataframe(Dcinside, ch)
	DcinsideDataFrames.parse_titles!(df, Kiwi.nouns)
	df[!, [:id, :title, :morphemes]]
end

# ╔═╡ aa000013-1301-4000-8000-000000000013
begin
	using HypertextLiteral

	const DISABILITY_KEYWORDS = ["장애", "불구", "실명", "자폐", "치료", "극복", "클리셰", "영구 장애"]

	const FRAME_VOCAB = Dict(
		:gaming    => ["디버프", "스탯", "패널티", "약점", "너프", "능력치", "상태이상",
		               "핸디캡", "제약", "쇠약", "디메리트", "마이너스"],
		:catharsis => ["성장", "회복", "완치", "기적", "노력", "이겨냈", "딛고",
		               "해냈", "역경", "강해", "각성", "시한부", "피폐"],
		:sympathy  => ["불쌍", "감동", "안타깝", "가엾", "측은", "눈물", "비련",
		               "가슴아프", "힘들", "애처롭", "불행", "고통"],
		:critical  => ["재현", "고정관념", "차별", "편견", "서사", "비판",
		               "문제적", "혐오", "장애인식", "의료화", "감동포르노"],
	)

	const KWIC_WINDOW = 40
	const OUTPUT_DIR  = let d = joinpath(@__DIR__, "..", "output"); mkpath(d); d end
	md"상수 정의 완료 — 키워드 $(length(DISABILITY_KEYWORDS))개, 프레임 $(length(FRAME_VOCAB))종 | 출력: $(OUTPUT_DIR)"
end

# ╔═╡ aa000014-1401-4000-8000-000000000014
module Corpus

using DataFrames

function _update_rows_with_doc(doc, idx, kw, rows)
	(isnothing(doc) || isempty(doc.contents)) && return
	push!(rows, (
		source_id   = idx.id * "_body",
		doc_id      = idx.id,
		keyword     = kw,
		source_type = :post_body,
		text        = doc.contents,
		author      = idx.author,
		timestamp   = idx.time,
		view_count  = idx.view_count,
		voteup      = idx.voteup_count,
	))
end

function _handle_document(fetch_fulltext, idx, kw, rows)
	fetch_fulltext || return
	_update_rows_with_doc(idx.document(), idx, kw, rows)
end

function _handle_comments(fetch_comments, idx, kw, rows)
	fetch_comments || return
	comments = Iterators.filter(c -> c.contents !== nothing, idx.comments())
	for c in comments
		push!(rows, (
			source_id   = c.id,
			doc_id      = idx.id,
			keyword     = kw,
			source_type = :comment,
			text        = c.contents,
			author      = c.author,
			timestamp   = c.time,
			view_count  = 0,
			voteup      = 0,
		))
	end
end

_title_row(idx, kw) = (
	source_id   = idx.id,
	doc_id      = idx.id,
	keyword     = kw,
	source_type = :post_title,
	text        = idx.title,
	author      = idx.author,
	timestamp   = idx.time,
	view_count  = idx.view_count,
	voteup      = idx.voteup_count,
)

"""
	collect_corpus(Dcinside, api, board_id, keywords; posts_per_keyword, fetch_fulltext, fetch_comments)
	-> DataFrame

각 키워드로 `search_board → document → comments` 순 수집.
`Dcinside` 모듈은 인자로 전달받는다 (Pluto 워크스페이스 전역을 서브모듈에서
직접 참조할 수 없으므로 — 호출부에서 넘겨준다).

반환 열: `source_id`, `doc_id`, `keyword`, `source_type` (:post_title/:post_body/:comment),
		 `text`, `author`, `timestamp`, `view_count`, `voteup`
"""
function collect(Dcinside::Module, api, board_id, keywords;
						posts_per_keyword::Int=20,
						fetch_fulltext::Bool=true,
						fetch_comments::Bool=true)
	rows     = NamedTuple[]
	seen_ids = Set{String}()
	for kw in keywords
		for idx in Dcinside.search_board(api, board_id, kw; num=posts_per_keyword)
			push!(rows, _title_row(idx, kw))
			idx.id in seen_ids && continue
			push!(seen_ids, idx.id)
			_handle_document(fetch_fulltext, idx, kw, rows)
			_handle_comments(fetch_comments, idx, kw, rows)
		end
	end
	DataFrame(rows)
end

end

# ╔═╡ aa000015-1501-4000-8000-000000000015
# 키워드 8개 × 20게시글 × (본문+댓글 포함) ≈ 요청 ~500회 × 1.5s ≈ 12~15분
corpus_df = let time
	@info "코퍼스 수집 시작..."
	df = Corpus.collect(Dcinside, api, gallery_name, DISABILITY_KEYWORDS; posts_per_keyword=20)
	@info "수집 완료" nrow=nrow(df)
	df
end

# ╔═╡ aa000016-1601-4000-8000-000000000016
begin
	function classify_frame(text::AbstractString, vocab::Dict)::Symbol
		scores = Dict(f => sum(count(t, text) for t in v) for (f, v) in vocab)
		best   = maximum(values(scores))
		best |> iszero && return :none
		winners = [f for (f, s) in scores if s == best]
		length(winners) == 1 ? only(winners) : :ambiguous
	end

	# 동음이의 용례 제거: 각 (키워드, 패턴) 쌍에 대해 키워드 행 중 패턴 불일치 행을 제거
	filter_keyword_sense!(df, kw_patterns) =
		(foreach(((kw, pat),) -> filter!(r -> r.keyword != kw || occursin(pat, r.text), df), kw_patterns); df)

	corpus_nlp = let
		df = copy(corpus_df)
		# 플랫폼 공식 봇 계정 제거
		filter!(r -> r.author != "댓글돌이", df)
		filter_keyword_sense!(df, [
			("불구", r"불구(?!하)"),   # "불구하고/하여/하다"(역접) 제거 — 장애 의미만 유지
			("실명", r"실명(?!제)"),   # "실명제"(금융 실명제) 제거 — 失明(시력 상실)만 유지
			("자폐", r"(?<!활)자폐"), # "활자폐기물" 등 합성어 제거 — 自閉(자폐증)만 유지
		])
		transform!(df, :text => ByRow(t -> Kiwi.nouns(t))                      => :nouns)
		transform!(df, :text => ByRow(t -> classify_frame(t, FRAME_VOCAB))     => :frame)
		df
	end
end

# ╔═╡ aa000017-1701-4000-8000-000000000017
"""
    kwic(df, keyword; window, n) -> DataFrame

키워드 주변 문맥(KWIC) 추출.
반환 열: `left_context`, `keyword_hit`, `right_context`, `source_type`, `doc_id`, `search_kw`
"""
function kwic(df::DataFrame, keyword::AbstractString;
              window::Int=KWIC_WINDOW, n::Int=30)
	results  = NamedTuple[]
	seen_pos = Set{Tuple{String,Int}}()   # (source_id, byte_offset) — 중복 제거
	for row in eachrow(df)
		text   = row.text
		offset = firstindex(text)
		while true
			r = findnext(keyword, text, offset)
			r === nothing && break
			ks, ke = first(r), last(r)

			# 동일 문서·동일 위치(다른 keyword 행으로 중복 수집된 경우) 스킵
			pos_key = (row.source_id, ks)
			pos_key in seen_pos && (offset = nextind(text, ke); continue)
			push!(seen_pos, pos_key)

			# prevind/nextind으로 문자 경계를 정확히 계산 (멀티바이트 안전)
			# s[i:j] 는 i·j 모두 문자 시작 바이트여야 함
			ls = max(firstindex(text), prevind(text, ks, window))
			left = text[ls:prevind(text, ks)]

			right_start = nextind(text, ke)
			right = if right_start > ncodeunits(text)
				""
			else
				re_raw = nextind(text, ke, window)   # window번째 문자의 시작 바이트
				re     = re_raw <= ncodeunits(text) ? re_raw : lastindex(text)
				text[right_start:re]
			end

			push!(results, (
				left_context  = left,
				keyword_hit   = keyword,
				right_context = right,
				source_type   = row.source_type,
				doc_id        = row.doc_id,
				search_kw     = row.keyword,
			))
			length(results) >= n && @goto kwic_done
			offset = nextind(text, ke)
		end
	end
	@label kwic_done
	DataFrame(results)
end

# ╔═╡ aa000018-1801-4000-8000-000000000018
begin
	"""
	    cooccurrence_matrix(df, dis_kws, frame_vocab) -> DataFrame

	행: 장애 키워드, 열: 프레임명.
	값 = 해당 텍스트에서 장애 키워드와 프레임 어휘가 함께 등장한 행 수.
	"""
	function cooccurrence_matrix(df::DataFrame,
	                              dis_kws::Vector{String},
	                              frame_vocab::Dict)
		frames = sort(collect(keys(frame_vocab)))
		rows = map(dis_kws) do dkw
			sub = filter(r -> occursin(dkw, r.text), eachrow(df))
			counts = Dict(
				f => count(r -> any(occursin(t, r.text) for t in frame_vocab[f]), sub)
				for f in frames
			)
			merge((; keyword=dkw), NamedTuple(sort(collect(counts))))
		end
		DataFrame(rows)
	end

	cooc_df = cooccurrence_matrix(corpus_nlp, DISABILITY_KEYWORDS, FRAME_VOCAB)
end

# ╔═╡ aa000019-1901-4000-8000-000000000019
# 키워드 빈도 막대 차트
let
	freq  = sort(combine(groupby(corpus_nlp, :keyword), nrow => :n), :n; rev=true)
	labels = freq.keyword
	vals   = freq.n
	max_v  = max(maximum(vals), 1)
	W, H   = 620, 280
	bar_w  = (W - 80) ÷ length(labels)

	rects = join(["""<g>
	  <rect x="$(60+(i-1)*bar_w)" y="$(H-50-round(Int,v/max_v*180))"
	        width="$(bar_w-4)" height="$(round(Int,v/max_v*180))" fill="#4e79a7" rx="2"/>
	  <text x="$(60+(i-1)*bar_w+bar_w÷2)" y="$(H-32)"
	        text-anchor="middle" font-size="12">$(labels[i])</text>
	  <text x="$(60+(i-1)*bar_w+bar_w÷2)" y="$(H-54-round(Int,v/max_v*180))"
	        text-anchor="middle" font-size="11" fill="#333">$(v)</text>
	</g>""" for (i,v) in enumerate(vals)], "\n")

	svg = """<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" style="font-family:sans-serif;overflow:visible">$rects</svg>"""
	write(joinpath(OUTPUT_DIR, "01_keyword_freq.svg"), svg)
	HTML("""<div><h4 style="font-family:sans-serif;margin:8px 0">키워드별 수집 행 수 (제목·본문·댓글 합산)</h4>$svg</div>""")
end

# ╔═╡ aa000020-2001-4000-8000-000000000020
# 프레임 분포 막대 차트
let
	frame_order = [:gaming, :catharsis, :sympathy, :critical, :ambiguous, :none]
	frame_color = Dict(
		:gaming    => "#e15759",
		:catharsis => "#f28e2b",
		:sympathy  => "#59a14f",
		:critical  => "#4e79a7",
		:ambiguous => "#bab0ac",
		:none      => "#d3d3d3",
	)
	counts    = combine(groupby(corpus_nlp, :frame), nrow => :n)
	count_map = Dict(r.frame => r.n for r in eachrow(counts))
	present   = [(string(f), get(count_map, f, 0), frame_color[f])
	             for f in frame_order if get(count_map, f, 0) > 0]

	if isempty(present)
		HTML("<p style='font-family:sans-serif'>데이터 없음</p>")
	else
		max_v = max(maximum(x[2] for x in present), 1)
		W, H  = 560, 280
		bar_w = (W - 80) ÷ length(present)

		rects = join(["""<g>
		  <rect x="$(60+(i-1)*bar_w)" y="$(H-50-round(Int,v/max_v*180))"
		        width="$(bar_w-6)" height="$(round(Int,v/max_v*180))" fill="$c" rx="2"/>
		  <text x="$(60+(i-1)*bar_w+(bar_w-6)÷2)" y="$(H-32)"
		        text-anchor="middle" font-size="12">$l</text>
		  <text x="$(60+(i-1)*bar_w+(bar_w-6)÷2)" y="$(H-54-round(Int,v/max_v*180))"
		        text-anchor="middle" font-size="11" fill="#333">$v</text>
		</g>""" for (i,(l,v,c)) in enumerate(present)], "\n")

		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" style="font-family:sans-serif;overflow:visible">$rects</svg>"""
		write(joinpath(OUTPUT_DIR, "02_frame_dist.svg"), svg)
		HTML("""<div><h4 style="font-family:sans-serif;margin:8px 0">프레임 분포</h4>$svg</div>""")
	end
end

# ╔═╡ aa000021-2101-4000-8000-000000000021
# 공기어 히트맵 — 값이 클수록 배경색 진하게
let
	frames  = [:gaming, :catharsis, :sympathy, :critical]
	max_val = max(maximum(maximum(cooc_df[!, f]) for f in frames), 1)

	cell_bg(v) = let
		i = round(Int, (1 - v/max_val) * 220)
		c = string(i, base=16, pad=2)
		"background:#$(c)$(c)ff;padding:6px 12px;text-align:center;font-size:13px"
	end

	header = join(["<th style='padding:6px 12px;background:#f0f0f0'>$f</th>" for f in frames])
	rows   = join(["<tr><td style='padding:6px 10px;font-weight:bold;background:#f8f8f8'>$(row.keyword)</td>" *
	               join(["<td style='$(cell_bg(row[f]))'>$(row[f])</td>" for f in frames]) *
	               "</tr>" for row in eachrow(cooc_df)])
	table  = """<table style="border-collapse:collapse;font-family:sans-serif">
	  <thead><tr><th style="padding:6px 10px;background:#f0f0f0">키워드</th>$header</tr></thead>
	  <tbody>$rows</tbody></table>"""

	write(joinpath(OUTPUT_DIR, "03_cooc_heatmap.html"), """<!DOCTYPE html>
	<html><head><meta charset="utf-8"></head><body>
	<h3 style="font-family:sans-serif">장애 키워드 × 프레임 공기어 히트맵</h3>
	<p style="font-size:12px;color:#666;font-family:sans-serif">진할수록 공기어 빈도 높음</p>
	$table</body></html>""")

	HTML("""<div>
		<h4 style="font-family:sans-serif;margin:8px 0">장애 키워드 × 프레임 공기어 히트맵</h4>
		<p style="font-size:12px;color:#666;font-family:sans-serif">진할수록 공기어 빈도 높음</p>
		$table
	</div>""")
end

# ╔═╡ aa000022-2201-4000-8000-000000000022
# 비판 프레임 부재 강조
let
	critical_n    = count(r -> r.frame == :critical, eachrow(corpus_nlp))
	noncritical_n = count(r -> r.frame in (:gaming, :catharsis, :sympathy), eachrow(corpus_nlp))
	labels = ["비판적 담론", "비비판적 담론 합계"]
	vals   = [critical_n, noncritical_n]
	colors = ["#4e79a7", "#e15759"]
	max_v  = max(maximum(vals), 1)
	W, H   = 360, 260
	bar_w  = (W - 80) ÷ 2

	rects = join(["""<g>
	  <rect x="$(60+(i-1)*(bar_w+10))" y="$(H-50-round(Int,v/max_v*160))"
	        width="$bar_w" height="$(round(Int,v/max_v*160))" fill="$(colors[i])" rx="2"/>
	  <text x="$(60+(i-1)*(bar_w+10)+bar_w÷2)" y="$(H-30)"
	        text-anchor="middle" font-size="12">$(labels[i])</text>
	  <text x="$(60+(i-1)*(bar_w+10)+bar_w÷2)" y="$(H-54-round(Int,v/max_v*160))"
	        text-anchor="middle" font-size="13" font-weight="bold">$v</text>
	</g>""" for (i,v) in enumerate(vals)], "\n")

	svg = """<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" style="font-family:sans-serif;overflow:visible">$rects</svg>"""
	write(joinpath(OUTPUT_DIR, "04_critical_absence.svg"), svg)
	HTML("""<div><h4 style="font-family:sans-serif;margin:8px 0">비판적 담론 부재 시각화</h4>$svg</div>""")
end

# ╔═╡ aa000023-2301-4000-8000-000000000023
@bind kwic_keyword Select(DISABILITY_KEYWORDS)

# ╔═╡ aa000024-2401-4000-8000-000000000024
# 키워드별 고빈도 공기 명사 Top-10
@bind topn_keyword Select(DISABILITY_KEYWORDS)

# ╔═╡ 2496d0f4-5b45-11f1-9781-0f03f23dfb35
let
	rows_df = kwic(corpus_nlp, kwic_keyword; n=30)
	nrow(rows_df) |> iszero && return md"검색 결과 없음"

	data_rows = [@htl("""<tr style="border-bottom:1px solid #eee">
		<td style="text-align:right;padding:4px 8px;color:#555;font-size:13px">$(r.left_context)</td>
		<td style="font-weight:bold;color:#c0392b;padding:4px 4px;white-space:nowrap;font-size:13px">$(r.keyword_hit)</td>
		<td style="padding:4px 8px;color:#555;font-size:13px">$(r.right_context)</td>
		<td style="padding:4px 8px;font-size:11px;color:#888">$(r.source_type)</td>
	</tr>""") for r in eachrow(rows_df)]

	@htl("""<div>
		<h4 style="font-family:sans-serif;margin:8px 0">KWIC — <span style="color:#c0392b">$(kwic_keyword)</span></h4>
		<table style="border-collapse:collapse;font-family:sans-serif;max-width:900px">
		  <thead><tr style="background:#f5f5f5">
		    <th style="padding:4px 8px;text-align:right;font-size:12px">좌측 문맥</th>
		    <th style="padding:4px 4px;font-size:12px">키워드</th>
		    <th style="padding:4px 8px;font-size:12px">우측 문맥</th>
		    <th style="padding:4px 8px;font-size:12px">유형</th>
		  </tr></thead>
		  <tbody>$(data_rows)</tbody>
		</table>
	</div>""")
end

# ╔═╡ 2496d5fe-5b45-11f1-8cad-db3dae0703dd
let
	sub    = filter(r -> occursin(topn_keyword, r.text), eachrow(corpus_nlp))
	all_n  = [n for r in sub for n in r.nouns]
	counts = sort(collect(Dict(n => count(==(n), all_n) for n in unique(all_n))),
	              by=x -> -x[2])
	top10  = first(counts, 10)
	isempty(top10) && return md"명사 없음"

	rows_html = [@htl("""<tr style="border-bottom:1px solid #eee">
		<td style="padding:4px 16px;font-size:14px">$i</td>
		<td style="padding:4px 16px;font-size:14px;font-weight:bold">$(p[1])</td>
		<td style="padding:4px 16px;font-size:14px">$(p[2])</td>
	</tr>""") for (i, p) in enumerate(top10)]

	@htl("""<div>
		<h4 style="font-family:sans-serif;margin:8px 0">
		  「$(topn_keyword)」 주변 고빈도 명사 Top-$(length(top10))
		</h4>
		<table style="border-collapse:collapse;font-family:sans-serif">
		  <thead><tr style="background:#f5f5f5">
		    <th style="padding:4px 16px;font-size:12px">순위</th>
		    <th style="padding:4px 16px;font-size:12px">명사</th>
		    <th style="padding:4px 16px;font-size:12px">빈도</th>
		  </tr></thead>
		  <tbody>$(rows_html)</tbody>
		</table>
	</div>""")
end

# ╔═╡ Cell order:
# ╟─a1f3c2d0-0001-4000-8000-000000000001
# ╟─d8b7dad9-867f-400d-87cc-e184d47f9880
# ╟─a43c857b-3162-49fb-9163-b25e6c93d6d2
# ╟─d32c25d4-960c-475d-8c55-5daa238e2a8c
# ╟─d9be15e6-11d4-4e56-af91-99a60befe7ef
# ╟─c708a4f0-2482-4d84-94f7-cc734cc1a5c0
# ╠═c03b12c8-ea24-4e68-a89a-a616db2b4798
# ╟─448bc7e4-5fff-4f16-9c28-7070f51083df
# ╟─fa9b0c1e-3d72-4a85-b6e8-2f5c8d1e0a34
# ╟─9c9e951d-b26f-4469-a34e-befce57a9338
# ╟─c1a2b3d4-e5f6-7890-abcd-ef1234567890
# ╟─aa000013-1301-4000-8000-000000000013
# ╠═aa000014-1401-4000-8000-000000000014
# ╟─aa000015-1501-4000-8000-000000000015
# ╟─aa000016-1601-4000-8000-000000000016
# ╟─aa000017-1701-4000-8000-000000000017
# ╟─aa000018-1801-4000-8000-000000000018
# ╟─aa000019-1901-4000-8000-000000000019
# ╟─aa000020-2001-4000-8000-000000000020
# ╟─aa000021-2101-4000-8000-000000000021
# ╟─aa000022-2201-4000-8000-000000000022
# ╠═aa000023-2301-4000-8000-000000000023
# ╠═aa000024-2401-4000-8000-000000000024
# ╟─2496d0f4-5b45-11f1-9781-0f03f23dfb35
# ╟─2496d5fe-5b45-11f1-8cad-db3dae0703dd
