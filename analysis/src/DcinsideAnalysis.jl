"""
    DcinsideAnalysis

genrenovel 갤러리 텍스트 분석용 재사용 레이어.
실험(experiments/)에서 공통으로 쓰이는 인프라를 모은 패키지.

서브모듈:
- [`Kiwi`](@ref)               — kiwipiepy 형태소 분석기 래퍼 (PyCall)
- [`Corpus`](@ref)             — 키워드 기반 코퍼스 수집 (search_board → document → comments)
- [`DcinsideDataFrames`](@ref) — DocumentIndex 이터러블 → DataFrame 변환

# 사용 예
```julia
using Dcinside, DcinsideAnalysis

api = Dcinside.API()
Kiwi.load_user_dict!("dict/base.dict")
df  = Corpus.collect(api, "genrenovel", ["나혼렙", "전독시"]; posts_per_keyword=20)
```
"""
module DcinsideAnalysis

include("Kiwi.jl")
include("Corpus.jl")
include("DcinsideDataFrames.jl")
include("NameDict.jl")

using .Kiwi, .Corpus, .DcinsideDataFrames, .NameDict

export Kiwi, Corpus, DcinsideDataFrames, NameDict

end # module DcinsideAnalysis
