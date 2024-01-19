open! Core

module T = struct
  [@@@coverage off]

  type t = int [@@deriving sexp, compare, equal]

  [@@@coverage on]
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

let to_string t = [%string "T%{t#Int}"]

(* Lower tiers are better than higher tiers, so do opposite of normal int
   comparison. *)
let compare t1 t2 = Int.compare t2 t1

(* Could use tier option as well. *)
module Tier_or_fail = struct
  [@@@coverage off]

  type tier = t [@@deriving sexp_of, equal]

  type t = Tier of tier | Fail [@@deriving sexp_of, equal]

  [@@@coverage on]

  (* Fail is always, less than (or worse) than Tiers. Tiers compare as they
     normally do (eg lower tiers are better/greater than higher tiers). *)
  let compare t1 t2 =
    match (t1, t2) with
    | Fail, Fail ->
        0
    | Fail, Tier _ ->
        (* Fail is less than (worse) than a tier *)
        -1
    | Tier _, Fail ->
        (* Tier is greater than (better) than fail *)
        1
    | Tier t1, Tier t2 ->
        compare t1 t2

  let to_string = function
    | Tier t ->
        [%string "Pass (%{to_string t})"]
    | Fail ->
        "Fail"

  let worst_tier : t list -> t option = fun ts -> List.min_elt ts ~compare

  let%expect_test "worst tier" =
    print_s @@ [%sexp_of: t option] @@ worst_tier [] ;
    [%expect {| () |}] ;
    print_s @@ [%sexp_of: t option] @@ worst_tier [Fail] ;
    [%expect {| (Fail) |}] ;
    print_s @@ [%sexp_of: t option] @@ worst_tier [Tier t1] ;
    [%expect {| ((Tier 1)) |}] ;
    print_s @@ [%sexp_of: t option] @@ worst_tier [Tier t1; Fail] ;
    [%expect {| (Fail) |}] ;
    print_s @@ [%sexp_of: t option] @@ worst_tier [Fail; Tier t1] ;
    [%expect {| (Fail) |}] ;
    print_s @@ [%sexp_of: t option] @@ worst_tier [Tier t1; Tier t2; Fail] ;
    [%expect {| (Fail) |}] ;
    print_s @@ [%sexp_of: t option] @@ worst_tier [Tier t1; Tier t2] ;
    [%expect {| ((Tier 2)) |}]
end

(** Silly name, but it is a list of tiers that start at one, and increase in
    steps of 1 without skipping. I.e., a "valid" list of tiers. *)
module Valid_list = struct
  [@@@coverage off]

  type tier = t [@@deriving sexp_of]

  type t = tier list [@@deriving sexp_of]

  [@@@coverage on]

  (** Ensures tiers are sorted, unique, start at 1, and increase by 1. *)
  let create tiers =
    (* Using Core.Set.to_list to get a list sorted in the order specified by the
       compartor. Set.Make functor result no doesn't give the Accessor functions
       as of Core v0.16, so you must use the Core.Set directly. *)
    let tiers = Set.of_list tiers |> Core.Set.to_list in
    let sorted = List.sort tiers ~compare:Int.compare in
    let not_starts_at_one_and_increases_by_one l =
      List.existsi l ~f:(fun i tier -> tier <> i + 1)
    in
    if not_starts_at_one_and_increases_by_one sorted then
      Or_error.errorf
        "Expected tiers to start at one and increase by one, but got: %s"
        (Sexp.to_string_hum @@ [%sexp_of: int list] sorted)
    else Or_error.return sorted
end

module Map = struct
  [@@@coverage off]

  type tier = t [@@deriving sexp_of]

  (* Maps the residue(s) to its tier. *)
  type t = tier Map.M(String).t [@@deriving sexp_of]

  [@@@coverage on]

  (* let of_alist_or_error = String.Map.of_alist_or_error *)
  let of_alist_or_error alist =
    (* If there are no duplicate keys, return the alist, if there are, return an
       error with the duplicates. Need this to give better errors to the
       user. *)
    let unique_keys alist =
      let counts =
        List.fold alist ~init:String.Map.empty ~f:(fun key_counts (k, _) ->
            Map.update key_counts k ~f:(function None -> 1 | Some i -> i + 1) )
      in
      let non_unique_keys =
        Map.filteri counts ~f:(fun ~key:_ ~data:count -> count <> 1) |> Map.keys
      in
      match non_unique_keys with
      | [] ->
          Or_error.return alist
      | [key] ->
          Or_error.error "duplicate key" key String.sexp_of_t
      | keys ->
          Or_error.error "duplicate keys" keys [%sexp_of: string list]
    in
    let%bind.Or_error alist = unique_keys alist in
    String.Map.of_alist_or_error alist

  let otoml_from_string_oe s =
    Or_error.try_with (fun () -> Otoml.Parser.from_string s)

  (* Validate that start residue key is good and return Or_error. *)
  let single_residue_key s =
    if String.length s = 1 then Or_error.return @@ String.uppercase s
    else Or_error.errorf "expected key to be a single residue but got '%s'" s

  (* Validate that end_residues key is good and return Or_error. *)
  let end_residues_key s =
    if String.length s = 2 then Or_error.return @@ String.uppercase s
    else Or_error.errorf "expected key to be two end residues but got '%s'" s

  let residue_parser key_validator l =
    let open Or_error.Let_syntax in
    let residue_tier_list =
      List.map l ~f:(fun (k, v) ->
          let%bind tier = create v in
          let%map k = key_validator k in
          (k, tier) )
    in
    let%bind residue_tier_list = Or_error.all residue_tier_list in
    (* Now we check that the tiers are valid *)
    let tier_list = List.map residue_tier_list ~f:snd in
    let%bind _tier_list = Valid_list.create tier_list in
    let%bind map = of_alist_or_error residue_tier_list in
    return map

  let tiny_toml_converter residue_parser =
    let open Tiny_toml in
    let acc = Otoml.get_table_values Otoml.get_string in
    Converter.v acc residue_parser

  let tiny_toml_single_residue_term ~default path =
    Tiny_toml.Value.find_or ~default path
    @@ tiny_toml_converter
    @@ residue_parser single_residue_key

  let tiny_toml_end_residues_term ~default path =
    Tiny_toml.Value.find_or ~default path
    @@ tiny_toml_converter
    @@ residue_parser end_residues_key

  let find : t -> string -> Tier_or_fail.t =
   fun t element ->
    match Map.find t element with Some tier -> Tier tier | None -> Fail

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
        Tiny_toml.Term.eval ~config:toml
        @@ tiny_toml_single_residue_term path ~default
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
      run s ;
      [%expect
        {|
        (Error
         ("config error: yo"
          "Expected tiers to start at one and increase by one, but got: (2 3)")) |}]

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
