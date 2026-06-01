"""
    NameDict

base.dict 고유명사 섹션 파서.
작품 줄임말·작가명을 `(form, canonical, entry_type)` 행으로 추출한다.
"""
module NameDict

using DataFrames
using Unicode

"""
    parse(path) -> DataFrame

base.dict 의 `# ── …고유명사… ──` 섹션을 파싱해 키워드 후보를 반환.
열: `form` (검색어), `canonical` (원형), `entry_type` (:work/:author/:other)

## 행 유형
- 독립 NNP: `form\\tNNP\\t점수\\t# 주석` → `canonical = form`
- alias:    `form\\t원형/NNP\\t점수`      → `canonical = 원형`

## entry_type 판정 (우선순위 순)
1. 주석에 `약칭` 포함 → `:work`
2. 주석에 `작가` 포함 → `:author`
3. 그 외             → `:other`

`약칭`을 먼저 검사하는 이유: 작품 제목 안에 "작가"가 포함된 경우
(예: <백작가의 망나니가 되었다>)가 `:author`로 오분류되는 것을 방지한다.

## NFD 정규화
base.dict 는 NFD(조합형) 한글로 저장돼 있어, NFC 리터럴(`"작가"`/`"약칭"`)과
바이트 단위로 일치하지 않는다. 각 줄을 `:NFC`로 정규화해 흡수한다.
"""
function parse(path::AbstractString)
    rows = NamedTuple[]
    in_section = false
    for raw in eachline(path)
        line = Unicode.normalize(rstrip(raw), :NFC)
        if startswith(line, "#")
            occursin("──", line) && (in_section = occursin("고유명사", line))
            continue
        end
        (in_section && !isempty(line)) || continue

        body, comment = let i = findfirst('#', line)
            i === nothing ? (line, "") : (line[1:prevind(line, i)], line[nextind(line, i):end])
        end
        fields = split(strip(body), '\t')
        length(fields) >= 2 || continue
        form = strip(fields[1])
        pos  = strip(fields[2])

        canonical  = occursin('/', pos) ? String(split(pos, '/')[1]) : form
        entry_type = occursin("약칭", comment) ? :work :
                     occursin("작가", comment) ? :author : :other
        push!(rows, (form = form, canonical = canonical, entry_type = entry_type))
    end
    DataFrame(rows)
end

end # module NameDict
