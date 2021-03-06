open Constraints
open Syntax

exception Type_error of string

(* Utilities *)

let rec is_static_type = function
  | TyFun (t1, t2) -> (is_static_type t1) && (is_static_type t2)
  | TyDyn -> false
  | _ -> true

let is_base_type = function
  | TyInt | TyBool -> true
  | _ -> false

let is_tyvar = function
  | TyVar _ -> true
  | _ -> false

let is_typaram = function
  | TyParam _ -> true
  | _ -> false

(* Base type, type variables, or type parameters *)
let is_bvp_type t = is_base_type t || is_tyvar t || is_typaram t

(* Type Variables *)

module Variables = Set.Make(
  struct
    type t = tyvar
    let compare (x : tyvar) y = compare x y
  end
)

let fresh_tyvar =
  let counter = ref 0 in
  let body () =
    let v = !counter in
    counter := v + 1;
    TyVar (v + 1)
  in body

let rec tyvars = function
  | TyVar x -> Variables.singleton x
  | TyFun (t1, t2) -> Variables.union (tyvars t1) (tyvars t2)
  | _ -> Variables.empty

(* Substitutions *)

type substitution = tyvar * ty
type substitutions = substitution list

let string_of_substitution (x, t) =
  Printf.sprintf "x%d=%s" x @@ string_of_type t

let string_of_substitutions s =
  String.concat ", " @@ List.map string_of_substitution s

let subst_type_substitutions (t : ty) (s : substitutions) =
  List.fold_left (fun u -> fun (x, t) -> subst_type x t u) t s

module TyVarMap = Map.Make (
  struct
    type t = tyvar
    let compare (x : tyvar) y = compare x y
  end
)

let fresh_typaram =
  let counter = ref 0 in
  let body () =
    let v = !counter in
    counter := v + 1;
    TyParam (v + 1)
  in body

let rec subst_tyvar t m = match t with
  | TyVar x -> TyVarMap.find x m
  | TyFun (t1, t2) -> TyFun (subst_tyvar t1 m, subst_tyvar t2 m)
  | _ -> t

(* Create map from type parameters to type variables *)
let create_tyvar_typaram_map t =
  let vars = tyvars t in
  let f x m =
    if TyVarMap.mem x m then
      m
    else
      TyVarMap.add x (fresh_typaram ()) m
  in
  Variables.fold f vars TyVarMap.empty

(* Replace type variables with type parameters *)
let subst_tyvars (t : ty) : ty =
  subst_tyvar t @@ create_tyvar_typaram_map t

(* Type Inference *)

let generate_constraints env e =
  let generate_constraints_codomain = function
  | TyVar x ->
      let x1, x2 = fresh_tyvar (), fresh_tyvar () in
      x2, Constraints.singleton @@ ConstrEqual ((TyVar x), (TyFun (x1, x2)))
  | TyFun (u1, u2) -> u2, Constraints.empty
  | TyDyn -> TyDyn, Constraints.empty
  | _ -> raise @@ Type_error "error"
  in
  let generate_constraints_domain u1 u2 = match u1 with
  | TyVar x ->
      let x1, x2 = fresh_tyvar (), fresh_tyvar () in
      let c = Constraints.singleton @@ ConstrEqual ((TyVar x), (TyFun (x1, x2))) in
      Constraints.add (ConstrConsistent (x1, u2)) c
  | TyFun (u11, u12) ->
      Constraints.singleton @@ ConstrConsistent (u11, u2)
  | TyDyn -> Constraints.singleton @@ ConstrConsistent (u1, u2)
  | _ -> raise @@ Type_error "error"
  in
  let rec generate_constraints env e = match e with
  | Var x ->
      let t = try
        Environment.find x env
      with
      | Not_found -> raise @@ Type_error (Printf.sprintf "variable '%s' not found in the environment" x)
      in
      t, Constraints.empty
  | Const c ->
      let t = begin match c with
      | ConstBool b -> TyBool
      | ConstInt i -> TyInt
      end in
      t, Constraints.empty
  | BinOp (op, e1, e2) ->
      let u1, c1 = generate_constraints env e1 in
      let u2, c2 = generate_constraints env e2 in
      let c = Constraints.union c1 c2 in
      let c = Constraints.add (ConstrConsistent (u1, TyInt)) c in
      let c = Constraints.add (ConstrConsistent (u2, TyInt)) c in
      TyInt, c
  | FunI (x, e) ->
      let x_t = fresh_tyvar () in
      let env' = Environment.add x x_t env in
      let u, c = generate_constraints env' e in
      TyFun (x_t, u), c
  | FunE (x, x_t, e) ->
      let env' = Environment.add x x_t env in
      let u, c = generate_constraints env' e in
      TyFun (x_t, u), c
  | App (e1, e2) ->
      let u1, c1 = generate_constraints env e1 in
      let u2, c2 = generate_constraints env e2 in
      let u3, c3 = generate_constraints_codomain u1 in
      let c4 = generate_constraints_domain u1 u2 in
      let c = Constraints.union c1 c2 in
      let c = Constraints.union c c3 in
      let c = Constraints.union c c4 in
      u3, c
  in
  generate_constraints env e

let unify c : substitutions =
  let rec unify c =
    match c with
    | [] -> []
    | ConstrConsistent (u1, u2) :: c when u1 = u2 && is_bvp_type u1 ->
        unify c
    | ConstrConsistent (TyDyn, _) :: c
    | ConstrConsistent (_, TyDyn) :: c ->
        unify c
    | ConstrConsistent (TyFun (u11, u12), TyFun (u21, u22)) :: c ->
        unify @@ ConstrConsistent (u11, u21) :: ConstrConsistent (u12, u22) :: c
    | ConstrConsistent (u, TyVar x) :: c when not @@ is_tyvar u ->
        unify @@ ConstrConsistent (TyVar x, u) :: c
    | ConstrConsistent (TyVar x, u) :: c when is_bvp_type u ->
        unify @@ ConstrEqual (TyVar x, u) :: c
    | ConstrConsistent (TyVar x, TyFun (u1, u2)) :: c when not @@ Variables.mem x @@ tyvars (TyFun (u1, u2)) ->
        let x1, x2 = fresh_tyvar (), fresh_tyvar () in
        unify @@ ConstrEqual (TyVar x, TyFun (x1, x2)) :: ConstrConsistent (x1, u1) :: ConstrConsistent (x2, u2) :: c
    | ConstrEqual (t1, t2) :: c when t1 = t2 && is_static_type t1 && is_bvp_type t1 ->
        unify c
    | ConstrEqual (TyFun (t11, t12), TyFun (t21, t22)) :: c when is_static_type t11 && is_static_type t12 && is_static_type t21 && is_static_type t22 ->
        unify @@ ConstrEqual (t11, t21) :: ConstrEqual (t12, t22) :: c
    | ConstrEqual (t, TyVar x) :: c when is_static_type t && not (is_tyvar t) ->
        unify @@ ConstrEqual (TyVar x, t) :: c
    | ConstrEqual (TyVar x, t) :: c when not @@ Variables.mem x @@ tyvars t ->
        let s = unify @@ subst_type_constraints x t c in
        (x, t) :: s
    | c :: _ ->
        raise @@ Type_error ("cannot unify: " ^ (string_of_constr c))
  in
  unify @@ map_constraints (fun x -> x) c

let type_of_exp env e =
  let u, c = generate_constraints env e in
  let s = unify c in
  let t = subst_type_substitutions u s in
  subst_tyvars t
