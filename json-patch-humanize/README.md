# JSON::Patch::Humanize

A simple perl module to convert JSON Patch arrays to arrays of readable strings.

Example:

```
[    
    { "op"=> "repace", "path"=> "/baz", "value"=> "boo", "old"=> "asd" },
    { "op"=> "add", "path"=> "/hello", "value"=> ["world"] },
    { "op"=> "remove", "path"=> "/foo", "old"=> "bar"},
    { "op"=> "move", "path"=> "/a", "from"=> "/b", "value"=> 2}
]
```

is converted to:

```
[
    'Changed value from "asd" to "boo" at /baz.',
    'Added value ["world"] at /hello.',
    'Deleted value "bar" at /foo.',
    'Moved value 2 from /b to /a.'
]
```

#### TODO

* Syntax configuration strings: `Value $VALUE$ changed from $OLD$ to $NEW$ at $PATH$.`
