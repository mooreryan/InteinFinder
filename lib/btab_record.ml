(** Extension module to use in place of Bio_io.Btab.Record.Parsed. *)

include Bio_io.Btab.Record.Parsed

(** Swap query start and end. *)
let canonicalize_qse r =
  if r.qstart > r.qend then {r with qstart= r.qend; qend= r.qstart} else r

(** Swap target start and end. *)
let canonicalize_tse r =
  if r.tstart > r.tend then {r with tstart= r.tend; tend= r.tstart} else r

(** Make sure the starts come before the ends. *)
let canonicalize r = r |> canonicalize_qse |> canonicalize_tse

(** Sort records by query start then by query end. *)
let compare_qstart_qend a z =
  (* First try to compare based on increasing query start. *)
  match Int.compare a.qstart z.qstart with
  (* If qstart is equal for both hits, sort the one with the lower qend
     first. *)
  | 0 ->
      Int.compare a.qend z.qend
  (* If not equal, just return the original sort result. *)
  | n ->
      n

let compare_bits_desc a z = Float.compare (bits z) (bits a)
