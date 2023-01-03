open! Core

module T = struct
  type t = int [@@deriving sexp, compare, equal]
end

include T
include Comparator.Make (T)
module Set = Set.Make (T)

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

(* Define the first couple of tiers for simplifying defaults. *)
let t1 = create_exn "T1"

let t2 = create_exn "T2"

let to_int t = t

let to_string t = [%string "T%{t#Int}"]

(* Could use tier option as well. *)
module Tier_or_fail = struct
  type tier = t [@@deriving sexp_of]

  type t = Tier of tier | Fail [@@deriving sexp_of]

  let to_string = function Tier t -> to_string t | Fail -> "Fail"
end

(** Silly name, but it is a list of tiers that start at one, and increase in
    steps of 1 without skipping. I.e., a "valid" list of tiers. *)
module Valid_list = struct
  type tier = t [@@deriving sexp_of]

  type t = tier list [@@deriving sexp_of]

  (** Ensures tiers are sorted, unique, start at 1, and increase by 1. *)
  let create tiers =
    let tiers = Set.of_list tiers |> Set.to_list in
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

(* type tier = t [@@deriving sexp_of] *)

module Map = struct
  type tier = t [@@deriving sexp_of]

  type t = tier Map.M(String).t [@@deriving sexp_of]

  let of_alist_or_error = String.Map.of_alist_or_error

  let otoml_from_string_oe s =
    Or_error.try_with (fun () -> Otoml.Parser.from_string s)

  let of_toml toml ~path ~default =
    let open Or_error.Let_syntax in
    let otoml_get_tier otoml = Otoml.get_string otoml |> create in
    let l = Otoml.find_or toml Otoml.get_table path ~default in
    let l =
      List.map l ~f:(fun (k, v) ->
          let%map tier = otoml_get_tier v in
          (k, tier) )
    in
    let%bind l = Or_error.all l in
    let tiers : tier list = List.map l ~f:snd in
    let%bind _list = Valid_list.create tiers in
    let%bind map = of_alist_or_error l in
    return map

  let find : t -> string -> Tier_or_fail.t =
   fun t element ->
    match Map.find t element with Some tier -> Tier tier | None -> Fail

  (* Tmp types to help with the switch. *)
  type passes_maybies_c = {passes: Char.Set.t; maybies: Char.Set.t}

  type passes_maybies_s = {passes: String.Set.t; maybies: String.Set.t}

  let t1_keys t = Map.filter t ~f:(equal t1) |> Map.keys

  let non_t1_keys t = Map.filter t ~f:(Fn.non @@ equal t1) |> Map.keys

  let char_set_of_string_list l =
    Char.Set.of_list @@ List.map ~f:Char.of_string l

  let to_passes_maybies_c : t -> passes_maybies_c =
   fun t ->
    { passes= char_set_of_string_list @@ t1_keys t
    ; maybies= char_set_of_string_list @@ non_t1_keys t }

  let to_passes_maybies_s : t -> passes_maybies_s =
   fun t ->
    { passes= String.Set.of_list @@ t1_keys t
    ; maybies= String.Set.of_list @@ non_t1_keys t }

  let of_passes_maybies_c : passes_maybies_c -> t =
    let add_to_tier_map tier_map aa ~tier =
      Core.Map.add_exn tier_map ~key:(String.of_char aa) ~data:tier
    in
    fun {passes; maybies} ->
      let t = String.Map.empty in
      let t = Core.Set.fold passes ~init:t ~f:(add_to_tier_map ~tier:t1) in
      let t = Core.Set.fold maybies ~init:t ~f:(add_to_tier_map ~tier:t2) in
      t

  let of_passes_maybies_s : passes_maybies_s -> t =
    let add_to_tier_map tier_map aa ~tier =
      Core.Map.add_exn tier_map ~key:aa ~data:tier
    in
    fun {passes; maybies} ->
      let t = String.Map.empty in
      let t = Core.Set.fold passes ~init:t ~f:(add_to_tier_map ~tier:t1) in
      let t = Core.Set.fold maybies ~init:t ~f:(add_to_tier_map ~tier:t2) in
      t

  module Test = struct
    let key = "yo"

    let path = [key]

    let default = []

    let run s =
      let s = [%string {|
[%{key}]
%{s}
|}] in
      let t =
        let%bind.Or_error toml = otoml_from_string_oe s in
        of_toml toml ~path ~default
      in
      print_s @@ [%sexp_of: t Or_error.t] t

    let%expect_test _ =
      let s = {|
A = "T1"
B = "T2"
C = "T1"
|} in
      run s ; [%expect {| (Ok ((A 1) (B 2) (C 1))) |}]

    let%expect_test _ =
      let s = {|
A = "T2"
B = "T2"
C = "T3"
|} in
      run s ; [%expect {| (Error "Bad tiers: (2 3)") |}]

    let%expect_test _ =
      let s = {|
A = "T2"
A = "T1"
|} in
      run s ;
      [%expect
        {|
        (Error
         ("Otoml__Common.Duplicate_key(\"duplicate key \\\"A\\\" overrides a value of type string with a value of type string\")")) |}]
  end
end
