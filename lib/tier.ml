open! Core

type t = int [@@deriving sexp_of]

let tier_match = Re.(compile @@ seq [bos; str "T"; group @@ rep1 digit; eos])

let tier s =
  let open Option.Let_syntax in
  let%bind re_group = Re.exec_opt tier_match s in
  let%map result = Re.Group.get_opt re_group 1 in
  Int.of_string result

let create s =
  match tier s with
  | None ->
      Or_error.errorf "Bad tier format for '%s'" s
  | Some result ->
      if result >= 1 then Or_error.return result
      else Or_error.errorf "Tier number must be >= 1.  Got %d." result

let create_exn s = Or_error.ok_exn @@ create s

let to_int t = t

let to_string t = Int.to_string t

(** Silly name, but it is a list of tiers that start at one, and increase in
    steps of 1 without skipping. I.e., a "valid" list of tiers. *)
module Valid_list : sig
  type tier := t [@@deriving sexp_of]

  type t = private tier list [@@deriving sexp_of]

  val create : tier list -> t Or_error.t
end = struct
  type tier = t [@@deriving sexp_of]

  type t = tier list [@@deriving sexp_of]

  (** Ensures tiers are sorted, start at 1, and increase by 1. *)
  let create tiers =
    let sorted = List.sort tiers ~compare:Int.compare in
    let starts_at_one_and_increases_by_one l =
      List.existsi l ~f:(fun i tier -> tier <> i + 1)
    in
    if starts_at_one_and_increases_by_one sorted then
      Or_error.errorf
        "Bad tiers: %s"
        (Sexp.to_string_hum @@ [%sexp_of: int list] sorted)
    else Or_error.return sorted
end
