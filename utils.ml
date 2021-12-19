exception Not_close_match

let string_to_list s =
  let rec exp i l =
    if i < 0 then l 
    else exp (i - 1) (s.[i] :: l) in exp (String.length s - 1) []

let rec common_letters s1 s2 = match s1, s2 with 
  | [] , _ -> 0
  | _ , [] -> 0
  | h1::t1, h2::t2 -> 
      if (Char.equal h1 h2) then 1 + common_letters t1 t2
      else common_letters t1 t2

let find_best_match w l = 
  let best_match = List.find_opt (fun (v,_) -> (common_letters (string_to_list w) (string_to_list v)) > 2) l in
  
  match best_match with
    | None -> raise Not_close_match
    | Some (v,_) -> ("Did you mean '"^v^"' ?")