open! Core

(** [name_map] maps new (aka renamed) names to the old (orig) names. *)
type t = {file_name: string; name_map: string Map.M(String).t}
[@@deriving fields, sexp_of]

val rename_seqs : seq_file:string -> out_dir:string -> min_length:int -> t
