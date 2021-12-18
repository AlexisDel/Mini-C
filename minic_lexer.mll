{

  open Lexing
  open Minic_parser

  (* Fonction auxiliaire pour rassembler les mots-clés 
     À COMPLÉTER
   *)
  let keyword_or_ident =
    let h = Hashtbl.create 17 in
    List.iter (fun (s, k) -> Hashtbl.add h s k)
      [ "return",   RETURN;
        "true",     BOOL_CST true;
        "false",    BOOL_CST false;
        "int",      INT;
        "bool",     BOOL;
        "void",     VOID;
        "putchar",  PUTCHAR;
        "if",       IF;
        "else",     ELSE;
        "while",    WHILE;
        "for",      FOR;
        "main",     MAIN
      ] ;
    fun s ->
      try  Hashtbl.find h s
      with Not_found -> IDENT(s)
        
}

(* Règles auxiliaires *)
let digit = ['0'-'9']
let number = ['-']? digit+
let alpha = ['a'-'z' 'A'-'Z']
let ident = alpha (alpha | '_' | digit)*

(* Règles de reconnaissance 
   À COMPLÉTER
*)
rule token = parse
  | ['\n']
      { new_line lexbuf; token lexbuf }
  | [' ' '\t' '\r']+
      { token lexbuf }
  | number as n
      { CST(int_of_string n) }
  | ident as id
      { keyword_or_ident id }
  | ";"
      { SEMI }
  | ","
      { COMMA }
  | "="
      { SET }
  | "("
      { LPAR }
  | ")"
      { RPAR }
  | "{"
      { BEGIN }
  | "}"
      { END }
  | "+"
      { PLUS }
  | "*"
      { TIMES }
  | "<"
      { LT }
  | _
      { failwith ("Unknown character : " ^ (lexeme lexbuf)) }
  | eof
      { EOF }
