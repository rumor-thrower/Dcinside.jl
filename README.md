# Dcinside.jl

HTTP API client for the DCinside gallery — read/write galleries, posts, and comments.

## Features

- Fetch galleries, post lists, and search results
- Read documents and their comments
- Write, modify, and remove posts and comments
- Lexbor-based HTML parsing into typed structures (`Document`, `Comment`, `Image`, ...)

## Usage

```julia
using Dcinside

api = API()
docs = board(api, "genrenovel"; num = 10)
for d in docs
    println(d.title)
end
```

## Attribution

This package is a Julia port of
[dcinside-python3-api](https://github.com/eunchuldev/dcinside-python3-api)
("Deadly simple non official async dcinside api for python3"), originally
written by song9446 and released under the MIT License.

## License

[MIT](LICENSE) — original work © 2018 song9446, Julia port © 2026 rumor-thrower.
