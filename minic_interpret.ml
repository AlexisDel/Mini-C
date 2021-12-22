(*

en entrée : un prog avec liste de variables globale et liste de déclaration de fonctions

étape 1 : créer un environnement de variables globales.

*)

open Minic_ast


exception ExcepSkip

type env = (string, int) Hashtbl.t

type result = I of int | B of bool | S of string | N


(*évaluation d'une expression :*)

let rec for_func genv fenv lenv stop s =
  let b = eval_code stop genv fenv lenv in
  if b = B(true) then let genv', fenv', lenv', res, flag = exec_function_code s genv fenv lenv in
    begin
      if flag then genv', fenv', lenv', res, flag else for_func genv' fenv' lenv' stop s
    end
  else genv, fenv, lenv, N, false

and eval_expr e genv fenv=
	match e with
	  | Cst n -> I(n)
    | BCst b -> if b then B(true) else B(false)
    | Str s -> S(s)
    | Get x -> Hashtbl.find genv x
    | Add(e1, e2) ->
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      begin
      match v1, v2 with
        |I(v1), I(v2) -> I(v1 + v2)
        |_, _ -> failwith "type error 1"
      end
    | Mul(e1, e2) ->
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      begin
      match v1, v2 with
        |I(v1), I(v2) -> I(v1 * v2)
        |_, _ -> failwith "type error 2"
      end
    | Lt(e1, e2) ->
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      begin
      match v1, v2 with
        |I(v1), I(v2) -> B(v1 < v2)
        |_, _ -> failwith "type error 3"
      end
    | Eg(e1, e2) -> let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      B(v1 = v2)
    | And(e1, e2) -> 
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      begin
        match v1, v2 with
          |B(v1), B(v2) -> B(v1 && v2)
          |_, _ -> failwith "type error,4"
      end
    | Or(e1, e2) -> 
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      begin
        match v1, v2 with
          |B(v1), B(v2) -> B(v1 || v2)
          |_, _ -> failwith "type error 5"
      end
    | Not(e1) -> 
      let v1 = eval_expr e1 genv fenv in
      begin
        match v1 with
          |B(v1) -> B(not v1)
          |_ -> failwith "type error 6"
      end
    | Null(_) -> N  (*not initialised variable*)
    | Call(f, p) -> let local_fun_env = Hashtbl.create 100 in (*création d'un environnement local à la fonction*)
                    try List.iter2 (fun x y -> let pvalue = eval_expr x genv fenv in Hashtbl.add local_fun_env (fst y) pvalue ) p (Hashtbl.find fenv f).params; (*association arguments valeurs*)
                    List.iter (fun (x,_,e) -> Hashtbl.add local_fun_env x (eval_expr e genv fenv)) (Hashtbl.find fenv f).locals; (*ajout des variables locales à l'environnement local*)
                    let _, _, _, e, b = exec_function_code (Hashtbl.find fenv f).code genv fenv [local_fun_env] in if b then e else if (Hashtbl.find fenv f).return = Void then N
                    else failwith "error calculation function value" (*calcul du code de la fonction*)
                    with Invalid_argument(_) -> failwith ("wrong arguments in function " ^ f) 
                    | Not_found -> failwith "Error function name"
and exec_code i genv fenv lenv= 
  match i with
    | Set(x, e) ->
      let v = eval_code e genv fenv lenv in
      let tmp = try List.find (fun env -> try let _ = Hashtbl.find env x in true with Not_found -> false) lenv with Not_found -> genv in
      Hashtbl.replace tmp x v; genv, fenv, lenv, N, false
    | If(e, b1, b2) ->
      let v = eval_code e genv fenv lenv in
      if v = B(true)
      then exec_function_code b1 genv fenv lenv
      else let tmp = try exec_function_code b2 genv fenv lenv with ExcepSkip -> genv, fenv, lenv, N, false in tmp
    | While(e, b) ->
      begin
        try 
          begin 
            let v = eval_code e genv fenv lenv in
            if v = B(false) then genv, fenv, lenv, N, false
            else let genv', fenv, lenv, e, b = exec_function_code b genv fenv lenv in
                 if b then genv', fenv, lenv, e, b else exec_code i genv' fenv lenv
          end
        with
          | ExcepSkip ->  let genv', fenv, lenv, e, b = exec_code (While (e, b)) genv fenv lenv in
                              if b then genv', fenv, lenv, e, b else exec_code i genv' fenv lenv
          | _ -> failwith "unknown exception"
      end
    | For(v,e,s) -> let x_v, _, e_v = v in
                    let env_for = Hashtbl.create 100 in
                    let () = Hashtbl.add env_for x_v (eval_code e_v genv fenv lenv) in
                    for_func genv fenv (env_for::lenv) e s
    | Skip -> raise ExcepSkip
    | Putchar(e) -> let tmp = eval_code e genv fenv lenv in
                    begin
                    match tmp with
                      |I(tmp) ->print_int tmp;print_string "\n"; genv, fenv, lenv, N, false
                      |B(tmp) ->if tmp then print_string "true" else print_string "false";print_string "\n"; genv, fenv, lenv, N, false
                      |S(tmp) -> print_string tmp; print_string "\n"; genv, fenv, lenv, N, false
                      |N -> print_string "null"; print_string "\n"; genv, fenv, lenv, N, false
                    end
    | Return(e) -> let tmp = eval_code e genv fenv lenv in genv, fenv, lenv, tmp, true
    | Expr(e) -> let tmp = eval_code e genv fenv lenv in genv, fenv, lenv, tmp, false

and exec_function_code b genv fenv lenv= 
  match b with
      | [] -> genv, fenv, lenv, N, false
      | i :: b' -> let genv', fenv, lenv, e, b = exec_code i genv fenv lenv in
                   if b then genv', fenv, lenv, e, b else exec_function_code b' genv' fenv lenv
and eval_code e genv fenv lenv=
  match e with
    | Cst n -> I(n)
    | BCst b -> if b then B(true) else B(false)
    | Str s -> S(s)
    | Get x -> let tmp = try List.find (fun env -> try let _ = Hashtbl.find env x in true with Not_found -> false) lenv with Not_found -> genv in
               let tmp = try Hashtbl.find tmp x with Not_found -> failwith ("unknown variable "^x) in tmp
    | Add(e1, e2) -> 
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      begin
      match v1, v2 with
        |I(v1), I(v2) -> I(v1 + v2)
        |_, _ -> failwith "type error 7"
      end
    | Mul(e1, e2) ->
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      begin
      match v1, v2 with
        |I(v1), I(v2) -> I(v1 * v2)
        |_, _ -> failwith "type error 8"
      end
    | Lt(e1, e2) ->
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      begin
      match v1, v2 with
        |I(v1), I(v2) -> B(v1 < v2)
        |_, _ -> failwith "type error 9"
      end
    | Eg(e1, e2) -> 
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      B(v1 = v2)
    | And(e1, e2) -> 
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      begin
      match v1, v2 with
        |B(v1), B(v2) -> B(v1 && v2)
        |_, _ -> failwith "type error 10"
      end
    | Or(e1, e2) -> 
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      begin
      match v1, v2 with
        |B(v1), B(v2) -> B(v1 || v2)
        |_, _ -> failwith "type error 11"
      end
    | Not(e1) -> 
      let v1 = eval_code e1 genv fenv lenv in
      begin
      match v1 with
        |B(v1) -> B(not v1)
        |_ -> failwith "type error 12"
      end
    | Null(_) -> N  (*not initialised variable*)
    | Call(f, p) -> let local_fun_env = Hashtbl.create 100 in (*création d'un environnement local à la fonction*)
                    try List.iter2 (fun x y -> let pvalue = eval_code x genv fenv lenv in Hashtbl.add local_fun_env (fst y) pvalue ) p (Hashtbl.find fenv f).params; (*association arguments valeurs*)
                    List.iter (fun (x,_,e) -> Hashtbl.add local_fun_env x (eval_code e genv fenv lenv)) (Hashtbl.find fenv f).locals; (*ajout des variables locales à l'environnement local*)
                    let _, _, _, e, b = exec_function_code (Hashtbl.find fenv f).code genv fenv (local_fun_env::lenv) in if b then e else if (Hashtbl.find fenv f).return = Void then N
                    else failwith "error calculation function value" (*calcul du code de la fonction*)
                    with Invalid_argument(_) -> failwith ("wrong arguments in function " ^ f) 
                    | Not_found -> failwith "Error function name"

(*****************************************************)
(*évaluation des instruction et listes d'instructions*)
and execinstr i genv fenv = 
  match i with
    | Set(x, e) ->
      let v = eval_expr e genv fenv in
      let () = Hashtbl.replace genv x v in 
      genv, fenv
    | If(e, b1, b2) ->
      let v = eval_expr e genv fenv in
      if v = B(true)
      then execseq b1 genv fenv
      else let tmp = try execseq b2 genv fenv  with ExcepSkip -> genv, fenv in tmp
    | While(e, b) ->
      begin
        try 
          begin 
            let v = eval_expr e genv fenv in
            if v = B(false) then genv, fenv
            else let genv', fenv = execseq b genv fenv in
                 execinstr i genv' fenv
          end
        with
          | ExcepSkip ->  let genv', fenv = execinstr (While (e, b)) genv fenv in
                              execinstr i genv' fenv
          | _ -> failwith "unknown exception"
      end
    | For(v,e,s) -> let genv, fenv, _, _, _ = exec_function_code ([For(v, e, s)]) genv fenv [] in
                    genv, fenv
    | Skip -> raise ExcepSkip
    | Putchar(e) -> let tmp = eval_expr e genv fenv in
                    begin
                    match tmp with
                      |I(tmp) ->print_int tmp; print_string "\n"; genv, fenv
                      |B(tmp) ->if tmp then print_string "true" else print_string "false";print_string "\n"; genv, fenv
                      |S(tmp) -> print_string tmp;print_string "\n"; genv, fenv
                      |N -> print_string "null";print_string "\n"; genv, fenv
                    end
    | Return(e) -> let _ = eval_expr e genv fenv in genv, fenv
    | Expr(e) ->let _ = eval_expr e genv fenv in genv, fenv

and execseq b genv fenv= 
	match b with
      | [] -> genv, fenv
      | i :: b' -> let genv', fenv = execinstr i genv fenv in
                   execseq b' genv' fenv



let interpret prog =

  (*environnement global*)
  let global_env = Hashtbl.create 100 in
  (*//////////////////////////////*)
  (*ajout des variables globales :*)
  let rec add_globals g genv fenv = 
    match g with
      |[] -> genv
      |(id, _, ex)::s -> Hashtbl.add genv id (eval_expr ex genv fenv);
                       add_globals s genv fenv
  in
  
  (*///////////////////////////*)
  (*environnement des fonctions*)
  let function_env = Hashtbl.create 100 in

  (*ajout des fonctions :*)
  let rec add_functions f genv fenv=
    match f with
      |[] -> fenv
      |fundef::s -> Hashtbl.add fenv fundef.name fundef; add_functions s genv fenv
  in

  (*///////////////////////////////////*)
  (*initialisation des environnements :*)
  let global_env = add_globals prog.globals global_env function_env in
  let function_env = add_functions prog.functions global_env function_env in

  (*interpretatin du main*)

  let interpret_main main genv fenv=
    match main with
      |[main] ->  List.iter (fun (x,_,e) -> Hashtbl.add genv x (eval_expr e genv fenv)) main.locals; (*ajout des variables locales à la fonction main à l'environnement global*)
                  execseq main.code genv fenv
      |_ -> failwith "error in main interpretation"
  in
  let _, _ = interpret_main prog.main global_env function_env in
  print_string ""
  (*Hashtbl.iter (fun s e -> print_string s; print_string " : "; print_int e; print_string " ") global_env; print_string "\n"*)
