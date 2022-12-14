open! Core

type t = private int [@@deriving sexp_of]

val create : string -> t Or_error.t

val create_exn : string -> t

val to_int : t -> int

val to_string : t -> string

module Valid_list : sig
  type tier := t

  type t = private tier list [@@deriving sexp_of]

  val create : tier list -> t Or_error.t
end
