"""
    NameDict

base.dict / vocab.dict 고유명사 섹션 파서.
작품 줄임말·작가명을 `(form, canonical, entry_type)` 행으로 추출한다.
"""
module NameDict

using DataFrames
using Unicode

# ── 섹션 헤더 → 기본 entry_type 매핑 ────────────────────────────────────────
# `# ── …헤더… ──` 형식의 줄에서 아래 키워드를 찾아 섹션 기본 타입을 결정한다.
# 개별 행의 주석 판정(약칭/작가)이 우선하므로 여기는 fallback 역할만 한다.
const _SECTION_RULES = [
    "약칭"  => :work,
    "작품명" => :work,
    "작가명" => :author,
    "고유명사" => :other,  # base.dict 기본 섹션 — 행별 주석으로 세분
]

function _section_default(header::AbstractString)
    for (kw, t) in _SECTION_RULES
        occursin(kw, header) && return t
    end
    return nothing  # 인식 불가 → 섹션 밖으로 처리
end

"""
    parse(paths...) -> DataFrame

하나 이상의 dict 파일을 순서대로 파싱해 키워드 후보를 반환.
열: `form` (검색어), `canonical` (원형), `entry_type` (:work/:author/:other)

## 섹션 진입 조건
- `# ──` 로 시작하는 헤더 줄에서 아래 키워드로 섹션 기본 타입을 결정한다.
  - `약칭` / `작품명` → `:work`
  - `작가명`          → `:author`
  - `고유명사`        → `:other` (행별 주석으로 세분)
- 인식되지 않는 헤더 → 섹션 종료 (갤러리 은어·장르 등 무시)

## entry_type 판정 (우선순위 순)
1. 주석에 `약칭` 포함 → `:work`
2. 주석에 `작가` 포함 → `:author`
3. 섹션 기본 타입
4. `:other`

`약칭`을 먼저 검사하는 이유: 작품 제목 안에 "작가"가 포함된 경우
(예: <백작가의 망나니가 되었다>)가 `:author`로 오분류되는 것을 방지한다.

## NFD 정규화
dict 파일은 NFD(조합형) 한글로 저장돼 있어, NFC 리터럴(`"작가"`/`"약칭"`)과
바이트 단위로 일치하지 않는다. 각 줄을 `:NFC`로 정규화해 흡수한다.
"""
function parse(paths::AbstractString...)
    rows = NamedTuple[]
    for path in paths
        section_default = nothing  # 현재 섹션의 기본 entry_type
        for raw in eachline(path)
            line = Unicode.normalize(rstrip(raw), :NFC)
            if startswith(line, "#")
                occursin("──", line) && (section_default = _section_default(line))
                continue
            end
            (section_default !== nothing && !isempty(line)) || continue

            body, comment = let i = findfirst('#', line)
                i === nothing ? (line, "") : (line[1:prevind(line, i)], line[nextind(line, i):end])
            end
            fields = split(strip(body), '\t')
            length(fields) >= 2 || continue
            form = strip(fields[1])
            pos  = strip(fields[2])

            canonical  = occursin('/', pos) ? String(split(pos, '/')[1]) : form
            entry_type = occursin("약칭", comment) ? :work :
                         occursin("작가", comment) ? :author : section_default
            push!(rows, (form = form, canonical = canonical, entry_type = entry_type))
        end
    end
    DataFrame(rows)
end

end # module NameDict
