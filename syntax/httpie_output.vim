" Syntax for the HTTPie output buffer
if exists("b:current_syntax")
  finish
endif

" Section comments at top
syntax match httpieOutputMeta "^#.*"

" HTTP status line in response headers (e.g. HTTP/1.1 200 OK)
syntax match httpieStatusLine "^HTTP/\S\+\s.*"
syntax match httpieStatus2xx "^HTTP/\S\+\s\+2\d\d.*" contains=httpieStatusLine
syntax match httpieStatus4xx "^HTTP/\S\+\s\+4\d\d.*" contains=httpieStatusLine
syntax match httpieStatus5xx "^HTTP/\S\+\s\+5\d\d.*" contains=httpieStatusLine

" Response headers
syntax match httpieHeader "^[A-Za-z][A-Za-z0-9_-]*:\s"

" JSON strings
syntax match httpieString '"[^"]*"'
" JSON keys
syntax match httpieKey '"\zs[^"]\+\ze"\s*:'
" JSON numbers
syntax match httpieNumber "\<\d\+\(\.\d\+\)\?\>"
" JSON booleans/null
syntax keyword httpieBoolean true false null

highlight default link httpieOutputMeta  Comment
highlight default link httpieStatus2xx   DiffAdd
highlight default link httpieStatus4xx   WarningMsg
highlight default link httpieStatus5xx   ErrorMsg
highlight default link httpieStatusLine  Statement
highlight default link httpieHeader      Type
highlight default link httpieString      String
highlight default link httpieKey         Identifier
highlight default link httpieNumber      Number
highlight default link httpieBoolean     Boolean

let b:current_syntax = "httpie_output"
