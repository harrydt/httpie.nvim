" Syntax for .http request files (RFC 7230 / VS Code REST Client format)
if exists("b:current_syntax")
  finish
endif

" ### separator and request name
syntax match httpSeparator "^###.*" contains=httpSeparatorText
syntax match httpSeparatorText "^###\s*\zs.*" contained

" Comments
syntax match httpComment "^#\([^#]\|$\).*"

" HTTP methods
syntax keyword httpMethod GET POST PUT PATCH DELETE HEAD OPTIONS contained
syntax match httpRequestLine "^\(GET\|POST\|PUT\|PATCH\|DELETE\|HEAD\|OPTIONS\)\s.*" contains=httpMethod,httpUrl

" URL (crude but effective)
syntax match httpUrl "https\?://\S\+" contained

" Headers  (Key: value)
syntax match httpHeaderKey "^[A-Za-z][A-Za-z0-9_-]*\ze\s*:"
syntax match httpHeaderSep ":\s*" contained
syntax match httpHeaderValue "^[A-Za-z][A-Za-z0-9_-]*:\s*\zs.*"

" Template variables
syntax match httpVariable "{{[A-Za-z0-9_]\+}}"

" JSON-ish body (very light)
syntax match httpJsonKey '"\zs[^"]\+\ze"\s*:'
syntax match httpString '"[^"]*"'
syntax match httpNumber "\<\d\+\(\.\d\+\)\?\>"

highlight default link httpSeparator  Title
highlight default link httpSeparatorText Identifier
highlight default link httpComment    Comment
highlight default link httpMethod     Statement
highlight default link httpUrl        Underlined
highlight default link httpHeaderKey  Type
highlight default link httpHeaderValue String
highlight default link httpVariable   Special
highlight default link httpJsonKey    Identifier
highlight default link httpString     String
highlight default link httpNumber     Number

let b:current_syntax = "http"
