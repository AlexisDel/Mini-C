# DM - Mini-C
 
## Introduction

Dans ce projet, nous avons construit la partie frontend d'un compilateur pour le langage Mini-C. Nous avons ensuite implémenté les extensions suivantes :
1. [Extension du noyau Mini-C](#Étendre-le-langage)
2. [Gestion des erreurs approfondie](#Error-Handling)
3. [Interpréteur Mini-C](#Interpréteur)

## Noyeau Mini-C
:page_facing_up: 
[`test_core.mnc`](./tests/noyeau/test_core.mnc)
[`test_ennonce.mnc`](./tests/interpret/test_ennonce.mnc)
    
Nous avons complété le squelette fourni et implémenté l'ensemble des "briques de base" de Mini-C à savoir :


- Déclaration de variables globales (avec ou sans affectation)
- Définition de fonctions
- Quelques instructions
	- Putchar
	- Affectation
	- If else
	- Boucle while
	- Return
- Quelques expressions
	- Constante entières et booléennes
	- Opérations arithmétiques et logiques (+, *, <)
	- L'accès à la valeur d'une variable
	- L'appel d'une fonction

Le typechecker vérifie récursivement le type de nos objets, par exemple, pour le `while` :
```ocaml=
...
| While(e,s) -> if type_expr local_env e <> Bool then failwith "type error"
                else List.iter (typecheck_instr local_env) s;
...
```
On verifie que l'expression `e` est bien de type booléen, et on appel récursivement une vérification de type sur chaque élément composant la séquence d'instruction de la boucle.

Pour l'appel de variable :
```ocaml=
...
| Get(v) -> let ty, e = try Env.find v local_env with Not_found -> 
            try Env.find v global_env with Not_found -> 
            failwith (did_u_mean v 
            (bindings_to_var_names (Env.bindings local_env) (Env.bindings global_env))) in
            if ty = type_expr local_env e then ty else failwith "type error"
...
```
Dans cet exemple, on cherche le type et la valeur de la variable `v` stockés dans un environnement local puis, on verifie que le type de `v` est bien le même que le type de sa valeur. 
Si le nom de la variable n'est pas une clé de l'environnement, alors le nom est mal écris ou n'existe pas, auquel cas on fait un appel à la fonction `did_u_mean` présentée dans la partie [Error Handling](#Did-you-mean-?).

## Extensions

### Étendre le langage

#### Opérateurs Booléens
:page_facing_up: 
[`test_op_bool.mnc`](./tests/extensions/test_missing_semicolumn.mnc)

Nous avons ajouté au noyau les opérateurs `!`, `&&`, `||` et `==`, dans l'ordre des priorités.
Ces opérateurs sont tous des expression de l'AST, leur type est donc vérifié dans la fonction `type_expr` du typechecker de la même manière que toutes les autres expressions.
```ocaml=
| And(e1,e2) -> if(type_expr local_env e1 = Bool && type_expr local_env e2 = Bool)
                then Bool else failwith "type error"
```
Les règle de typage sont les suivantes : 
- `e1 == e2` ➜ `e1` et `e2` ont le même type
- `e1 && e2`, `e1 || e2` ➜ `e1` et `e2` sont de type bool
- `!e1` ➜ `e1` est de type bool

Le résultat de ces 4 opérateurs est un boolean.

#### Boucle `for`
:page_facing_up: 
[`test_for_loop.mnc`](./tests/extensions/test_for_loop.mnc)


La boucle `for` est définie comme une instruction dans l'AST.
```ocaml
For of (string * typ * expr) * expr * seq
```
* `(string * typ * expr)` : la var d'incrémentation (locale).
* `expr` : l'expression booléenne de la boucle
* `seq` : la séquence d'instruction se trouvant à l'intérieur de la boucle, elle contient aussi l'instruction d'incrémentation de la boucle `for`.

La boucle `for` dans le parser :
```ocaml=
| FOR LPAR v=variable_decl e=expression SEMI i=indentation RPAR BEGIN s=list(instruction) END { For(v,e,s@[i]) }
(* Note : Il n'y a pas de SEMI après variable_decl car variable_decl contient déjà un SEMI *)
```

Nous avons fait ce choix afin de pouvoir définir la varibale d'incrémentation du `for` comme une variable locale à la boucle, chose qui n'aurait pas était possible si nous avions choisis de voir la boucle `for` comme du sucre syntaxique.

La syntaxe du `for` ainsi que sa vérification de type sont géré de la même manière que toutes les autres instructions dans le lexer et le typechecker

#### `If` sans `Else`
:page_facing_up: 
[`test_if_without_else.mnc`](./tests/extensions/test_if_without_else.mnc)

Afin d'implémenter le `If` sans `Else`, nous avons ajouter une instruction `Skip` dans l'AST. Ainsi dans le cas d'un `if` sans `else`, le parser renvoie simplement `If(e, s1, [Skip])` au lieu de `If(e, s1, s2)`. Ceci nous permet de ne pas faire de distinction de cas dans le typechecker.

#### Fonction `Main`
Afin implémenter [l'interpréteur](#Interpréteur), nous avons eu besoin de spécifier ce qu'était la fonction `main`. Pour cela, nous avons ajouté un champs `main` au type `programme` de l'AST. La fonction `main` est identifié par le lexer via le keyword `main` qui est traduit en un token `MAIN`. Le parser utilise ce token afin de repérer cette définition de fonction particulière et définir l'attribut `main` de `programme`.

:arrow_right: Tous les tests présentent une fonction main, car nous avons interdit l'absence de main dans un programme.
La fonction main ne peut pas avoir d'attributs et est forcement de type `int`.

#### Type `string`

En plus des types int, bool et void, nous avons ajouté un trype string. On peut déclarer des variables et des fonctions de types string, et les afficher avec putchar. 
Pour reconnaitre une chaine de caractères dans le lexeur, on reconnais des guillemets, puis tout ce qui n'est pas des guillemets, et enfin des guillemets:
```ocaml=
...
| "\"" ([^'\"']* as s) "\""
      { STR s }
...
```


### Error Handling

#### Missing semicolon ?
:page_facing_up: 
[`test_)_expected.mnc`](./tests/extensions/test_\)_expected.mnc)
[`test_missing_semicolumn.mnc`](./tests/extensions/test_missing_semicolumn.mnc)

Un certain nombre d'erreurs de synthaxe courantes sont détectées via le parser et engendre un message d'erreur de synthaxe spécifique à celle-ci.
Voici les erreurs spécifiques gérées :
* Pour les instructions `putchar`, `if`, `while` `for`:
    * ( expected
    * ) expected

* Pour toutes les instructions 
    * missing semicolumn ?

Pour détecter une erreur on utilise le token `error` et en jouant sur son positionement on peut déduire des erreurs précises, exemple sur l'erreur `( expected`.

```ocaml=
lpar_error:
| PUTCHAR error {}
| IF error {}
| WHILE error {}
| FOR error {}
;
```

```ocaml=
| lpar_error { let pos = $startpos in failwith (print_error_message_with_position ", \"(\" expected" pos) }
```

#### Did you mean ?
:page_facing_up: 
[`test_did_u_mean_var.mnc`](./tests/extensions/test_did_u_mean_var.mnc)
[`test_did_u_mean_fun.mnc`](./tests/extensions/test_did_u_mean_fun.mnc)

Dans la typechecker, lorsqu'un appel à une variable ou à une fonction qui n'est pas définie se produit, on vérifie via la fonction `did_u_mean` s'il n'existe pas dans l'environnement une variable ou une fonction ayant un identifiant proche (à 2 lettres près) de l'identifiant inconnue.

:arrow_right: L'ensemble des fonctions liées à l'auto-suggestion d'identifiant se trouve dans le fichier `auto_suggestion.ml`

Afin de trouver un identifiant proche, on utilise la [distance de Levenshtein](https://fr.wikipedia.org/wiki/Distance_de_Levenshtein). 

1. Variables

On itère (de gauche à droite) sur la liste (on la note `l`) contenant l'ensemble des identifiants des variables locales et globales. On calcul pour chaque identifiant sa distance de Levenshtein et on stock le résultat s'il est meilleur que le précédent `best_match`. Une fois la liste entièrement parcouru, on renvoie le `best_match`.

`l = [g0, g1, g2, ..., l0, l1, l2, ...]` avec `g` les variables globales et `l` les variables locales.

Ainsi si deux variables, une globale et une locale, ont la même distance de levenshtein, c'est l'identifiant de la varibale locale qui sera renvoyer.

2. Fonctions

Dans le cas des fonctions on fait la même chose mais on itère sur la liste des identifiant des fonctions récupéré via le champs `functions` de `programme` qui contient la `fun_def` (donc le nom) de l'ensemble des fonctions de notre programme.
 
### Interpréteur

Nous avons implémenter un interpéteur. L'interpréteur supporte tous les éléments présentés précédemments dans [le noyau Mini-C](#Noyeau-Mini-C), et dans [les ajouts](#Extensions).

Pour interpréter un programme, on parcours la séquence de la fonction `main`. Il s'agit du file conducteur du programme. cette séquence est enfait une liste d'arbre. On effectue donc un parcours d'arbres d'instruction dans la séquence du main.

Pour faire le lien avec le reste du programme, on créé avant l'interprétation deux environnements. Un environnement stockant la valeur des variables globales et les variables locales au main, et un 
environnement stockant les fonctions et leur définition. Ainsi, à chaque appel d'une fonction, on retrouve aisément sa définition.

Lors d'un appel de fonction, un nouvel environnement est crée, plus local. Cet environnement contient les valeurs passé en argument lors d'appels aux fonctions, et les variables locales aux fonctions.
Cela permet de faire le lien avec les variables locales à la fonction. 

Lors d'appels récursifs de fonctions, ou d'appels de fonctions dans le corps d'une autre fonction, pour éviter des collisions de variables, on crée des nouveaux environnements toujours plus locaux. Aussi, il devient nécessaire de non plus traiter les environnements un à un, mais de stocker l'environnement global, l'environnement de fonctions, et une liste d'environnement locaux, la tête de liste étant l'environnement le plus local. Ainsi, par exemple pour l'expression `get` :
```ocaml=
...| Get x -> let tmp = try List.find (fun env -> try let _ = 
                    Hashtbl.find env x in true with Not_found -> false) 
                    lenv with Not_found -> genv in
               let tmp = try Hashtbl.find tmp x with Not_found -> 
                   failwith ("unknown variable "^x) in tmp
...
```
Ici, on parcours la liste d'environnement locaux et on regarde le premier trouvé (et donc le plus local contenant la variable x). Si la variable n'est dans aucun environnement local, on regarde dans l'environnement global.
Ainsi, on trouve forcément la valeur associée à une variable de nom x la plus locale.

Pour l'instruction `set` :
```ocaml=
...
| Set(x, e) ->
      let v = eval_code e genv fenv lenv in
      let tmp = try List.find (fun env -> try let _ = 
      Hashtbl.find env x in true with Not_found -> false) lenv with Not_found 
      -> genv in
      Hashtbl.replace tmp x v; genv, fenv, lenv, N, false
...
```
Après avoir calculé la valeur de l'expression e, on cherche l'environnement le plus local contenant x, et on met sa valeur à jour.

Les return se doivent d'arreter totalement l'exécutions de l'instruction dans laquelle il est depuis la
racine de l'arbre.
Il est nécessaire de transmettre l'information de la présence d'un return ou non. pour cela, lors de l'interprétation d'une fonction, en plus de renvoyer les environnements, on renvoie la valeur du return, -1 sinon, et un booléen à vrai si il y a eu un return, à faux sinon :
```ocaml=
...
| Return(e) -> let tmp = eval_code e genv fenv lenv in genv, fenv, lenv, tmp, true
...
```

Regardons l'interprétation de l'instruction `If` :

```ocaml=
...
| If(e, b1, b2) ->
      let v = eval_code e genv fenv lenv in
      if v = B(true)
      then exec_function_code b1 genv fenv lenv
      else let tmp = try exec_function_code b2 genv fenv lenv with ExcepSkip -> 
      genv, fenv, lenv, N, false in tmp
...
```
On calcul la valeur de l'expression e. Si celle-ci faut 1, alors c'est un booléen à `true`, on branche donc sur la première branche. Sinon on branche sur la seconde. Dans le premier cas, on calcul simplement la séquence d'instruction de la branche. Dans le second cas, on calcul la seconde branche, et on fait attention à la présence d'une exception skip `ExcepSkip`, qui nous indique qu'il s'agit dans `If` sans `Else`, auquel cas on peut arrêter le calcul et propager l'information de l'absence de `return`. 


Attardons nous sur l'interprétation d'une boucle for :

```ocaml=
...
| For(v,e,s) -> let x_v, _, e_v = v in
                let env_for = Hashtbl.create 100 in
                let () = Hashtbl.add env_for x_v (eval_code e_v genv fenv lenv) in
                for_func genv fenv (env_for::lenv) e s
...
```

Lors de la reconnaissance d'une instruction for, on créé un environnement local à celle-ci contenant la variable d'incrémentation. puis, on appel la fonction `for_func` qui prends en paramètre la séquence d'instruction, et les environnements, donc le nouvel environnemennt `env_for` qui est le plus global.

```ocaml=
let rec for_func genv fenv lenv stop s =
  let b = eval_code stop genv fenv lenv in
  if b = B(true) 
  then let genv', fenv', lenv', res, flag = exec_function_code s genv fenv lenv in
    begin
      if flag then genv', fenv', lenv', res, flag 
      else for_func genv' fenv' lenv' stop s
    end
  else genv, fenv, lenv, N, false
``` 

La fonction `for_func` simule en Ocaml une boucle for. Cela permet d'exécuter la boucle avec potentiellent des niveau de localité encore plus bas à l'intérieur, sans collisions.


L'ajout des variables et fonctions de type `string` ont pas mal modifié l'interpréteur de base. Nous avons crée le type : 

```ocaml
type result = I of int | B of bool | S of string | N
```
Ainsi, on peut manipuler dans les mêmes fonctions des valeurs de type int et string, sans erreurs de types de Ocaml. 
L'affichage devient alors assez simple :
```ocaml=
...
| Putchar(e) -> let tmp = eval_code e genv fenv lenv in
        begin
            match tmp with
             |I(tmp) ->print_int tmp;print_string "\n"; genv, fenv, lenv, N, false
             |B(tmp) ->if tmp then print_string "true" else print_string "false";
                  print_string "\n"; genv, fenv, lenv, N, false
             |S(tmp) -> print_string tmp; print_string "\n"; 
                      genv, fenv, lenv, N, false
             |N -> print_string "null"; print_string "\n"; 
                      genv, fenv, lenv, N, false
        end
...
```
On appel une fonction d'affichage différente en fonction du filtrage.

De même pour les opérations booléennes :

```ocaml=
...
| Not(e1) -> 
      let v1 = eval_expr e1 genv fenv in
      begin
        match v1 with
          |B(v1) -> B(not v1)
          |_ -> failwith "type error"
      end
...
```

Ici, le code `|_ -> failwith "type error"` n'est jamais exécuté puisque le type checker vérifie `v1` est bien de la forme `B(bool)`.



