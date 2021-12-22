%{

  open Lexing
  open Minic_ast

  let print_error_message_with_position message pos = (Printf.sprintf "Syntax error at %d, %d" pos.pos_lnum (pos.pos_cnum - pos.pos_bol))^message

%}

(* Déclaration des lexèmes *)
%token MAIN
%token <int> CST
%token <bool> BOOL_CST
%token <string> IDENT
%token <string> STR
%token LPAR RPAR BEGIN END
%token RETURN SET
%token IF ELSE WHILE FOR
%token SEMI COMMA
%token INT BOOL VOID STRING
%token TIMES
%token PLUS 
%token LT
%token EG
%token OR
%token AND
%token NOT
%token PUTCHAR
%token EOF

%nonassoc EG
%nonassoc LT
%left PLUS
%left TIMES
%left OR
%left AND
%nonassoc NOT


%start program
%type <Minic_ast.prog> program

%%

(* Un programme est une liste de déclarations.
   On ajoute une règle déclenchée en cas d'erreur, donnant une
   information minimale : la position. *)
program:
| dl=declaration_list EOF
       { let var_list, fun_list, m = dl in
         { globals = var_list; functions = fun_list; main = m} }
| error { let pos = $startpos in failwith (print_error_message_with_position "" pos) }
;

(* Chaque déclaration peut concerner une variable ou une fonction. *)
declaration_list:
| (* vide *) { [], [], [] }    
| vd=variable_decl dl=declaration_list { let vl, fl, m = dl in
                                         (vd :: vl), fl, m }
| fd=function_decl dl=declaration_list { let vl, fl, m = dl in
                                         vl, (fd :: fl), m }
| md = main_decl dl=declaration_list {let vl, fl, _ = dl in
                                          vl, fl, [md]}
;

(* Déclaration de variable.
   Note : on ne traite ici que le cas où une valeur initiale est fournie.

   À COMPLÉTER
*)
variable_decl:
| t=typ x=IDENT SET e=expression SEMI { (x, t, e) }
| t=typ x=IDENT SEMI { (x, t, Null(x))}
;

(* Indication de type.

   À COMPLÉTER
*)
typ:
| INT { Int }
| BOOL { Bool }
| VOID { Void }
| STRING { String }
;

(* Déclaration de fonction.
   Note : on ne traite ici que le cas d'une fonction sans argument et
   sans variable locale.

   À COMPLÉTER
*)
function_decl:
| t=typ f=IDENT LPAR p=list(params) RPAR BEGIN v=list(variable_decl) s=list(instruction) END
   { { name=f; code=s; params=p; return=t; locals=v } }
;
main_decl:
|t = typ MAIN LPAR RPAR BEGIN v=list(variable_decl) s=list(instruction) END {{name = "main" ; code = s ; params = [] ; return = t; locals = v}}
;

params:
| t=typ x=IDENT COMMA { (x, t) }
| t=typ x=IDENT { (x, t) }
;

(* Instructions.

   À COMPLÉTER
*)

instruction:
| PUTCHAR LPAR e=expression RPAR SEMI { Putchar(e) }
| x=IDENT SET e=expression SEMI { Set(x,e) }
| IF LPAR e=expression RPAR BEGIN s1=list(instruction) END { If(e, s1, [Skip])}
| IF LPAR e=expression RPAR BEGIN s1=list(instruction) END ELSE BEGIN s2=list(instruction) END { If(e,s1,s2) }
| WHILE LPAR e=expression RPAR BEGIN s=list(instruction) END { While(e,s) }
| FOR LPAR v=variable_decl e=expression SEMI i=indentation RPAR BEGIN s=list(instruction) END { For(v,e,s@[i]) }
| RETURN e=expression SEMI { Return(e) }
| e=expression SEMI { Expr(e) }

(* Erreurs *)
| lpar_error { let pos = $startpos in failwith (print_error_message_with_position ", \"(\" expected" pos) }
| rpar_error { let pos = $startpos in failwith (print_error_message_with_position ", \")\" expected" pos) }
| semi_error { let pos = $startpos in failwith (print_error_message_with_position ", missing semicolumn ?" pos) }
| error { let pos = $startpos in failwith (print_error_message_with_position "" pos) }
;

lpar_error:
| PUTCHAR error {}
| IF error {}
| WHILE error {}
| FOR error {}
;

rpar_error:
| PUTCHAR LPAR expression error {}
| IF LPAR expression error {}
| WHILE LPAR expression error {}
| FOR LPAR variable_decl expression SEMI indentation error {}
;

semi_error:
| PUTCHAR LPAR expression RPAR error {}
| IDENT SET expression error {}
| RETURN expression error {}
| expression error {}
;


indentation:
| x=IDENT SET e=expression { Set(x,e) }
;
(* Expressions.

   À COMPLÉTER
*)
expression:
| n=CST { Cst(n) }
| b=BOOL_CST { BCst(b) }
| s=STR { Str(s) }
| e1=expression PLUS e2=expression { Add(e1, e2) }
| e1=expression TIMES e2=expression { Mul(e1, e2) }
| e1=expression LT e2=expression { Lt(e1, e2) }
| x=IDENT { Get(x) }
| f=IDENT LPAR a=list(args) RPAR { Call(f,a) }
| e1=expression EG e2=expression { Eg(e1, e2) }
| e1=expression OR e2=expression { Or(e1, e2) }
| e1=expression AND e2=expression { And(e1, e2) }
| NOT e1=expression { Not(e1) }
;

args:
| e=expression COMMA { e }
| e=expression { e }
;
