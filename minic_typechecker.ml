open Minic_ast
open Auto_suggestion
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
    | Null(v) -> let ty, _ = try Env.find v local_env with Not_found -> try Env.find v global_env with Not_found -> 
                                  failwith (did_u_mean v (bindings_to_var_names (Env.bindings local_env) (Env.bindings global_env)) ) in ty
    | Cst _ -> Int
    | BCst _ -> Bool
    | Add(e1,e2) -> if(type_expr local_env e1 = Int && type_expr local_env e2 = Int) then Int else failwith "type error"
    | Mul(e1,e2) -> if(type_expr local_env e1 = Int && type_expr local_env e2 = Int) then Int else failwith "type error"
    | Lt(e1,e2) -> if(type_expr local_env e1 = Int && type_expr local_env e2 = Int) then Bool else failwith "type error"
    | Eg(e1, e2) -> let t1, t2 = type_expr local_env e1, type_expr local_env e2 in if t1=t2 then Bool else failwith "type error"
    | And(e1, e2) -> if(type_expr local_env e1 = Bool && type_expr local_env e2 = Bool) then Bool else failwith "type error"
    | Or(e1, e2) -> if(type_expr local_env e1 = Bool && type_expr local_env e2 = Bool) then Bool else failwith "type error"
    | Not(e1) -> if type_expr local_env e1 = Bool  then Bool else failwith "type error"
    | Get(v) -> let ty, e = try Env.find v local_env with Not_found -> try Env.find v global_env with Not_found -> 
                                failwith (did_u_mean v (bindings_to_var_names (Env.bindings local_env) (Env.bindings global_env)) ) in
                    if ty = type_expr local_env e then ty else failwith "type error"
    | Call(f,p) -> 
                  let fu = 
                          try List.find (fun x -> x.name = f) (prog.functions) with Not_found -> 
                            failwith (did_u_mean f (fun_def_to_fun_names (prog.functions) ) ) in
                  if List.length p > List.length (fu.params) then 
                    failwith (fu.name ^ "(" ^ (fun_def_to_arguments_as_string (fu.params)) ^ ") : too much arguments !")
                  else if List.length p < List.length (fu.params) then 
                    failwith (fu.name ^ "(" ^ (fun_def_to_arguments_as_string (fu.params)) ^ ") : missing arguments ?")
                  else
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

    (* Vérification du bon typage d'une instruction ou d'une séquence.
       Toujours local. *)
    let rec typecheck_instr local_env = function
      | Skip -> ()
      | Putchar(e) -> if type_expr local_env e <> Int then failwith "type error"
      | Set(v,e) -> let ty, _ = try Env.find v local_env with Not_found -> try Env.find v global_env with Not_found -> 
                                  failwith (did_u_mean v (bindings_to_var_names (Env.bindings local_env) (Env.bindings global_env)) ) in
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
  (*check si il est mention d'un return dans une liste d'instructions*)
  let rec return_in_list l =
    match l with
      |[] -> false
      |Return(_)::_ -> true
      |_::s -> return_in_list s
  in

  let typecheck_main f =
    match f with
      |[] -> failwith "undefined reference to \'main\'"
      |[f] -> if not (f.name = "main") || not (f.params = []) || not (f.return = Int) 
              then failwith "synthax error on main function" 
              else if not (return_in_list f.code) then failwith "no return reference occure in main function"
      |_ -> failwith "error too much function in program.main"
  in
  (* Code principal du typage d'un programme : on type ses fonctions.
     Il faudrait aussi vérifier les valeurs initiales des variables globales.
     À COMPLÉTER
   *)
  List.iter typecheck_function (prog.functions);
  List.iter typecheck_variable_global (prog.globals);
  typecheck_main (prog.main);
  List.iter typecheck_function (prog.main)
;;
