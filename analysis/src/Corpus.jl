"""
    Corpus

키워드 기반 코퍼스 수집: `search_board → document → comments` 순으로
제목·본문·댓글 행을 모아 `DataFrame` 으로 반환한다.
"""
module Corpus

using DataFrames
using Dcinside

_doc_row(doc, idx, kw) = (
    source_id   = idx.id * "_body",
    doc_id      = idx.id,
    keyword     = kw,
    source_type = :post_body,
    text        = doc.contents,
    author      = idx.author,
    timestamp   = idx.time,
    view_count  = idx.view_count,
    voteup      = idx.voteup_count,
)

_comment_row(c, idx, kw) = (
    source_id   = c.id,
    doc_id      = idx.id,
    keyword     = kw,
    source_type = :comment,
    text        = c.contents,
    author      = c.author,
    timestamp   = c.time,
    view_count  = 0,
    voteup      = 0,
)

function _update_rows_with_doc!(doc, idx, kw, rows)
    (isnothing(doc) || isempty(doc.contents)) && return
    push!(rows, _doc_row(doc, idx, kw))
end

function _handle_document!(fetch_fulltext, idx, kw, rows)
    fetch_fulltext || return
    _update_rows_with_doc!(idx.document(), idx, kw, rows)
end

function _handle_comments!(fetch_comments, idx, kw, rows)
    fetch_comments || return
    ch = idx.comments()
    try
        for c in ch
            c.contents === nothing && continue
            push!(rows, _comment_row(c, idx, kw))
        end
    finally
        close(ch)
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
    collect(api, board_id, keywords; posts_per_keyword, fetch_fulltext, fetch_comments)
    -> DataFrame

각 키워드로 `search_board → document → comments` 순 수집.

반환 열: `source_id`, `doc_id`, `keyword`, `source_type` (:post_title/:post_body/:comment),
         `text`, `author`, `timestamp`, `view_count`, `voteup`
"""
function collect(api, board_id, keywords;
                 posts_per_keyword::Int=20,
                 fetch_fulltext::Bool=true,
                 fetch_comments::Bool=true)
    rows     = NamedTuple[]
    seen_ids = Set{String}()
    for kw in keywords
        for idx in Dcinside.search_board(api, board_id, kw; num=posts_per_keyword)
            idx.id in seen_ids && continue
            push!(rows, _title_row(idx, kw))
            push!(seen_ids, idx.id)
            _handle_document!(fetch_fulltext, idx, kw, rows)
            _handle_comments!(fetch_comments, idx, kw, rows)
        end
    end
    DataFrame(rows)
end

end # module Corpus
