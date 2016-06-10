open Printf

(* Types *)

type typaram = int
type tyvar = int

type ty =
  | TyParam of typaram
  | TyVar of tyvar
  | TyBool
  | TyInt
  | TyFun of ty * ty
  | TyDyn

let rec string_of_type = function
  | TyParam a -> "a" ^ string_of_int a
  | TyVar x -> "x" ^ string_of_int x
  | TyBool -> "bool"
  | TyInt -> "int"
  | TyFun (t1, t2) -> sprintf "(%s -> %s)" (string_of_type t1) (string_of_type t2)
  | TyDyn -> "?"

(*
let match_function t = match t with
| TyFun _ -> t
| TyDyn -> TyFun (TyDyn, TyDyn)
| _ -> raise @@ Type_error ("cannot match function: %s" ^ string_of_type t)

let rec check_consistency s t = match s, t with
| (s, t) when s = t -> true
| (_, TyDyn) | (TyDyn, _) -> true
| (TyFun (s1, t1), TyFun (s2, t2)) ->
    check_consistency s1 s2 && check_consistency t1 t2
| _ -> false
*)


(* Syntax *)

type id = string

type const =
  | ConstBool of bool
  | ConstInt of int

let string_of_const = function
  | ConstBool b -> string_of_bool b
  | ConstInt i -> string_of_int i

type binop = Plus

type exp =
  | Var of id
  | Const of const
  | BinOp of binop * exp * exp
  | FunI of id * exp
  | FunE of id * ty * exp
  | App of exp * exp

let rec string_of_exp = function
  | Var id -> id
  | Const c -> string_of_const c
  | BinOp (op, e1, e2) ->
      sprintf "%s + %s" (string_of_exp e1) (string_of_exp e2)
  | FunI (x, e) -> sprintf "λ%s.%s" x (string_of_exp e)
  | FunE (x, x_t, e) -> sprintf "λ%s:%s.%s" x (string_of_type x_t) (string_of_exp e)
  | App (x, y) -> sprintf "(%s %s)" (string_of_exp x) (string_of_exp y)

