open! Core

type t = private int [@@deriving sexp_of, compare, equal]

val create : string -> t Or_error.t

val create_exn : string -> t

val to_string : t -> string

val t1 : t

val t2 : t

val compare : t -> t -> int

module Valid_list : sig
  type tier := t

  type t = private tier list [@@deriving sexp_of]

  val create : tier list -> t Or_error.t
end

module Tier_or_fail : sig
  type tier := t

  type t = Tier of tier | Fail [@@deriving sexp_of]

  val to_string : t -> string

  val compare : t -> t -> int

  val worst_tier : t list -> t option
end

(** A map from Amino Acids (one or more) to Tiers. *)
module Map : sig
  type tier := t

  type t [@@deriving sexp_of]

  val tiny_toml_single_residue_term :
    default:(string * string) list -> string list -> t Tiny_toml.Term.t

  val tiny_toml_end_residues_term :
    default:(string * string) list -> string list -> t Tiny_toml.Term.t

  val of_alist_or_error : (string * tier) list -> t Or_error.t

  val find : t -> string -> Tier_or_fail.t
end
