using Test
using Dates
using Dcinside

# ────────────────────────────────────────────────────────────
# 헬퍼
# ────────────────────────────────────────────────────────────

"""
DocumentIndex 의 필수 필드가 모두 채워져 있는지 검사.
`skip` 에 나열한 필드는 `nothing` / `""` 을 허용한다.
"""
function check_index_fields(idx::DocumentIndex; skip=(:subject,))
    for fname in fieldnames(DocumentIndex)
        fname in skip && continue
        val = getfield(idx, fname)
        if val isa Function
            @testset "$fname is callable" begin @test val isa Function end
        else
            @testset "$fname not nothing" begin @test !isnothing(val) end
            @testset "$fname not empty"   begin @test string(val) != "" end
        end
    end
end

"""Document 의 필수 필드 검사."""
function check_doc_fields(doc::Document; skip=(:subject, :author_id))
    for fname in fieldnames(Document)
        fname in skip && continue
        val = getfield(doc, fname)
        if val isa Function
            @testset "$fname is callable" begin @test val isa Function end
        else
            @testset "$fname not nothing" begin @test !isnothing(val) end
            @testset "$fname not empty"   begin @test string(val) != "" end
        end
    end
end

"""Comment 의 필수 필드 검사."""
function check_comment_fields(comm::Comment; skip=(:contents, :dccon, :voice, :author_id))
    for fname in fieldnames(Comment)
        fname in skip && continue
        val = getfield(comm, fname)
        @testset "$fname not nothing" begin @test !isnothing(val) end
        @testset "$fname not empty"   begin @test string(val) != "" end
    end
    # contents / dccon / voice 중 최소 하나는 있어야 함
    @test !isnothing(something(comm.contents, comm.dccon, comm.voice, nothing))
end

# ────────────────────────────────────────────────────────────
# 테스트 스위트
# ────────────────────────────────────────────────────────────

@testset "Dcinside.jl" begin

    api = API()

    # ── 1. API 생성 ──────────────────────────────────────────
    @testset "API 생성" begin
        @test api isa API
    end

    # ── 2. 마이너 갤러리 글 1개 읽기 ────────────────────────
    @testset "마이너 갤러리(aoegame) 글 1개 읽기" begin
        ch  = board(api, "aoegame"; num=1)
        idx = take!(ch)

        check_index_fields(idx)
        @test idx.time > now() - Hour(1)
        @test idx.time < now() + Hour(1)
    end

    # ── 3. 마이너 갤러리 글 201개 읽기 ──────────────────────
    @testset "마이너 갤러리(aoegame) 글 201개 읽기" begin
        cnt = 0
        for idx in board(api, "aoegame"; num=201)
            check_index_fields(idx)
            @test idx.time > now() - Hour(24)
            @test idx.time < now() + Hour(1)
            cnt += 1
        end
        @test isapprox(cnt, 201; atol=5)
    end

    # ── 4. 메이저 갤러리 고정 댓글 (회귀 테스트) ────────────
    @testset "프로그래밍 갤러리 고정 댓글 (doc 1847628)" begin
        comms = collect(comments(api, "programming", "1847628"))
        @test length(comms) >= 5

        c1, c2, c3, c4, c5 = comms[1:5]

        @test c1.author   == "ㅇㅇ(112.172)"
        @test c1.contents == "뭐하러일함  - dc App"
        @test !c1.is_reply
        @test c1.time     == DateTime(2021, 8, 21, 12, 28, 8)

        @test c2.author   == "ㅇㅇ(39.121)"
        @test !c2.is_reply
        @test c2.time     == DateTime(2021, 8, 21, 12, 32, 11)

        @test c3.is_reply
        @test c3.time     == DateTime(2021, 8, 21, 12, 40, 32)

        @test c4.is_reply
        @test c4.time     == DateTime(2021, 8, 21, 12, 42, 28)

        @test c5.author   == "ㅇㅇ(202.150)"
        @test !c5.is_reply
        @test c5.time     == DateTime(2021, 8, 21, 12, 45, 7)
    end

    # ── 5. 마이너 갤러리 최신 글 댓글 검사 ─────────────────
    @testset "마이너 갤러리(aoegame) 최신 글 댓글" begin
        for idx in board(api, "aoegame")
            comms = collect(idx.comments())
            isempty(comms) && continue
            for comm in comms
                check_comment_fields(comm)
                @test comm.time > now() - Hour(1)
                @test comm.time < now() + Hour(1)
            end
            break
        end
    end

    # ── 6. 메이저 갤러리 글 1개 읽기 ────────────────────────
    @testset "프로그래밍 갤러리 글 1개 읽기" begin
        ch  = board(api, "programming"; num=1)
        idx = take!(ch)

        check_index_fields(idx)
        @test idx.time > now() - Hour(24)
        @test idx.time < now() + Hour(1)
    end

    # ── 7. 메이저 갤러리 글 201개 읽기 ─────────────────────
    @testset "프로그래밍 갤러리 글 201개 읽기" begin
        count = 0
        for idx in board(api, "programming"; num=201)
            check_index_fields(idx)
            @test idx.time > now() - Hour(24)
            @test idx.time < now() + Hour(1)
            count += 1
        end
        @test isapprox(count, 201; atol=5)
    end

    # ── 8. 메이저 갤러리 최신 글 댓글 검사 ─────────────────
    @testset "프로그래밍 갤러리 최신 글 댓글" begin
        for idx in board(api, "programming")
            comms = collect(idx.comments())
            isempty(comms) && continue
            for comm in comms
                check_comment_fields(comm)
                @test comm.time > now() - Hour(24)
                @test comm.time < now() + Hour(1)
            end
            break
        end
    end

    # ── 9. 마이너 갤러리 글 본문 읽기 ───────────────────────
    @testset "마이너 갤러리(aoegame) 글 본문" begin
        ch  = board(api, "aoegame"; num=1)
        idx = take!(ch)
        doc = idx.document()

        @test !isnothing(doc)
        if !isnothing(doc)
            check_doc_fields(doc)
            @test doc.time > now() - Hour(1)
            @test doc.time < now() + Hour(1)
        end
    end

    # ── 10. 메이저 갤러리 글 본문 읽기 ──────────────────────
    @testset "프로그래밍 갤러리 글 본문" begin
        ch  = board(api, "programming"; num=1)
        idx = take!(ch)
        doc = idx.document()

        @test !isnothing(doc)
        if !isnothing(doc)
            check_doc_fields(doc; skip=(:subject, :author_id))
            @test doc.time > now() - Hour(1)
            @test doc.time < now() + Hour(1)
        end
    end

    # ── (선택 실행) 글 작성 / 수정 / 삭제 테스트 ───────────
    if get(ENV, "DC_TEST_WRITE", "0") == "1"

        @testset "글 작성/수정/삭제 (프로그래밍 갤러리)" begin
            bid    = "programming"
            doc_id = write_document(api, bid;
                                    title="제목", contents="내용",
                                    name="닉네임", password="비밀번호")
            @test !isnothing(doc_id) && doc_id != ""

            doc = document(api, bid, doc_id)
            @test !isnothing(doc)
            @test doc.contents == "내용"

            modify_document(api, bid, doc_id;
                            title="수정된 제목", contents="수정된 내용",
                            name="수정된 닉네임", password="비밀번호")
            doc2 = document(api, bid, doc_id)
            @test !isnothing(doc2)
            @test doc2.contents == "수정된 내용"

            comm_id = write_comment(api, bid, doc_id;
                                    contents="댓글", name="닉네임", password="비밀번호")
            @test !isnothing(comm_id) && comm_id != ""

            comms = collect(comments(api, bid, doc_id))
            @test !isempty(comms)
            @test first(comms).contents == "댓글"

            @test remove_document(api, bid, doc_id; password="비밀번호")
            @test isnothing(document(api, bid, doc_id))
        end

        @testset "글 작성/수정/삭제 (마이너: stick 갤러리)" begin
            bid    = "stick"
            doc_id = write_document(api, bid;
                                    title="제목", contents="내용",
                                    name="닉네임", password="비밀번호",
                                    is_minor=true)
            @test !isnothing(doc_id) && doc_id != ""

            doc = document(api, bid, doc_id)
            @test !isnothing(doc)
            @test doc.contents == "내용"

            modify_document(api, bid, doc_id;
                            title="수정된 제목", contents="수정된 내용",
                            name="수정된 닉네임", password="비밀번호",
                            is_minor=true)
            doc2 = document(api, bid, doc_id)
            @test !isnothing(doc2)
            @test doc2.contents == "수정된 내용"

            comm_id = write_comment(api, bid, doc_id;
                                    contents="댓글", name="닉네임", password="비밀번호")
            @test !isnothing(comm_id) && comm_id != ""

            comms = collect(comments(api, bid, doc_id))
            @test !isempty(comms)
            @test first(comms).contents == "댓글"

            @test remove_document(api, bid, doc_id; password="비밀번호")
            @test isnothing(document(api, bid, doc_id))
        end

    end # DC_TEST_WRITE

end # @testset "Dcinside.jl"
