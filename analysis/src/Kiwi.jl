"""
    Kiwi

kiwipiepy.Kiwi 형태소 분석기 래퍼 (싱글톤 + 사용자 사전 로드).
"""
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

`form => tag` 사전으로 반환.
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
형식: 탭 구분 `단어\\t품사` (한 줄에 하나).
파일이 수정되지 않았으면 재로드를 생략한다.
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

end # module Kiwi
