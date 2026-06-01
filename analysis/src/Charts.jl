"""
    Charts

실험 노트북 공통 SVG 막대 차트 렌더러.

`barchart` 하나로 네 종류의 막대 차트(단색·타입별 색·회전 레이블·막대 간격)를
파라미터로 흡수한다. 반환값은 `HTML`(Pluto 인라인 표시용)이며,
`outfile` 지정 시 같은 SVG 를 파일로도 저장한다.
"""
module Charts

export barchart

_svg_text(s) = replace(string(s),
    "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

"""
    barchart(labels, vals; kwargs...) -> HTML

`labels`(x축) 과 `vals`(높이) 로 SVG 막대 차트를 그린다.

# 키워드 인자
- `colors`        : 단일 색 문자열(전체 동일) 또는 막대별 색 벡터. 기본 `"#4e79a7"`.
- `title`         : 차트 상단 `<h4>` 제목. `nothing` 이면 제목 없음.
- `width`,`height`: 명시하면 고정. `width=nothing`(기본) 이면 막대 수에 맞춰 산출.
- `bar_w`         : 막대 한 칸 폭(px). 기본 `nothing` → 너비에서 역산.
- `gap`           : 막대 사이 추가 간격(px). 기본 `0`.
- `rotate_labels` : `true` 면 x축 레이블을 -45° 회전(긴 한글 레이블용). 기본 `false`.
- `bold_values`   : 막대 위 값 라벨을 굵게. 기본 `false`.
- `legend`        : `(label, color)` 튜플 벡터. 지정 시 우상단 범례 표시. 기본 `nothing`.
- `outfile`       : 지정 시 해당 경로로 SVG 파일 저장.
"""
function barchart(labels, vals;
                  colors = "#4e79a7",
                  title = nothing,
                  width = nothing,
                  height = 280,
                  bar_w = nothing,
                  gap = 0,
                  rotate_labels::Bool = false,
                  bold_values::Bool = false,
                  legend = nothing,
                  outfile = nothing)
    n = length(labels)
    n == 0 && return HTML("<p style='font-family:sans-serif'>데이터 없음</p>")

    H     = height
    max_v = max(maximum(vals), 1)
    bar_h = H - 100                                   # 막대가 차지하는 세로 영역
    color_at(i) = colors isa AbstractString ? colors : colors[i]

    # 폭 산출: 고정 width 우선, 없으면 bar_w 기준, 둘 다 없으면 기본 bar_w 추정
    bw = isnothing(bar_w) ?
         (isnothing(width) ? 28 : (width - 80) ÷ n) :
         bar_w
    W  = isnothing(width) ? 80 + (bw + gap) * n : width
    step = bw + gap

    rects = IOBuffer()
    for (i, v) in enumerate(vals)
        h  = round(Int, v / max_v * bar_h)
        x  = 60 + (i - 1) * step
        cx = x + (bw ÷ 2)
        bar_top = H - 60 - h
        label = _svg_text(labels[i])

        print(rects, "<g>\n")
        print(rects, "  <rect x=\"$x\" y=\"$bar_top\" width=\"$(bw-3)\" height=\"$h\" ",
                     "fill=\"$(color_at(i))\" rx=\"2\"/>\n")
        if rotate_labels
            print(rects, "  <text x=\"$cx\" y=\"$(H-38)\" text-anchor=\"end\" ",
                         "dominant-baseline=\"middle\" font-size=\"11\" ",
                         "transform=\"rotate(-45 $cx $(H-38))\">$label</text>\n")
        else
            print(rects, "  <text x=\"$cx\" y=\"$(H-32)\" text-anchor=\"middle\" ",
                         "font-size=\"12\">$label</text>\n")
        end
        vw = bold_values ? " font-weight=\"bold\"" : ""
        print(rects, "  <text x=\"$cx\" y=\"$(bar_top-4)\" text-anchor=\"middle\" ",
                     "font-size=\"11\" fill=\"#333\"$vw>$v</text>\n")
        print(rects, "</g>\n")
    end

    legend_svg = ""
    if legend !== nothing
        parts = String[]
        for (i, (l, c)) in enumerate(legend)
            push!(parts, "<g transform=\"translate($(W-130+i*55),12)\">" *
                "<rect width=\"12\" height=\"12\" fill=\"$c\" rx=\"2\"/>" *
                "<text x=\"16\" y=\"10\" font-size=\"11\">$(_svg_text(l))</text></g>")
        end
        legend_svg = join(parts, "\n")
    end

    svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$W\" height=\"$H\" " *
          "style=\"font-family:sans-serif;overflow:visible\">\n" *
          legend_svg * "\n" * String(take!(rects)) * "</svg>"

    isnothing(outfile) || write(outfile, svg)

    head = isnothing(title) ? "" :
        "<h4 style=\"font-family:sans-serif;margin:8px 0\">$(_svg_text(title))</h4>"
    HTML("<div>$head$svg</div>")
end

end # module Charts
