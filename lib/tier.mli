open! Core

type t = private int [@@deriving sexp_of, compare, equal]

val create : string -> t Or_error.t

val create_exn : string -> t

val to_int : t -> int

val to_string : t -> string

val t1 : t

val t2 : t

val is_t1 : t -> bool

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

  val of_alist_or_error : (string * tier) list -> t Or_error.t

  val of_toml :
       Otoml.t
    -> path:string list
    -> default:(string * Otoml.t) list
    -> t Or_error.t

  val find : t -> string -> Tier_or_fail.t

  (* Tmp types to help with the switch. *)
  type passes_maybies_c = {passes: Char.Set.t; maybies: Char.Set.t}

  val to_passes_maybies_c : t -> passes_maybies_c

  val of_passes_maybies_c : passes_maybies_c -> t

  type passes_maybies_s = {passes: String.Set.t; maybies: String.Set.t}

  val to_passes_maybies_s : t -> passes_maybies_s

  val of_passes_maybies_s : passes_maybies_s -> t
end
