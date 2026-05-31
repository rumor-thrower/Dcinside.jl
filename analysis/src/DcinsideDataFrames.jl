"""
    DcinsideDataFrames

`Dcinside.DocumentIndex` 이터러블을 타입 보정된 `DataFrame` 으로 변환한다.
"""
module DcinsideDataFrames

using DataFrames: DataFrame, transform!, ByRow
using Dcinside: DocumentIndex

# Function 필드(comments, document)를 제외한 열 이름 (타입 기반).
const _IDX_FNAMES = Tuple(
    f for f in fieldnames(DocumentIndex)
    if fieldtype(DocumentIndex, f) != Function
)

_to_row(idx) = NamedTuple{_IDX_FNAMES}(getfield(idx, f) for f in _IDX_FNAMES)

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

end # module DcinsideDataFrames
