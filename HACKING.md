# Hacking

## Code Coverage

Use `@@@coverage off/on` around types with `ppx` generated code.  E.g.,

```ocaml
[@@@coverage off]

type t = A | B [@@deriving sexp]

[@@@coverage on]
```

Use `[@coverage off]` around impossible cases.  Use it with `impossible` or `invalid_argf`.

```ocaml
let x = 1

if x > 0 then 
  x 
else 
  Utils.impossible "x can't be negative here" [@coverage off]
```
