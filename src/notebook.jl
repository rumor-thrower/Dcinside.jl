### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# ╔═╡ 281fde6a-f4cf-41a1-87e0-5d3fa8e136bd
module DC_API

# PyCall 로드 전에 SSL 인증서 경로 지정
# ENV["SSL_CERT_FILE"] = "/home/lim/Documents/Coding/Julia/NLP/src/.venv/lib/python3.12/site-packages/certifi/cacert.pem"
# ENV["REQUESTS_CA_BUNDLE"] = ENV["SSL_CERT_FILE"]

using PyCall

const asyncio = pyimport("asyncio")
const dc_api  = pyimport("dc_api")

py"""
import dc_api
import traceback

async def fetch_something():
    results = []
    async with dc_api.API() as api:
        async for idx in api.board(board_id="programming", num=5):
            try:
                doc = await idx.document()
            except Exception as e:
                results.append(("ERROR", f"{type(e).__name__}: {e}"))
                continue

            if doc is None:
                # 어떤 글에서 None이 나오는지 식별 정보를 남겨둔다
                results.append((
                    getattr(idx, "title", "?"),
                    f"<doc is None> id={getattr(idx, 'id', '?')}",
                ))
                continue

            results.append((idx.title, doc.contents))
    return results
"""

function fetch()
    return asyncio.run(py"fetch_something"())
end

end # module

# ╔═╡ 4742348c-574d-11f1-8031-1dd6b9bf726c
module HTTPRequest

using HTTP

function http_get(url::String, gallery_name::String, page_no::Int)::HTTP.Response
	resp = HTTP.get(url; query=["id" => gallery_name, "no" => page_no])
    return resp
end

function scrape_comment(api_url::String)
	headers = Dict(
		"User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:151.0) Gecko/20100101 Firefox/151.0"
	)
	body = (
		id="genrenovel",
		no="12283219",
		cmt_id="genrenovel",
		cmt_no="12283219",
		e_s_n_o="3eabc219ebdd65f536",
		comment_page="1",
		sort="D",
		_GALLTYPE_="M"
	)
	cookies = Dict(
		"PHPSESSID" => "922b5d74bcf7a9261400aac5eaa4f0cf",
		"ci_c" => "a71236f019eb73603b4dbfb567421eb5",
		"service_code" => "21ac6d96ad152e8f15a05b7350a2475909d19bcedeba9d4face8115e9bc0f8430e0aa9d93250548c6d0e71fdb27c85bc0925f36210c08f9db6b1c0b08c409445b627e8f9c0b7c1f480f6dbf7016a3a9d401f1700f9d61622e3f70c1b9befb716d600388250564dc2c0be13e0c51fad3ac22060b6e4539455a47a86ce47e40357791f63c5f74407750b0fc5a7beb1aa62d03e6ed578d20f4a3b66397a926614669db27fe7eea57ba58d202f527be422941cde9a5bda0d90689761eda5bdc704a655c003168ac076568a1afd",
		"alarm_popup" => "1",
		"last_alarm" => "1779619716",
		"img_comment" => "0"
	)
	resp = HTTP.post(api_url; headers=headers, body=body, cookies=cookies)
	return resp
end

end

# ╔═╡ a818cf94-06bb-4a15-904c-e5a45a5170c5
DC_API.fetch()

# ╔═╡ dd9fa8f9-ee6c-40b9-b498-5d778efb5e35
const URL = "https://gall.dcinside.com/mgallery/board/view"

# ╔═╡ c708a4f0-2482-4d84-94f7-cc734cc1a5c0
const gallery_name = "genrenovel"

# ╔═╡ d007246b-ed83-4b4b-8c4d-dc8524cb5bf5
const test_page_no = 12283219

# ╔═╡ cdc5e088-f1e0-443e-a6b6-e36b77518749
const resp = HTTPRequest.http_get(URL, gallery_name, test_page_no)

# ╔═╡ f6180771-ac11-4567-96ec-e0baa2a79915
const html = resp.body |> String

# ╔═╡ 3dc7e54a-9104-4ca3-9780-0ebfa53a04bb
# ╠═╡ disabled = true
#=╠═╡
# Embed HTML
HTML(html)
  ╠═╡ =#

# ╔═╡ f81a0e96-83c4-449f-87ad-9d98e7422603
module HTMLParse

import Lexbor
import AbstractTrees

function parse_html(html)::Lexbor.Document
	doc = Lexbor.Document(html)
	return doc
end

function query_doc(doc::Lexbor.Document, selector)::Vector{Lexbor.Node}
	nodes = Lexbor.query(doc, selector)
	return nodes
end

function iter_doc(doc::Lexbor.Document)
	node = Lexbor.Node(doc)
	return iter_doc(node::Lexbor.Node)
end

function iter_doc(node::Lexbor.Node)
	for node in AbstractTrees.PreOrderDFS(node)
		println(Lexbor.tag(node))
		if Lexbor.is_text(node)
			@show Lexbor.text(node)
		end
	end
end

function find_first_node(doc::Lexbor.Document, selector)
	root = Lexbor.Node(doc)
	return find_first_node(root, selector)
end

function find_first_node(root::Lexbor.Node, selector)
    # Create the `Matcher` object once, then reuse in the loop.
    matcher = Lexbor.Matcher(selector)
    for node in AbstractTrees.PreOrderDFS(root)
        if matcher(node)
            return node
        end
    end
    return nothing
end

get_node_attr(node::Lexbor.Node) = Lexbor.attributes(node)
get_node_text(node::Lexbor.Node) = Lexbor.text(node)
get_node_comment(node::Lexbor.Node) = Lexbor.comment(node)

show_tree(x) = Lexbor.Tree(x)

end

# ╔═╡ ac1f883b-8fe3-44e2-9ac9-624358b34e0d
const doc = HTMLParse.parse_html(html)

# ╔═╡ e63cb6cb-926c-4057-b1d4-cbdac171986f
# ╠═╡ show_logs = false
# Traverse the document contents
HTMLParse.iter_doc(doc)

# ╔═╡ 51a433de-8660-436b-a9ec-fe42a028412e
const titles = HTMLParse.query_doc(doc, "title")

# ╔═╡ a6034038-20e7-4cf4-aeda-8532684ca60c
const node = HTMLParse.find_first_node(doc, "title")

# ╔═╡ 89fc155e-a044-4b32-aec9-75878ab64828
const tree = HTMLParse.show_tree(node)

# ╔═╡ 29acde0c-769d-4b2e-8612-deea2ef513d1
const attrs = HTMLParse.get_node_attr(node)

# ╔═╡ 41376cbb-cd58-49c7-9164-2101451c4b95
const text = HTMLParse.get_node_text(node)

# ╔═╡ f982b4cf-2f63-449c-9b61-a1c01e8b77d2
const comment = HTMLParse.get_node_comment(node)

# ╔═╡ 9c9e951d-b26f-4469-a34e-befce57a9338


# ╔═╡ 13c8bcaa-c341-44af-aaab-20b49251f247
const comment_api_url = "https://gall.dcinside.com/board/comment/"

# ╔═╡ 19d867f0-bfa1-48db-baf3-6c11e47c5d09
HTTPRequest.scrape_comment(comment_api_url)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AbstractTrees = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
Lexbor = "7c3807c3-6380-4629-8731-66194421aa0a"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"

[compat]
AbstractTrees = "~0.4.5"
HTTP = "~1.11.0"
Lexbor = "~1.0.0"
PyCall = "~1.96.4"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "cec7917a5bee1e737cc3f2621c50cc3c9e6ef988"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "21d088c496ea22914fe80906eb5bce65755e5ec8"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.5.1"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "8f06b0cfa4c514c7b9546756dbae91fcfbc92dc9"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.10.3"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "51059d23c8bb67911a2e6fd5130229113735fc7e"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.11.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "f76f7560267b840e492180f9899b472f30b88450"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.6.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.Lexbor]]
deps = ["AbstractTrees", "CEnum", "lexbor_jll"]
git-tree-sha1 = "df5e64088a7c0424db4b84f4532640b4fdedb4fa"
uuid = "7c3807c3-6380-4629-8731-66194421aa0a"
version = "1.0.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f00544d95982ea270145636c181ceda21c4e2575"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.2.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "8785729fa736197687541f7053f6d8ab7fc44f92"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.10"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ff69a2b1330bcb730b9ac1ab7dd680176f5896b8"
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.1010+0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "NetworkOptions", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "1d1aaa7d449b58415f97d2839c318b70ffb525a0"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.6.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "5d5e0a78e971354b1c7bff0655d11fdc1b0e12c8"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.4"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "8b770b60760d4451834fe79dd483e318eee709c4"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "9816a3826b0ebf49ab4926e2b18842ad8b5c8f04"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.96.4"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "82bee338d650aa515f31866c460cb7e3bcef90b8"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.8.2"

    [deps.StructUtils.extensions]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.lexbor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "9c0ea94cf1cc2caa86e42d947723557638f2820f"
uuid = "be8d7a73-1782-5ce7-96ff-8fff21e5e970"
version = "2.4.0+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"
"""

# ╔═╡ Cell order:
# ╠═281fde6a-f4cf-41a1-87e0-5d3fa8e136bd
# ╠═a818cf94-06bb-4a15-904c-e5a45a5170c5
# ╠═4742348c-574d-11f1-8031-1dd6b9bf726c
# ╠═dd9fa8f9-ee6c-40b9-b498-5d778efb5e35
# ╠═c708a4f0-2482-4d84-94f7-cc734cc1a5c0
# ╠═d007246b-ed83-4b4b-8c4d-dc8524cb5bf5
# ╠═cdc5e088-f1e0-443e-a6b6-e36b77518749
# ╠═f6180771-ac11-4567-96ec-e0baa2a79915
# ╠═3dc7e54a-9104-4ca3-9780-0ebfa53a04bb
# ╠═f81a0e96-83c4-449f-87ad-9d98e7422603
# ╠═ac1f883b-8fe3-44e2-9ac9-624358b34e0d
# ╠═e63cb6cb-926c-4057-b1d4-cbdac171986f
# ╠═51a433de-8660-436b-a9ec-fe42a028412e
# ╠═a6034038-20e7-4cf4-aeda-8532684ca60c
# ╠═89fc155e-a044-4b32-aec9-75878ab64828
# ╠═29acde0c-769d-4b2e-8612-deea2ef513d1
# ╠═41376cbb-cd58-49c7-9164-2101451c4b95
# ╠═f982b4cf-2f63-449c-9b61-a1c01e8b77d2
# ╠═9c9e951d-b26f-4469-a34e-befce57a9338
# ╠═13c8bcaa-c341-44af-aaab-20b49251f247
# ╠═19d867f0-bfa1-48db-baf3-6c11e47c5d09
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
