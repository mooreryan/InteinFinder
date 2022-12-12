open! Core

module T = struct
  [@@@coverage off]

  type t = int [@@deriving sexp_of, compare, hash]

  [@@@coverage on]
end

include T
include Comparable.Make_plain (T)

let of_zero_indexed_int i = i

let of_one_indexed_int i = i - 1

let to_zero_indexed_int i = i

let to_one_indexed_int i = i + 1

let to_zero_indexed_string t = Int.to_string @@ to_zero_indexed_int t

let to_one_indexed_string t = Int.to_string @@ to_one_indexed_int t

let zero () = 0

let assert_positive_or_zero t =
  let i = to_zero_indexed_int t in
  if i < 0 then Or_error.errorf "Expected index >= 0, but got %d" i
  else Or_error.return ()
