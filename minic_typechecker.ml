open Minic_ast
(* Pour représenter les environnements associant chaque variable à son type. *)
module Env = Map.Make(String)

(* Vérification du bon typage d'un programme. *)
let typecheck_program (prog: prog) =
  (* L'environnement global mémorise le type de chaque variable globale. *)
  let global_env =
    List.fold_left (fun env (x, ty, e) -> Env.add x (ty, e) env) Env.empty prog.globals
  in

  (* Vérification du bon typage et calcul du type d'une expression.
       À nouveau, fonction locale avec accès à tout ce qui est au-dessus. *)
  let rec type_expr local_env = function
    | Null(v) -> let ty, _ = try Env.find v local_env with Not_found -> Env.find v global_env in ty
    | Cst _ -> Int
    | BCst _ -> Bool
    | Add(e1,e2) -> if(type_expr local_env e1 = Int && type_expr local_env e2 = Int) then Int else failwith "type error"
    | Mul(e1,e2) -> if(type_expr local_env e1 = Int && type_expr local_env e2 = Int) then Int else failwith "type error"
    | Lt(e1,e2) -> if(type_expr local_env e1 = Int && type_expr local_env e2 = Int) then Bool else failwith "type error"
    | Get(v) -> let ty, e = try Env.find v local_env with Not_found -> Env.find v global_env in 
                    if ty = type_expr local_env e then ty else failwith "type error"
    | Call(f,p) -> let fu = List.find (fun x -> x.name = f) (prog.functions) in
                   List.iter2 (fun e p -> if type_expr local_env e <> (snd p) then failwith "params type error") p (fu.params);
                   fu.return
  
  in

  let typecheck_variable_global var = 
    let _, ty, e = var in
    if ty <> type_expr Env.empty e then failwith "type error"
  in


  (* Vérification du bon typage d'une fonction.
     C'est une fonction locale : on a accès à [prog] et à [global_env]. *)
  let typecheck_function (fdef: fun_def) =
    
    (* On devrait ici avoir également un environnement local.
       À COMPLÉTER
     *)
    let params_env =
      List.fold_left (fun env (x, ty) -> Env.add x (ty, Null(x)) env) Env.empty fdef.params
    in
    let local_env = 
      List.fold_left (fun env (x, ty, e) -> Env.add x (ty, e) env) params_env fdef.locals
    in


    let typecheck_variable_local var =  
      let _, ty, e = var in
      if ty <> type_expr local_env e then failwith "type error"
    in

    let not_found x env =
      
      let rec common_letters s1 s2 = match s1, s2 with 
        | [] , _ -> 0
        | _ , [] -> 0
        | h1::t1, h2::t2 -> 
            if (Char.equal h1 h2) then 1 + common_letters t1 t2
            else common_letters t1 t2
      in

      let to_list s =
        let rec exp i l =
          if i < 0 then l else exp (i - 1) (s.[i] :: l) in
        exp (String.length s - 1) []
      in

      let best = List.fold_left (fun acc (k,v) -> if (common_letters (to_list x) (to_list k)) > ((String.length x) - 2) then k else acc) "" (Env.bindings env) in
      if best = "" then (x^" : Unboud Value")
      else ("Did you mean '"^best^"' ?")
    in

    (* Vérification du bon typage d'une instruction ou d'une séquence.
       Toujours local. *)
    let rec typecheck_instr local_env = function
      | Skip -> ()
      | Putchar(e) -> if type_expr local_env e <> Int then failwith "type error"
      | Set(v,e) -> let ty, _ = try Env.find v local_env with Not_found -> try Env.find v global_env with Not_found -> failwith (not_found v local_env) in
                    if ty <> type_expr local_env e then failwith "type error"
      | If(e,s1,s2) -> if type_expr local_env e <> Bool then failwith "type error"
                       else
                        List.iter (typecheck_instr local_env) s1;
                        List.iter (typecheck_instr local_env) s2
      | While(e,s) -> if type_expr local_env e <> Bool then failwith "type error"
                      else
                        List.iter (typecheck_instr local_env) s;
      | For(v,e,s) -> let x_v, ty_v, e_v = v in
                      let local_env = Env.add x_v (ty_v, e_v) local_env in
                      if type_expr local_env e <> Bool then failwith "type error"
                      else
                        List.iter (typecheck_instr local_env) s;                  
      (* Cas d'une instruction [return]. On vérifie que le type correspond au
         type de retour attendu par la fonction dans laquelle on se trouve. *)
      | Return(e) -> let t = type_expr local_env e in
                     if t <> fdef.return then
                       failwith "type error"
      | Expr(e) ->  let _ = type_expr local_env e in ()
      (* À COMPLÉTER *)
                   
    and typecheck_seq f s =
      List.iter f s        
    in

    (* Code principal du typage d'une fonction : on type ses instructions. *)
    typecheck_seq typecheck_variable_local (fdef.locals);
    typecheck_seq (typecheck_instr local_env) (fdef.code);
  in

  (* Code principal du typage d'un programme : on type ses fonctions.
     Il faudrait aussi vérifier les valeurs initiales des variables globales.
     À COMPLÉTER
   *)
  List.iter typecheck_function (prog.functions);
  List.iter typecheck_variable_global (prog.globals)
;;
