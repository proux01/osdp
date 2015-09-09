(*
 * OSDP (OCaml SDP) is an OCaml frontend library to semi-definite
 * programming (SDP) solvers.
 * Copyright (C) 2012, 2014  P. Roux and P.L. Garoche
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

module type S = sig
  module Poly : Polynomial.S
  type var
  type polynomial_expr =
    | Const of Poly.t
    | Var of var
    | Mult_scalar of Poly.Coeff.t * polynomial_expr
    | Add of polynomial_expr * polynomial_expr
    | Sub of polynomial_expr * polynomial_expr
    | Mult of polynomial_expr * polynomial_expr
    | Power of polynomial_expr * int
    | Compose of polynomial_expr * polynomial_expr list
    | Derive of polynomial_expr * int
  val var : string -> polynomial_expr
  val var_poly : string -> int -> ?homogen:bool -> int ->
                 polynomial_expr * (Monomial.t * polynomial_expr) list
  val const : Poly.t -> polynomial_expr
  val mult_scalar : Poly.Coeff.t -> polynomial_expr -> polynomial_expr
  val add : polynomial_expr -> polynomial_expr -> polynomial_expr
  val sub : polynomial_expr -> polynomial_expr -> polynomial_expr
  val mult : polynomial_expr -> polynomial_expr -> polynomial_expr
  val power : polynomial_expr -> int -> polynomial_expr
  val compose : polynomial_expr -> polynomial_expr list -> polynomial_expr
  val derive : polynomial_expr -> int -> polynomial_expr
  val ( !! ) : Poly.t -> polynomial_expr
  val ( ?? ) : int -> polynomial_expr
  val ( ! ) : Poly.Coeff.t -> polynomial_expr
  val ( *. ) : Poly.Coeff.t -> polynomial_expr -> polynomial_expr
  val ( ~- ) : polynomial_expr -> polynomial_expr
  val ( + ) : polynomial_expr -> polynomial_expr -> polynomial_expr
  val ( - ) : polynomial_expr -> polynomial_expr -> polynomial_expr
  val ( * ) : polynomial_expr -> polynomial_expr -> polynomial_expr
  val ( / ) : polynomial_expr -> Poly.Coeff.t -> polynomial_expr
  val ( /. ) : Poly.Coeff.t -> Poly.Coeff.t -> polynomial_expr
  val ( ** ) : polynomial_expr -> int -> polynomial_expr
  val ( >= ) : polynomial_expr -> polynomial_expr -> polynomial_expr
  val ( <= ) : polynomial_expr -> polynomial_expr -> polynomial_expr
  type options = {
    sdp : Sdp.options
  }
  val default : options
  type obj =
      Minimize of polynomial_expr | Maximize of polynomial_expr | Purefeas
  type values
  type witness = Monomial.t array * float array array
  exception Dimension_error
  exception Not_linear
  val solve : ?options:options -> ?solver:Sdp.solver ->
              obj -> polynomial_expr list ->
              SdpRet.t * (float * float) * values * witness list
  val value : polynomial_expr -> values -> Poly.Coeff.t
  val value_poly : polynomial_expr -> values -> Poly.t
  val check : polynomial_expr -> ?values:values -> witness -> bool
  val pp : Format.formatter -> polynomial_expr -> unit
  val pp_names : string list -> Format.formatter -> polynomial_expr -> unit
end

module Make (P : Polynomial.S) : S with module Poly = P = struct
  module Poly = P
  module S = Poly.Coeff

  type polynomial_var = {
    name : Ident.t;
    poly : (Monomial.t * Ident.t) list }

  type var = Vscalar of Ident.t | Vpoly of polynomial_var

  type polynomial_expr =
    | Const of Poly.t
    | Var of var
    | Mult_scalar of Poly.Coeff.t * polynomial_expr
    | Add of polynomial_expr * polynomial_expr
    | Sub of polynomial_expr * polynomial_expr
    | Mult of polynomial_expr * polynomial_expr
    | Power of polynomial_expr * int
    | Compose of polynomial_expr * polynomial_expr list
    | Derive of polynomial_expr * int

  let var s = Var (Vscalar (Ident.create s))

  let var_poly s n ?homogen d =
    let homogen = match homogen with Some h -> h | None -> false in
    let name = Ident.create s in
    let l =
      let mons = (if homogen then Monomial.list_eq else Monomial.list_le) n d in
      let s = (*"__SOS__" ^*) Format.asprintf "%a" Ident.pp name ^ "_" in
      List.mapi (fun i m -> m, Ident.create (s ^ string_of_int i)) mons in
    Var (Vpoly { name = name; poly = l }),
    List.map (fun (m, id) -> m, Var (Vscalar id)) l

  let const p = Const p
  let mult_scalar c e = Mult_scalar (c, e)
  let add e1 e2 = Add (e1, e2)
  let sub e1 e2 = Sub (e1, e2)
  let mult e1 e2 = Mult (e1, e2)
  let power e d = Power (e, d)
  let compose e l = Compose (e, l)
  let derive e i = Derive (e, i)
        
  let pp_names names fmt e =
    let rec pp_prior prior fmt = function
      | Const p ->
         let par =
           2 < prior || 0 < prior && List.length (Poly.to_list p) >= 2 in
         Format.fprintf fmt (if par then "(%a)" else "%a")
                        (Poly.pp_names names) p
      | Var (Vscalar id) -> Ident.pp fmt id
      | Var (Vpoly p) -> Ident.pp fmt p.name
      | Mult_scalar (n, e) -> Format.fprintf fmt
         (if 1 < prior then "(@[%a@ * %a@])" else "@[%a@ * %a@]")
         S.pp n (pp_prior 1) e
      | Add (e1, e2) -> Format.fprintf fmt
         (if 0 < prior then "(@[%a@ + %a@])" else "@[%a@ + %a@]")
         (pp_prior 0) e1 (pp_prior 0) e2
      | Sub (e1, e2) -> Format.fprintf fmt
         (if 0 < prior then "(@[%a@ - %a@])" else "@[%a@ - %a@]")
         (pp_prior 0) e1 (pp_prior 1) e2
      | Mult (e1, e2) -> Format.fprintf fmt
         (if 1 < prior then "(@[%a@ * %a@])" else "@[%a@ * %a@]")
         (pp_prior 1) e1 (pp_prior 1) e2
      | Power (e, d) -> Format.fprintf fmt "%a^%i" (pp_prior 3) e d
      | Compose (e, el) ->
         Format.fprintf fmt "%a(@[%a@])" (pp_prior 2) e
                        (Utils.pp_list ~sep:",@ " (pp_prior 0)) el
      | Derive (e, i) ->
         let m = Array.to_list (Array.make i 0) @ [1] in
         Format.fprintf fmt "d/d%a(%a)"
                        (Monomial.pp_names names) (Monomial.of_list m)
                        (pp_prior 0) e in
    pp_prior 0 fmt e

  let pp = pp_names []

  (*************)
  (* Scalarize *)
  (*************)

  module LinExprSC = LinExpr.Make (Poly.Coeff)

  (* polynomials whose coefficients are linear expressions *)
  module LEPoly = Polynomial.Make (LinExpr.MakeScalar (LinExprSC))

  exception Dimension_error
  exception Not_linear

  (* Compile each polynomial_expr as a LEPoly.t. *)
  let scalarize (el : polynomial_expr list) : LEPoly.t list =

    let rec scalarize = function
      | Const p ->
         Poly.to_list p
         |> List.map (fun (m, c) -> m, LinExprSC.const c)
         |> LEPoly.of_list
      | Var (Vscalar id) -> LEPoly.mult_scalar (LinExprSC.var id) LEPoly.one
      | Var (Vpoly p) ->
         List.map (fun (m, id) -> m, LinExprSC.var id) p.poly
         |> LEPoly.of_list
      | Mult_scalar (n, e) ->
         let le = LinExprSC.const n in
         LEPoly.mult_scalar le (scalarize e)
      | Add (e1, e2) -> LEPoly.add (scalarize e1) (scalarize e2)
      | Sub (e1, e2) -> LEPoly.sub (scalarize e1) (scalarize e2)
      | Mult (e1, e2) -> LEPoly.mult (scalarize e1) (scalarize e2)
      | Power (e, d) -> LEPoly.power (scalarize e) d
      | Compose (e, el) ->
         LEPoly.compose (scalarize e) (List.map scalarize el)
      | Derive (e, i) -> LEPoly.derive (scalarize e) i in

    try List.map scalarize el
    with
    | LEPoly.Dimension_error -> raise Dimension_error
    | LinExpr.Not_linear -> raise Not_linear

  (*********)
  (* Solve *)
  (*********)

  type options = {
    sdp : Sdp.options
  }

  let default = { sdp = Sdp.default }

  type obj =
      Minimize of polynomial_expr | Maximize of polynomial_expr | Purefeas

  type values = S.t Ident.Map.t

  type witness = Monomial.t array * float array array

  let solve ?options ?solver obj el =
    let sdp_options = match options with None -> None | Some o -> Some o.sdp in

    let obj, obj_sign = match obj with
      | Minimize obj -> Mult_scalar (S.of_float (-1.), obj), -1.
      | Maximize obj -> obj, 1.
      | Purefeas -> Const (Poly.zero), 0. in

    (* associate an index to each (scalar) variable *)
    let var_idx, _ =
      let rec collect env = function
        | Const p -> env
        | Var (Vscalar id) -> Ident.Set.add id env
        | Var (Vpoly { name = _; poly = l }) ->
           List.fold_left (fun env (_, id) -> Ident.Set.add id env) env l
        | Mult_scalar (_, e) | Power (e, _) -> collect env e
        | Add (e1, e2) | Sub (e1, e2) | Mult (e1, e2) ->
           collect (collect env e1) e2
        | Compose (e, el) -> List.fold_left collect (collect env e) el
        | Derive (e, _) -> collect env e in
      let env = List.fold_left collect Ident.Set.empty (obj :: el) in
      Ident.Set.fold
        (fun id (m, i) -> Ident.Map.add id i m, i + 1)
        env (Ident.Map.empty, 0) in

    let obj, scalarized = match scalarize (obj :: el) with
      | [] -> assert false
      | obj :: scalarized -> obj, scalarized in

    (* build the objective (see sdp.mli) *)
    let obj, obj_cst = match LEPoly.to_list obj with
      | [] -> ([], []), 0.
      | [m, c] when Monomial.to_list m = [] ->
         let le, c = LinExprSC.to_list c in
         let v = List.map (fun (id, c) -> Ident.Map.find id var_idx, c) le in
         (v, []), S.to_float c
      | _ -> raise Not_linear in

    (* associate a monomial basis to each SOS constraint *)
    let monoms_scalarized =
      let build_monoms e =
        let monoms_e = List.map fst (LEPoly.to_list e) in
        let l =
          let h = LEPoly.is_homogeneous e in
          let n = LEPoly.nb_vars e in
          let d = (LEPoly.degree e + 1) / 2 in
          (if h then Monomial.list_eq else Monomial.list_le) n d in
        Monomial.filter_newton_polytope l monoms_e in
      List.map (fun e -> Array.of_list (build_monoms e), e) scalarized in

    (* build the a_i, A_i and b_i (see sdp.mli) *)
    let build_cstr ei (monoms, e) =
      (* for monoms = [m_0;...; m_n], square_monoms associates to each
         monom m the list of all i >= j such that m = m_i *
         m_j. square_monoms is sorted by Monomial.compare. *)
      let square_monoms =
        let sz = Array.length monoms in
        let m = ref Monomial.Map.empty in
        for i = 0 to sz - 1 do
          for j = 0 to i do
            let mij = Monomial.mult monoms.(i) monoms.(j) in
            let lm = try Monomial.Map.find mij !m with Not_found -> [] in
            m := Monomial.Map.add mij ((i, j) :: lm) !m
          done
        done;
        Monomial.Map.bindings !m in

      (* collect the constraints by equating coefficients (linear
         expressions) of polynomials corresponding to the same
         monomial *)
      let constraints =
        let le_zero = LinExprSC.const S.zero in
        let rec match_polys l p1 p2 = match p1, p2 with
          | [], [] -> l
          | [], (_, c2) :: t2 -> match_polys ((le_zero, c2) :: l) [] t2
          | (_, c1) :: t1, [] -> match_polys ((c1, []) :: l) t1 []
          | (m1, c1) :: t1, (m2, c2) :: t2 ->
             let cmp =  Monomial.compare m1 m2 in
             if cmp = 0 then match_polys ((c1, c2) :: l) t1 t2
             else if cmp > 0 then match_polys ((le_zero, c2) :: l) p1 t2
             else (* cmp < 0 *) match_polys ((c1, []) :: l) t1 p2 in
        match_polys [] (LEPoly.to_list e) square_monoms in

      (* encode the constraints for solve_ext (c.f., sdp.mli) *)
      let constraints =
        List.rev_map
          (fun (le, lij) ->
           let le, b = LinExprSC.to_list le in
           let vect =
             List.map
               (fun (id, c) ->
                Ident.Map.find id var_idx, S.sub S.zero c)
               le in
           let mat = [ei, List.map (fun (i, j) -> i, j, 1.) lij] in
           (vect, mat), b)
          constraints in
      monoms, constraints in

    let monoms_cstrs = List.mapi build_cstr monoms_scalarized in

    (* pad constraints *)
    (* The solver will return X >= 0 such that tr(A_i X) = b_i + perr
       where perr is bounded by the primal feasibility error stop
       criteria of the solver. In the check function below (c.f. its
       spec in the mli), we will need \lambda_min(X) >= n perr. That's
       why we perform the change of variable X' := X - n perr I. *)
    let paddings, cstrs =
      let perr = if false then 0. else
        let bl = List.map (fun (_, c) -> List.map snd c) monoms_cstrs
                 |> List.flatten |> List.map S.to_float in
        Sdp.pfeas_stop_crit ?options:sdp_options ?solver bl in
      Format.printf "perr = %g@." perr;
      let pad_cstrs (monoms, constraints) =
        let pad = 2. *. float_of_int (Array.length monoms) *. perr in
        let has_diag mat =
          let diag (i, j, _) = i = j in
          List.exists (fun (_, m) -> List.exists diag m) mat in
        pad,
        List.map
          (fun ((vect, mat), b) ->
           (* there is at most one diagonal coefficient in mat *)
           let b = if has_diag mat then S.sub b (S.of_float pad) else b in
           vect, mat, b, b)
          constraints in
      List.split (List.map pad_cstrs monoms_cstrs) in
    let cstrs = List.flatten cstrs in

    (* Format.printf "SDP solved <@."; *)
    (* Format.printf "%a@." Sdp.pp_ext_sparse (obj, cstrs, []); *)
    (* Format.printf ">@."; *)

    (* call SDP solver *)
    let module PreSdp = PreSdp.Make (S) in
    let ret, (pobj, dobj), (res_x, res_X, _, _) =
      PreSdp.solve_ext_sparse ?options:sdp_options ?solver obj cstrs [] in

    let obj = let f o = obj_sign *. (o +. obj_cst) in f pobj, f dobj in

    (* rebuild variables *)
    if not (SdpRet.is_success ret) then
      ret, obj, Ident.Map.empty, []
    else
      let vars =
        let a = Array.of_list res_x in
        Ident.Map.map (fun i -> snd a.(i)) var_idx in
      let witnesses =
        List.combine (List.map fst monoms_cstrs) (List.map snd res_X) in
      (* unpad result *)
      List.iter2
        (fun pad (_, q) ->
         let sz = Array.length q in
         for i = 0 to sz - 1 do q.(i).(i) <- q.(i).(i) +. pad done)
        paddings witnesses;
      ret, obj, vars, witnesses

  let value_poly e m =
    let rec aux = function
      | Const p -> p
      | Var (Vscalar id) -> Poly.const (Ident.Map.find id m)
      | Var (Vpoly p) ->
         List.map (fun (mon, id) -> mon, Ident.Map.find id m) p.poly
         |> Poly.of_list
      | Mult_scalar (c, e) -> Poly.mult_scalar c (aux e)
      | Add (e1, e2) -> Poly.add (aux e1) (aux e2)
      | Sub (e1, e2) -> Poly.sub (aux e1) (aux e2)
      | Mult (e1, e2) -> Poly.mult (aux e1) (aux e2)
      | Power (e, d) -> Poly.power (aux e) d
      | Compose (e, el) -> Poly.compose (aux e) (List.map aux el)
      | Derive (e, i) -> Poly.derive (aux e) i in
    aux e

  let value e m =
    match Poly.is_const (value_poly e m) with
    | None -> raise Dimension_error
    | Some c -> c

  let check e ?values:values (v, q) =
    let values = match values with Some v -> v | None -> Ident.Map.empty in
    let module PQ = Polynomial.Q in let module M = Monomial in
    (* first compute (exactly, using Q) a polynomial p from
       polynomial_expr e *)
    let rec scalarize = function
      | Const p ->
         Poly.to_list p
         |> List.map (fun (m, c) -> m, Poly.Coeff.to_q c)
         |> PQ.of_list
      | Var (Vscalar id) ->
         PQ.const (Poly.Coeff.to_q (Ident.Map.find id values))
      | Var (Vpoly p) ->
         List.map (fun (m, id) -> m, Ident.Map.find id values) p.poly
         |> List.map (fun (m, c) -> m, Poly.Coeff.to_q c)
         |> PQ.of_list
      | Mult_scalar (c, e) ->
         PQ.mult_scalar (Poly.Coeff.to_q c) (scalarize e)
      | Add (e1, e2) -> PQ.add (scalarize e1) (scalarize e2)
      | Sub (e1, e2) -> PQ.sub (scalarize e1) (scalarize e2)
      | Mult (e1, e2) -> PQ.mult (scalarize e1) (scalarize e2)
      | Power (e, d) -> PQ.power (scalarize e) d
      | Compose (e, el) ->
         PQ.compose (scalarize e) (List.map scalarize el)
      | Derive (e, i) -> PQ.derive (scalarize e) i in
    let p = scalarize e in
    (* then check that p can be expressed in monomial base v *)
    let check_base =
      let s = ref M.Set.empty in
      let sz = Array.length v in
      for i = 0 to sz - 1 do
        for j = 0 to i do
          s := M.Set.add (M.mult v.(i) v.(j)) !s
        done
      done;
      List.for_all (fun (m, _) -> M.Set.mem m !s) (PQ.to_list p) in
    if not check_base then false else
      (* compute polynomial v^T q v *)
      let p' =
        let p' = ref [] in
        let sz = Array.length v in
        for i = 0 to sz - 1 do
          for j = 0 to sz - 1 do
            p' := (M.mult v.(i) v.(j), Scalar.Q.of_float q.(i).(j)) :: !p'
          done
        done;
        PQ.of_list !p' in
      (* compute the maximum difference between corresponding
         coefficients *)
      let rec cpt_diff p p' = match p, p' with
        | [], [] -> Scalar.Q.zero
        | [], (_, c) :: l | (_, c) :: l, [] -> Q.max (Q.abs c) (cpt_diff [] l)
        | (m, c) :: l, (m', c') :: l' ->
           let cmp = M.compare m m' in
           if cmp = 0 then Q.max (Q.abs (Q.sub c' c)) (cpt_diff l l')
           else if cmp < 0 then Q.max (Q.abs c) (cpt_diff l p')
           else (* cmp > 0 *) Q.max (Q.abs c') (cpt_diff p l') in
      let r = cpt_diff (PQ.to_list p) (PQ.to_list p') in
      Format.printf "r = %g@." (Utils.float_of_q r);
      (* Format.printf "Q = %a@." Matrix.Float.pp (Matrix.Float.of_array_array q); *)
      (* form the interval matrix q +/- r *)
      let qpmr =
        let itv f =
          let q = Q.of_float f in
          let l, _ = Utils.itv_float_of_q (Q.sub q r) in
          let _, u = Utils.itv_float_of_q (Q.add q r) in
          l, u in
        Array.map (Array.map itv) q in
      (* and check its positive definiteness *)
      let res = Posdef.check_itv qpmr in
      (* Format.printf "res = %B@." res; *)
      res

  (* function solve including a posteriori checking with check just
     above *)
  let solve ?options ?solver obj el =
    let ret, obj, vals, wits = solve ?options ?solver obj el in
    if not (SdpRet.is_success ret) then ret, obj, vals, wits else
      let check_repl e wit = check e ~values:vals wit in
      if List.for_all2 check_repl el wits then SdpRet.Success, obj, vals, wits
      else SdpRet.PartialSuccess, obj, vals, wits

  let ( !! ) = const
  let ( ?? ) i = const (Poly.( ?? ) i)
  let ( ! ) c = const (Poly.const c)
  let ( *. ) = mult_scalar
  let ( ~- ) = sub (const Poly.zero)
  let ( + ) = add
  let ( - ) = sub
  let ( * ) = mult
  let ( / ) e c = Mult_scalar (Poly.Coeff.(div one c), e)
  let ( /. ) c1 c2 = const (Poly.( /. ) c1 c2)
  let ( ** ) = power
  let ( >= ) e1 e2 = e1 - e2
  let ( <= ) e1 e2 = e2 - e1
end

module Float = Make (Polynomial.Float)
