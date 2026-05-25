module Dcinside

using HTTP
using Lexbor
using AbstractTrees
using JSON
using Dates

export API
export gallery, board, document, comments
export write_comment, write_document, modify_document, remove_document
export DocumentIndex, Document, Comment, Image

# ============================================================
# Constants
# ============================================================

const DOCS_PER_PAGE = 200

const GET_HEADERS = [
    "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
]

const XML_HTTP_REQ_HEADERS = [
    "Accept"           => "*/*",
    "Connection"       => "keep-alive",
    "User-Agent"       => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "X-Requested-With" => "XMLHttpRequest",
    "Accept-Encoding"  => "gzip, deflate, br",
    "Accept-Language"  => "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
    "Content-Type"     => "application/x-www-form-urlencoded; charset=UTF-8",
]

const POST_HEADERS = [
    "Accept"                    => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Encoding"           => "gzip, deflate, br",
    "Accept-Language"           => "ko-KR,ko;q=0.9",
    "Cache-Control"             => "no-cache",
    "Connection"                => "keep-alive",
    "Pragma"                    => "no-cache",
    "Upgrade-Insecure-Requests" => "1",
    "User-Agent"                => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
]

const BASE_COOKIES = Dict{String,String}(
    "_ga" => "GA1.2.693521455.1588839880",
)

# ============================================================
# URL encoding helpers  (Python의 quote / unquote 대응)
# ============================================================

"""
    url_unquote(s) -> String

`\\uXXXX` / `\\uXX` 이스케이프를 실제 유니코드 문자로 변환.
"""
function url_unquote(s::AbstractString)
    replace(s, r"\\u([a-fA-F0-9]{4}|[a-fA-F0-9]{2})" =>
        m -> string(Char(parse(Int, m.captures[1]; base=16))))
end

"""
    url_quote(s) -> String

각 문자를 `%XX` 또는 `%uXXXX` 형식으로 퍼센트-인코딩 (Python `quote()` 동일).
"""
function url_quote(s::AbstractString)
    buf = IOBuffer()
    for c in s
        cp = codepoint(c)
        t  = uppercase(string(cp; base=16))
        if length(t) >= 4
            print(buf, "%u", t)
        else
            print(buf, "%", t)
        end
    end
    String(take!(buf))
end

# ============================================================
# Data structures
# ============================================================

"""디씨인사이드 댓글."""
struct Comment
    id        ::String
    is_reply  ::Bool
    author    ::String
    author_id ::Union{String,Nothing}
    contents  ::Union{String,Nothing}
    dccon     ::Union{String,Nothing}
    voice     ::Union{String,Nothing}
    time      ::DateTime
end

function Base.show(io::IO, c::Comment)
    prefix = c.is_reply ? "ㄴㄴ" : "ㄴ"
    print(io, "$prefix $(c.author): $(something(c.contents,""))$(something(c.dccon,""))$(something(c.voice,"")) | $(c.time)")
end

"""게시글 첨부 이미지."""
struct Image
    src         ::String
    document_id ::String
    board_id    ::String
end

"""게시글 본문."""
struct Document
    id                  ::String
    board_id            ::String
    title               ::String
    author              ::String
    author_id           ::Union{String,Nothing}
    contents            ::String
    images              ::Vector{Image}
    html                ::String
    view_count          ::Int
    voteup_count        ::Int
    votedown_count      ::Int
    logined_voteup_count::Int
    time                ::DateTime
    subject             ::Union{String,Nothing}
    comments            ::Function   # () -> Channel{Comment}
end

function Base.show(io::IO, d::Document)
    print(io, "$(something(d.subject,""))\t|$(d.id)\t|$(d.time)\t|$(d.author)\t|$(d.title)" *
              " +$(d.voteup_count) -$(d.votedown_count)\n$(d.contents)")
end

"""게시판 목록의 글 헤더."""
struct DocumentIndex
    id             ::String
    board_id       ::String
    title          ::String
    has_image      ::Bool
    image_available::Bool
    author         ::String
    time           ::DateTime
    view_count     ::Int
    comment_count  ::Int
    voteup_count   ::Int
    subject        ::Union{String,Nothing}
    document       ::Function   # () -> Union{Document,Nothing}
    comments       ::Function   # () -> Channel{Comment}
end

function Base.show(io::IO, d::DocumentIndex)
    print(io, "$(something(d.subject,""))\t|$(d.id)\t|$(d.time)\t|$(d.author)\t|$(d.title)" *
              "($(d.comment_count)) +$(d.voteup_count)")
end

# ============================================================
# API handle
# ============================================================

"""
    API()

디씨인사이드 API 핸들. HTTP.jl 이 연결 풀을 관리한다.
"""
struct API end

# ============================================================
# Internal: HTTP helpers
# ============================================================

function _get(url::AbstractString;
              headers = GET_HEADERS,
              cookies::Dict{String,String} = BASE_COOKIES,
              redirect::Bool = true)::String
    resp = HTTP.get(url; headers, cookies, redirect)
    String(resp.body)
end

# 최종 리다이렉트 URL 도 함께 반환
function _get_with_url(url::AbstractString;
                       headers = GET_HEADERS,
                       cookies::Dict{String,String} = BASE_COOKIES)::Tuple{String,String}
    resp = HTTP.get(url; headers, cookies, redirect=true)
    body    = String(resp.body)
    final_url = string(resp.request.url)
    (body, final_url)
end

function _post(url::AbstractString,
               payload;                          # Pairs 또는 Dict
               headers = XML_HTTP_REQ_HEADERS,
               cookies::Dict{String,String} = BASE_COOKIES)::String
    pairs = payload isa Dict ? collect(payload) : payload
    body  = HTTP.URIs.escapeuri(pairs)
    resp  = HTTP.post(url; headers, cookies, body)
    String(resp.body)
end

# ============================================================
# Internal: Lexbor helpers
# ============================================================

_parse_html(html::AbstractString) = Lexbor.Document(html)

_query(doc_or_node, sel) = Lexbor.query(doc_or_node, sel)

function _query1(doc_or_node, sel)
    nodes = _query(doc_or_node, sel)
    isempty(nodes) ? nothing : first(nodes)
end

function _attr(node::Lexbor.Node, name::AbstractString)
    attrs = Lexbor.attributes(node)
    isnothing(attrs) ? nothing : get(attrs, name, nothing)
end

"""全 텍스트 노드를 sep 으로 이어 붙임 (lxml `itertext()` 대응)."""
function _innertext(node::Lexbor.Node; sep::AbstractString="\n")::String
    parts = String[]
    for n in PreOrderDFS(node)
        Lexbor.is_text(n) || continue
        t = Lexbor.text(n)
        isnothing(t) && continue
        ts = strip(t)
        isempty(ts) || push!(parts, ts)
    end
    join(parts, sep)
end

# ============================================================
# Internal: gallery type detection
# ============================================================

# board_id → "mgallery" | "board" (캐시)
const _gtype_cache = Dict{String,String}()

"""
`board_id` 가 마이너 갤러리면 `"mgallery"`, 일반 갤러리면 `"board"` 반환.
결과는 세션 내에서 캐싱된다.
"""
function _gallery_type(board_id::AbstractString)::String
    get!(_gtype_cache, string(board_id)) do
        # m.dcinside.com 리다이렉트를 따라가면 gtype 을 알 수 있음
        resp = HTTP.get("https://m.dcinside.com/board/$board_id";
                        headers=GET_HEADERS, cookies=BASE_COOKIES, redirect=true)
        url = string(resp.request.url)
        occursin("mgallery", url) ? "mgallery" : "board"
    end
end

"""게시판 목록 URL 생성.
- major : `gall.dcinside.com/board/lists/?id=...`
- minor : `gall.dcinside.com/mgallery/board/lists/?id=...`
"""
function _list_url(board_id, page; recommend=false)
    gtype = _gallery_type(board_id)   # "mgallery" | "board"
    q     = recommend ? "&recommend=1" : ""
    if gtype == "mgallery"
        "https://gall.dcinside.com/mgallery/board/lists/?id=$board_id&page=$page$q"
    else
        "https://gall.dcinside.com/board/lists/?id=$board_id&page=$page$q"
    end
end

"""글 본문 URL 생성."""
function _view_url(board_id, document_id)
    gtype = _gallery_type(board_id)
    if gtype == "mgallery"
        "https://gall.dcinside.com/mgallery/board/view/?id=$board_id&no=$document_id"
    else
        "https://gall.dcinside.com/board/view/?id=$board_id&no=$document_id"
    end
end

# ============================================================
# Internal: time parsing  (Python __parse_time 대응)
# ============================================================

function _parse_time(raw::AbstractString)::DateTime
    t = strip(raw)
    n = length(t)
    today = now()

    if n <= 5
        if contains(t, ":")
            h, m = parse.(Int, split(t, ":"))
            return DateTime(year(today), month(today), day(today), h, m)
        else
            mo, d = parse.(Int, split(t, "."))
            return DateTime(year(today), mo, d, 23, 59, 59)
        end
    elseif n <= 11
        if contains(t, ":")
            # "MM.DD HH:MM"
            parts = split(t)
            mo, d = parse.(Int, split(parts[1], "."))
            h, m  = parse.(Int, split(parts[2], ":"))
            return DateTime(year(today), mo, d, h, m)
        else
            # "YY.MM.DD"
            yy, mo, d = parse.(Int, split(t, "."))
            return DateTime(2000 + yy, mo, d, 23, 59, 59)
        end
    elseif n <= 16
        if count(==('.'), t) >= 2
            return DateTime(t, dateformat"yyyy.mm.dd HH:MM")
        else
            # "MM.DD HH:MM:SS"
            parts = split(t)
            mo, d    = parse.(Int, split(parts[1], "."))
            h, m, s  = parse.(Int, split(parts[2], ":"))
            return DateTime(year(today), mo, d, h, m, s)
        end
    else
        if contains(t, ".")
            return DateTime(t, dateformat"yyyy.mm.dd HH:MM:SS")
        else
            return DateTime(t, dateformat"yyyy-mm-dd HH:MM:SS")
        end
    end
end

# ============================================================
# Internal: CSRF / con_key (Python __access 대응)
# ============================================================

function _access(token_verify::AbstractString, target_url::AbstractString;
                 require_conkey::Bool=true,
                 csrf_token::Union{AbstractString,Nothing}=nothing)::String
    payload = [("token_verify", token_verify)]
    if require_conkey
        html    = _get(target_url)
        doc     = _parse_html(html)
        ck_node = _query1(doc, "#con_key")
        ck_node !== nothing && push!(payload, ("con_key", something(_attr(ck_node, "value"), "")))
    end
    hdrs = copy(XML_HTTP_REQ_HEADERS)
    push!(hdrs, "Referer" => target_url)
    csrf_token !== nothing && push!(hdrs, "X-CSRF-TOKEN" => csrf_token)
    resp = _post("https://m.dcinside.com/ajax/access", payload; headers=hdrs)
    JSON.parse(resp)["Block_key"]
end

# ============================================================
# Public API
# ============================================================

"""
    gallery(api; name=nothing) -> Dict{String,String}

전체 갤러리 목록. `name` 지정 시 그 문자열을 포함한 갤러리만 반환.

# 예시
```julia
api = API()
gallery(api; name="프로그래밍")
```
"""
function gallery(::API; name::Union{AbstractString,Nothing}=nothing)::Dict{String,String}
    html   = _get("https://m.dcinside.com/galltotal")
    doc    = _parse_html(html)
    result = Dict{String,String}()
    for a in _query(doc, "#total_1 a")
        board_name = _innertext(a; sep=" ")
        href       = something(_attr(a, "href"), "")
        board_id   = split(href, "/")[end]
        if name === nothing || contains(board_name, name)
            result[board_name] = board_id
        end
    end
    result
end

"""
    board(api, board_id; num=-1, start_page=1, recommend=false,
          document_id_upper_limit=nothing, document_id_lower_limit=nothing)
    -> Channel{DocumentIndex}

게시판 글 목록을 `Channel` (lazy) 로 반환.

- `num=-1` : 무제한
- `recommend=true` : 개념글 목록
- `document_id_upper_limit` : 이 번호 **이상**의 글 건너뜀
- `document_id_lower_limit` : 이 번호 **이하** 도달 시 중단

# 예시
```julia
api = API()
for idx in board(api, "programming"; num=10)
    println(idx)
end
```
"""
function board(api::API, board_id::AbstractString;
               num::Int=-1,
               start_page::Int=1,
               recommend::Bool=false,
               document_id_upper_limit::Union{Int,Nothing}=nothing,
               document_id_lower_limit::Union{Int,Nothing}=nothing)::Channel{DocumentIndex}

    Channel{DocumentIndex}(32) do ch
        page      = start_page
        remaining = num

        while remaining != 0
            url   = _list_url(board_id, page; recommend)
            html  = _get(url)
            doc   = _parse_html(html)

            # PC 갤러리: tbody.listwrap2 > tr.ub-content[data-no]
            # us-post 클래스가 있는 일반 글만 수집
            rows = filter(_query(doc, "tbody.listwrap2 > tr.ub-content")) do tr
                no  = _attr(tr, "data-no")
                cls = something(_attr(tr, "class"), "")
                no !== nothing && occursin("us-post", cls)
            end

            isempty(rows) && break
            found_any = false

            for tr in rows
                document_id = something(_attr(tr, "data-no"), "")
                isempty(document_id) && continue

                doc_id_int = tryparse(Int, document_id)
                if document_id_upper_limit !== nothing && doc_id_int !== nothing
                    doc_id_int >= document_id_upper_limit && continue
                end
                if document_id_lower_limit !== nothing && doc_id_int !== nothing
                    doc_id_int <= document_id_lower_limit && return
                end

                # 말머리
                subj_n  = _query1(tr, "td.gall_subject > b")
                subject = subj_n === nothing ? nothing : begin
                    t = _innertext(subj_n; sep=" ")
                    isempty(t) ? nothing : t
                end

                # 제목: <b> 가 있으면 그 텍스트, 없으면 링크 <a> 전체 텍스트
                # (일부 일반 글은 <b> 없이 <a> 안 텍스트 노드로 직접 존재)
                title_b  = _query1(tr, "td.gall_tit b")
                title_a  = _query1(tr, "td.gall_tit a:not(.reply_numbox)")
                title    = if title_b !== nothing
                    _innertext(title_b; sep=" ")
                elseif title_a !== nothing
                    parts = String[]
                    for n in PreOrderDFS(title_a)
                        Lexbor.is_text(n) || continue
                        t = Lexbor.text(n)
                        isnothing(t) && continue
                        ts = strip(t)
                        isempty(ts) || push!(parts, ts)
                    end
                    join(parts, " ")
                else
                    ""
                end

                # 이미지 아이콘
                has_image       = !isempty(_query(tr, "td.gall_tit em.icon_img"))
                image_available = has_image

                # 작성자: data-nick + data-uid/data-ip
                writer_td = _query1(tr, "td.gall_writer")
                author = ""
                if writer_td !== nothing
                    nick = something(_attr(writer_td, "data-nick"), "")
                    ip   = something(_attr(writer_td, "data-ip"),   "")
                    author = isempty(ip) ? nick : "$nick($ip)"
                end

                # 날짜: td.gall_date[title] 에 전체 날짜 있음
                date_td  = _query1(tr, "td.gall_date")
                time_str = date_td === nothing ? "00:00" : begin
                    full = something(_attr(date_td, "title"), "")
                    isempty(full) ? _innertext(date_td; sep=" ") : full
                end
                post_time = try _parse_time(time_str) catch; now() end

                # 조회수
                view_td    = _query1(tr, "td.gall_count")
                view_count = view_td === nothing ? 0 :
                    something(tryparse(Int, strip(_innertext(view_td; sep=" "))), 0)

                # 추천수
                recom_td     = _query1(tr, "td.gall_recommend")
                voteup_count = recom_td === nothing ? 0 :
                    something(tryparse(Int, strip(_innertext(recom_td; sep=" "))), 0)

                # 댓글수: span.reply_num 텍스트 "[N]" 또는 "[N/M]"
                reply_n       = _query1(tr, "span.reply_num")
                comment_count = 0
                if reply_n !== nothing
                    digits = filter(isdigit, _innertext(reply_n; sep=" "))
                    !isempty(digits) && (comment_count = something(tryparse(Int, digits), 0))
                end

                idx = DocumentIndex(
                    document_id, board_id, title, has_image, image_available,
                    author, post_time, view_count, comment_count, voteup_count, subject,
                    () -> document(api, board_id, document_id),
                    () -> comments(api, board_id, document_id),
                )
                put!(ch, idx)
                found_any  = true
                remaining -= 1
                remaining == 0 && return
            end

            found_any || break
            page += 1
        end
    end
end

"""
    document(api, board_id, document_id) -> Union{Document, Nothing}

게시글 상세 내용 반환. 파싱 실패 시 `nothing`.
"""
function document(api::API, board_id::AbstractString, document_id::AbstractString)::Union{Document,Nothing}
    url  = _view_url(board_id, document_id)
    html = _get(url)
    doc  = _parse_html(html)

    # PC 갤러리: div.gallview_head.ub-content
    head = _query1(doc, "div.gallview_head")
    head === nothing && return nothing

    # 본문 div
    body_node = _query1(doc, "div.writing_view_box")
    body_node === nothing && return nothing

    # 제목
    title_n = _query1(head, "h3.title span.title_subject")
    title   = title_n === nothing ? "" : _innertext(title_n; sep=" ")

    # 작성자
    writer_n  = _query1(head, "div.gall_writer")
    author    = ""
    author_id = nothing
    if writer_n !== nothing
        nick  = something(_attr(writer_n, "data-nick"), "")
        uid   = something(_attr(writer_n, "data-uid"),  "")
        ip    = something(_attr(writer_n, "data-ip"),   "")
        author    = isempty(ip) ? nick : "$nick($ip)"
        author_id = isempty(uid) ? nothing : uid
    end

    # 시각: span.gall_date[title]
    date_n   = _query1(head, "span.gall_date")
    time_str = date_n === nothing ? "00:00" : begin
        full = something(_attr(date_n, "title"), "")
        isempty(full) ? strip(_innertext(date_n; sep=" ")) : full
    end
    post_time = try _parse_time(time_str) catch; now() end

    # 본문: body_node 를 직접 순회 (Lexbor.Node(node) 생성자는 Document 전용)
    contents = strip(_innertext(body_node; sep=" "))

    # 이미지
    images = Image[]
    for img in _query(doc, "div.writing_view_box img")
        src_orig = _attr(img, "data-original")
        src_fall = _attr(img, "src")
        src      = something(src_orig, src_fall)
        src === nothing && continue
        if src_orig === nothing
            startswith(src, "https://nstatic")             && continue
            startswith(src, "https://img.iacstatic.co.kr") && continue
        end
        push!(images, Image(src, document_id, board_id))
    end

    # 조회수: span.gall_count "조회 N"
    view_n     = _query1(head, "span.gall_count")
    view_count = 0
    if view_n !== nothing
        vs = split(_innertext(view_n; sep=" "))
        !isempty(vs) && (view_count = something(tryparse(Int, vs[end]), 0))
    end

    # 추천수: span.gall_reply_num "추천 N"
    vote_n   = _query1(head, "span.gall_reply_num")
    voteup   = 0
    if vote_n !== nothing
        vs = split(_innertext(vote_n; sep=" "))
        !isempty(vs) && (voteup = something(tryparse(Int, vs[end]), 0))
    end

    # votedown / logined_voteup: PC 갤러리에서는 별도 엔드포인트 (0 으로 초기화)
    votedown = 0
    logined  = 0
    html_str = _innertext(body_node)

    Document(
        document_id, board_id, title, author, author_id,
        contents, images, html_str,
        view_count, voteup, votedown, logined,
        post_time, nothing,
        () -> comments(api, board_id, document_id),
    )
end

"""
    comments(api, board_id, document_id; num=-1, start_page=1)
    -> Channel{Comment}

댓글 목록을 `Channel` (lazy) 로 반환.

PC 갤러리의 JSON 댓글 API 를 사용한다.
내부적으로 글 본문 페이지에서 `e_s_n_o` 와 `_GALLTYPE_` 를 취득한다.
"""
function comments(api::API, board_id::AbstractString, document_id::AbstractString;
                  num::Int=-1, start_page::Int=1)::Channel{Comment}

    Channel{Comment}(32) do ch
        # 글 본문에서 댓글 API 필수 파라미터 취득
        view_html = _get(_view_url(board_id, document_id))
        view_doc  = _parse_html(view_html)

        esnon  = _query1(view_doc, "#e_s_n_o")
        gtype_ = _query1(view_doc, "#GALLTYPE_")
        e_s_n_o   = esnon  !== nothing ? something(_attr(esnon,  "value"), "") : ""
        galltype  = gtype_ !== nothing ? something(_attr(gtype_, "value"), "G") : "G"

        url       = "https://gall.dcinside.com/board/comment/"
        remaining = num

        for page in start_page:999_999
            payload = [
                "id"           => board_id,
                "no"           => document_id,
                "cmt_id"       => board_id,
                "cmt_no"       => document_id,
                "e_s_n_o"      => e_s_n_o,
                "comment_page" => string(page),
                "sort"         => "D",
                "_GALLTYPE_"   => galltype,
            ]
            resp_str = _post(url, payload)
            data     = try JSON.parse(resp_str)
                       catch; break end

            clist = get(data, "comments", nothing)
            (clist === nothing || isempty(clist)) && break
            found_any = false

            for c in clist
                id       = string(get(c, "no", ""))
                depth    = get(c, "depth", 0)
                is_reply = depth > 0

                # 작성자
                name  = string(get(c, "name", ""))
                uid   = string(get(c, "user_id", ""))
                ip    = string(get(c, "ip", ""))
                author    = isempty(ip) ? name : "$name($ip)"
                author_id = isempty(uid) ? nothing : uid

                # 내용: HTML 포함 가능 → 텍스트 추출
                memo_raw = get(c, "memo", nothing)
                if memo_raw === nothing
                    contents = nothing
                else
                    memo_str = string(memo_raw)
                    if occursin("<", memo_str)
                        # HTML 포함 → Lexbor 로 텍스트 추출
                        memo_doc  = _parse_html(memo_str)
                        memo_root = Lexbor.Node(memo_doc)
                        memo_text = strip(_innertext(memo_root; sep=" "))
                        contents  = isempty(memo_text) ? nothing : memo_text
                    else
                        contents = isempty(strip(memo_str)) ? nothing : strip(memo_str)
                    end
                end

                # dccon (이미지 댓글)
                dccon = nothing
                voice = nothing
                voice_raw = get(c, "voice", nothing)
                voice_raw !== nothing && !isempty(string(voice_raw)) && (voice = string(voice_raw))

                # 시각
                reg_date  = string(get(c, "reg_date", "00:00"))
                post_time = try _parse_time(reg_date) catch; now() end

                put!(ch, Comment(id, is_reply, author, author_id, contents, dccon, voice, post_time))
                found_any  = true
                remaining -= 1
                remaining == 0 && return
            end

            found_any || break

            # 전체 댓글 수 확인으로 마지막 페이지 판단
            total_cnt = get(data, "total_cnt", 0)
            page * 20 >= total_cnt && break
        end
    end
end

"""
    write_comment(api, board_id, document_id;
                  contents="", dccon_id="", dccon_src="",
                  parent_comment_id="", name="", password="") -> String

댓글 작성. 작성된 댓글 ID 반환.
"""
function write_comment(api::API, board_id::AbstractString, document_id::AbstractString;
                       contents::AbstractString="",
                       dccon_id::AbstractString="",
                       dccon_src::AbstractString="",
                       parent_comment_id::AbstractString="",
                       name::AbstractString="",
                       password::AbstractString="")::String
    url  = "https://m.dcinside.com/board/$board_id/$document_id"
    html = _get(url)
    doc  = _parse_html(html)

    hr_n       = _query1(doc, "input.hide-robot")
    hide_robot = hr_n !== nothing ? something(_attr(hr_n, "name"), "") : ""
    csrf_n     = _query1(doc, "meta[name='csrf-token']")
    csrf_token = csrf_n !== nothing ? something(_attr(csrf_n, "content"), "") : ""
    title_n    = _query1(doc, "span.tit")
    title      = title_n !== nothing ? strip(_innertext(title_n; sep=" ")) : ""
    bnm_n      = _query1(doc, "a.gall-tit-lnk")
    board_name = bnm_n !== nothing ? strip(_innertext(bnm_n; sep=" ")) : ""

    con_key = _access("com_submit", url; require_conkey=false, csrf_token=csrf_token)

    hdrs = vcat(XML_HTTP_REQ_HEADERS, [
        "Referer"      => url,
        "Host"         => "m.dcinside.com",
        "Origin"       => "https://m.dcinside.com",
        "X-CSRF-TOKEN" => csrf_token,
    ])
    cookies = merge(BASE_COOKIES, Dict(
        "m_dcinside_$board_id" => board_id,
        "m_dcinside_lately"    => url_quote("$board_id|$board_name,"),
    ))

    memo = isempty(dccon_src) ? contents : "<img src='$dccon_src' class='written_dccon' alt='1'>"
    payload = [
        "comment_memo" => memo,
        "comment_nick" => name,
        "comment_pw"   => password,
        "mode"         => "com_write",
        "comment_no"   => parent_comment_id,
        "id"           => board_id,
        "no"           => document_id,
        "best_chk"     => "",
        "subject"      => title,
        "board_id"     => "0",
        "reple_id"     => "",
        "cpage"        => "1",
        "con_key"      => con_key,
        hide_robot     => "1",
    ]
    !isempty(dccon_id) && push!(payload, "detail_idx" => dccon_id)

    resp = _post("https://m.dcinside.com/ajax/comment-write", payload; headers=hdrs, cookies=cookies)
    parsed = try JSON.parse(resp)
             catch; error("Error while writing comment: " * url_unquote(resp)) end
    haskey(parsed, "data") || error("Error while writing comment: " * url_unquote(resp))
    string(parsed["data"])
end

"""
    write_document(api, board_id;
                   title="", contents="", name="", password="", is_minor=false)

게시글 작성.
"""
function write_document(api::API, board_id::AbstractString;
                        title::AbstractString="",
                        contents::AbstractString="",
                        name::AbstractString="",
                        password::AbstractString="",
                        is_minor::Bool=false)
    _write_or_modify(api, board_id;
                     title=title, contents=contents, name=name,
                     password=password, is_minor=is_minor)
end

"""
    modify_document(api, board_id, document_id;
                    title="", contents="", name="", password="", is_minor=false)

게시글 수정.
"""
function modify_document(api::API, board_id::AbstractString, document_id::AbstractString;
                         title::AbstractString="",
                         contents::AbstractString="",
                         name::AbstractString="",
                         password::AbstractString="",
                         is_minor::Bool=false)
    if isempty(password)
        url  = "https://m.dcinside.com/write/$board_id/modify/$document_id"
        html = _get(url)
        return _write_or_modify(api, board_id;
                                title=title, contents=contents,
                                name=name, password=password,
                                intermediate=html, intermediate_referer=url,
                                document_id=document_id, is_minor=is_minor)
    end

    url    = "https://m.dcinside.com/confirmpw/$board_id/$document_id?mode=modify"
    html   = _get(url)
    doc    = _parse_html(html)
    tok_n  = _query1(doc, "input[name='_token']")
    token  = tok_n !== nothing ? something(_attr(tok_n, "value"), "") : ""
    csrf_n = _query1(doc, "meta[name='csrf-token']")
    csrf   = csrf_n !== nothing ? something(_attr(csrf_n, "content"), "") : ""

    con_key = _access("Modifypw", url; require_conkey=false, csrf_token=csrf)
    pw_payload = [
        "_token"   => token,
        "board_pw" => password,
        "id"       => board_id,
        "no"       => document_id,
        "mode"     => "modify",
        "con_key"  => con_key,
    ]
    hdrs = vcat(XML_HTTP_REQ_HEADERS, [
        "Referer"      => url,
        "Host"         => "m.dcinside.com",
        "Origin"       => "https://m.dcinside.com",
        "X-CSRF-TOKEN" => csrf,
    ])
    res = _post("https://m.dcinside.com/ajax/pwcheck-board", pw_payload; headers=hdrs)
    isempty(strip(res)) && error("Error while modifying: maybe the password is incorrect")

    write_url  = "https://m.dcinside.com/write/$board_id/modify/$document_id"
    post_hdrs  = vcat(POST_HEADERS, ["Referer" => url])
    body_pl    = ["board_pw" => password, "id" => board_id, "no" => document_id, "_token" => csrf]
    inter_html = _post(write_url, body_pl; headers=post_hdrs)

    _write_or_modify(api, board_id;
                     title=title, contents=contents,
                     name=name, password=password,
                     intermediate=inter_html, intermediate_referer=write_url,
                     document_id=document_id, is_minor=is_minor)
end

"""
    remove_document(api, board_id, document_id; password="") -> Bool

게시글 삭제. 성공 시 `true`.
"""
function remove_document(api::API, board_id::AbstractString, document_id::AbstractString;
                         password::AbstractString="")::Bool
    if isempty(password)
        url  = "https://m.dcinside.com/board/$board_id/$document_id"
        html = _get(url)
        doc  = _parse_html(html)
        csrf_n = _query1(doc, "meta[name='csrf-token']")
        csrf   = csrf_n !== nothing ? something(_attr(csrf_n, "content"), "") : ""
        hdrs   = vcat(XML_HTTP_REQ_HEADERS, ["Referer" => url, "X-CSRF-TOKEN" => csrf])
        con_key = _access("board_Del", url; require_conkey=false, csrf_token=csrf)
        payload = ["id" => board_id, "no" => document_id, "con_key" => con_key]
        res = _post("https://m.dcinside.com/del/board", payload; headers=hdrs)
        occursin("true", res) || error("Error while removing: " * url_unquote(res))
        return true
    end

    url    = "https://m.dcinside.com/confirmpw/$board_id/$document_id?mode=del"
    html   = _get(url)
    doc    = _parse_html(html)
    tok_n  = _query1(doc, "input[name='_token']")
    token  = tok_n !== nothing ? something(_attr(tok_n, "value"), "") : ""
    csrf_n = _query1(doc, "meta[name='csrf-token']")
    csrf   = csrf_n !== nothing ? something(_attr(csrf_n, "content"), "") : ""
    bnm_n  = _query1(doc, "a.gall-tit-lnk")
    board_name = bnm_n !== nothing ? strip(_innertext(bnm_n; sep=" ")) : ""

    con_key = _access("board_Del", url; require_conkey=false, csrf_token=csrf)
    payload = [
        "_token"   => token,
        "board_pw" => password,
        "id"       => board_id,
        "no"       => document_id,
        "mode"     => "del",
        "con_key"  => con_key,
    ]
    hdrs    = vcat(XML_HTTP_REQ_HEADERS, ["Referer" => url, "X-CSRF-TOKEN" => csrf])
    cookies = merge(BASE_COOKIES, Dict(
        "m_dcinside_$board_id" => board_id,
        "m_dcinside_lately"    => url_quote("$board_id|$board_name,"),
    ))
    res = _post("https://m.dcinside.com/del/board", payload; headers=hdrs, cookies=cookies)
    occursin("true", res) || error("Error while removing: " * url_unquote(res))
    true
end

# ============================================================
# Internal: write / modify 공통 로직
# ============================================================

function _write_or_modify(api::API, board_id::AbstractString;
                          title::AbstractString="",
                          contents::AbstractString="",
                          name::AbstractString="",
                          password::AbstractString="",
                          intermediate::Union{AbstractString,Nothing}=nothing,
                          intermediate_referer::Union{AbstractString,Nothing}=nothing,
                          document_id::Union{AbstractString,Nothing}=nothing,
                          is_minor::Bool=false)
    if intermediate === nothing
        url  = "https://m.dcinside.com/write/$board_id"
        html = _get(url)
    else
        html = intermediate
        url  = something(intermediate_referer, "https://m.dcinside.com/write/$board_id")
    end
    first_url = url
    doc = _parse_html(html)

    code_n     = _query1(doc, "input[name='code']")
    rand_code  = code_n !== nothing ? _attr(code_n, "value") : nothing
    uid_n      = isempty(name) ? _query1(doc, "input[name='user_id']") : nothing
    user_id    = uid_n !== nothing ? _attr(uid_n, "value") : nothing
    mk_n       = _query1(doc, "#mobile_key")
    mobile_key = mk_n !== nothing ? something(_attr(mk_n, "value"), "") : ""
    hr_n       = _query1(doc, "input.hide-robot")
    hide_robot = hr_n !== nothing ? something(_attr(hr_n, "name"), "") : ""
    csrf_n     = _query1(doc, "meta[name='csrf-token']")
    csrf       = csrf_n !== nothing ? something(_attr(csrf_n, "content"), "") : ""
    bnm_n      = _query1(doc, "a.gall-tit-lnk")
    board_name = bnm_n !== nothing ? strip(_innertext(bnm_n; sep=" ")) : ""

    con_key = _access("dc_check2", url; require_conkey=false, csrf_token=csrf)

    filter_hdrs = vcat(XML_HTTP_REQ_HEADERS, ["Referer" => url, "X-CSRF-TOKEN" => csrf])
    filter_pl   = [
        "subject" => title,
        "memo"    => contents,
        "mode"    => "write",
        "id"      => board_id,
    ]
    rand_code !== nothing && push!(filter_pl, "code" => rand_code)
    fres = JSON.parse(_post("https://m.dcinside.com/ajax/w_filter", filter_pl; headers=filter_hdrs))
    get(fres, "result", false) || error("Error while writing document: $fres")

    upload_hdrs = vcat(POST_HEADERS, [
        "Host"    => "mupload.dcinside.com",
        "Referer" => first_url,
    ])
    payload = [
        "subject"      => title,
        "memo"         => contents,
        hide_robot     => "1",
        "GEY3JWF"      => hide_robot,
        "id"           => board_id,
        "contentOrder" => "order_memo",
        "mode"         => "write",
        "Block_key"    => con_key,
        "bgm"          => "",
        "iData"        => "",
        "yData"        => "",
        "tmp"          => "",
        "imgSize"      => "850",
        "is_minor"     => is_minor ? "1" : "",
        "mobile_key"   => mobile_key,
    ]
    rand_code !== nothing && push!(payload, "code" => rand_code)
    if !isempty(name)
        push!(payload, "name"     => name)
        push!(payload, "password" => password)
    elseif user_id !== nothing
        push!(payload, "user_id" => user_id)
    end
    if intermediate !== nothing
        # modify mode
        for (i, p) in enumerate(payload)
            p.first == "mode" && (payload[i] = "mode" => "modify")
        end
        push!(payload, "delcheck" => "")
        push!(payload, "t_ch2"    => "")
        push!(payload, "no"       => something(document_id, ""))
    end
    cookies = merge(BASE_COOKIES, Dict(
        "m_dcinside_$board_id" => board_id,
        "m_dcinside_lately"    => url_quote("$board_id|$board_name,"),
    ))
    _post("https://mupload.dcinside.com/write_new.php", payload; headers=upload_hdrs, cookies=cookies)
    nothing
end

end # module Dcinside
