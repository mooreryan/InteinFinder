open! Core

type t [@@deriving sexp_of]

val of_zero_indexed_int : int -> t

val to_zero_indexed_int : t -> int

val to_one_indexed_int : t -> int

val to_one_indexed_string : t -> string

val zero : unit -> t

include Comparable.S_plain with type t := t

val assert_positive_or_zero : t -> unit Or_error.t
