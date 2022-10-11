
mutable struct Binding
  name
  value
end

make_binding(name, value) = Binding(name, value)
binding_name(binding) = binding.name
binding_value(binding) = binding.value
set_binding_value!(binding, value) = binding.value = value

mutable struct Environment
 bindings
 parent
end

create_initial_environment(bindings...) =
 Environment([bindings...], nothing)

augment_environment(names, values, env) =
 Environment(map(make_binding, names, values),
             env)

get_environment_binding(name, env) =
  isnothing(env) ?
    error("Unbound name: ", name) :
    begin
      for binding in env.bindings
        if name === binding_name(binding)
          return binding
        end
      end
      get_environment_binding(name, env.parent)
    end


create_initial_environment(bindings...) =
  Environment(map(b -> make_binding(b.first, b.second), bindings),
              nothing)

#=
Regarding the syntax:
=#

is_set(expr) = false # FINISH THIS!!!
assignment_name(expr) = error("FINISH THIS")
assignment_expression(expr) = error("FINISH THIS")

define_name!(name, value, env) =
  env.bindings = [make_binding(name, value), env.bindings...]

update_name!(name, value, env) =
  let binding = get_environment_binding(name, env)
    set_binding_value!(binding, value)
  end

eval_set(expr, env) =
  let value = eval_expr(assignment_expression(expr), env)
    update_name!(assignment_name(expr), value, env)
    value
  end

is_name(expr) = expr isa Symbol
eval_name(name, env) =
  binding_value(get_environment_binding(name, env))

eval_expr(expr, env) =
  if is_self_evaluating(expr)
    expr
  elseif is_name(expr)
    eval_name(expr, env)
  elseif is_quote(expr)
    eval_quote(expr, env)
  elseif is_lambda(expr)
    eval_lambda(expr, env)
  elseif is_if(expr)
    eval_if(expr, env)
  elseif is_let(expr)
    eval_let(expr, env)
  elseif is_def(expr)
    eval_def(expr, env)
  elseif is_gdef(expr)
    eval_gdef(expr, env)
  elseif is_set(expr)
    eval_set(expr, env)
  elseif is_fdef(expr)
    eval_fdef(expr, env)
  elseif is_mdef(expr)
    eval_mdef(expr, env)
  elseif is_begin(expr)
    eval_begin(expr, env)
  elseif is_and(expr)
    eval_and(expr, env)
  elseif is_or(expr)
    eval_or(expr, env)
  elseif is_call(expr)
    eval_call(expr, env)
  else
    println("I will generate an error! Here is the dump of the expression:")
    dump(expr)
    error("Unknown expression type: ", expr)
  end

struct LexicalFunction
  parameters
  body
  environment
end

make_function(parameters, body, env) = LexicalFunction(parameters, body, env)
is_function(obj) = obj isa LexicalFunction
function_parameters(f) = f.parameters
function_body(f) = f.body
function_environment(f) = f.environment

eval_lambda(expr, env) =
  make_function(lambda_parameters(expr), lambda_body(expr), env)

#=
Regarding the implementation of macros, they are just like functions (with
lexical environment, et al), but are called differently, as they receive the
operands unevaluated and the result needs further evaluation. We might distinguish
by using a special calling syntax, as it happens with Julia @macro or we might
just have a special kind of function that is not exactly like a function so that
we can distinguish them and make an appropriate call for each one.
Scheme follows this last tradition, so we will just mark each macro so that we
can recognize it.

The struct has the same fields as a (lexical) function so that the same selectors
can be used (lack of inheritance in Julia is understandable but still annoying.)
=#

struct MacroFunction
  parameters
  body
  environment
end

make_macro_function(parameters, body, env) = MacroFunction(parameters, body, env)
is_macro_function(obj) = obj isa MacroFunction

eval_mdef(expr, env) =
  let value = make_macro_function(mdef_parameters(expr), mdef_body(expr), env)
    define_name!(mdef_name(expr), value, env)
    value
  end

eval_call(expr, env) =
  let func = eval_expr(call_operator(expr), env),
      exprs = call_operands(expr)
    is_macro_function(func) ?
      let expansion = apply_function(func, exprs, env)
        replace(expr, expansion)
        eval_expr(expansion, env)
      end :
      let args = map(expr -> eval_expr(expr, env), exprs)
        apply_function(func, args, env)
      end
  end

make_primitive(f) = f
is_primitive(obj) = obj isa Function
apply_primitive(prim, args) = prim(args...)

apply_function(func, args, env) =
  is_primitive(func) ?
    apply_primitive(func, args) :
    let params = function_parameters(func),
        extended_env = augment_environment(params, args,  function_environment(func))
      eval_expr(function_body(func), extended_env)
    end

eval_if(expr, env) =
  is_true(eval_expr(if_condition(expr), env)) ?
    eval_expr(if_consequent(expr), env) :
    eval_expr(if_alternative(expr), env)

#=
For the initial environment, we also need to clean things a bit:
=#

initial_environment =
  create_initial_environment(
    :pi => 3.14159,
    :e  => 2.17828,
    :nothing => nothing,
    :+  => make_primitive(+),
    :*  => make_primitive(*),
    :-  => make_primitive(-),
    :/  => make_primitive(/),
    :(==) => make_primitive(==),
    :<  => make_primitive(<),
    :>  => make_primitive(>),
    :<= => make_primitive(<=),
    :>= => make_primitive(>=),
    :!  => make_primitive(!),
    :read => make_primitive(julia_read),
    :print => make_primitive(print),
    :println => make_primitive(println),
    :tuple => make_primitive(tuple),
    :Expr => make_primitive(Expr),
    :gensym => make_primitive(gensym),
    :eval => make_primitive(eval_expr))

eval_expr(expr) = eval_expr(expr, initial_environment)

#=
Self evaluation must also include those pesky LineNumberNodes generated by
Julia's parser:
=#
is_self_evaluating(expr) = expr isa Number || expr isa String || expr isa Bool ||
  expr isa LineNumberNode


is_call(expr) = expr isa Expr && expr.head === :call
call_operator(expr) = expr.args[1]
call_operands(expr) = expr.args[2:end]

#=
Julia uses blocks a lot. These are the equivalent to the begin forms of Scheme.
=#

is_begin(expr) = expr isa Expr && expr.head === :block
begin_expressions(expr) = expr.args
eval_begin(expr, env) =
  let eval_sequentially(exprs) =
        length(exprs) == 1 ?
          eval_expr(exprs[1], env) :
          begin
            eval_expr(exprs[1], env)
            eval_sequentially(exprs[2:end])
          end
    eval_sequentially(begin_expressions(expr))
  end

#=
As we saw in the Scheme evaluators, an anonymous function is a fundamental
concept that can be used to support different language constructs.
=#

is_lambda(expr) = expr isa Expr && expr.head === :->
lambda_parameters(expr) =
  expr.args[1] isa Expr ?
    expr.args[1].args :
    [expr.args[1]]
lambda_body(expr) = expr.args[2]

#=
Julia does not have flet, only let but it also supports local function
definitions.
=#

is_let(expr) = expr isa Expr && expr.head === :let
let_bindings(expr) =
  expr.args[1].head === :block ?
    expr.args[1].args :
    [expr.args[1]]
let_body(expr) = expr.args[end]
eval_let(expr, env) =
  let bindings = let_bindings(expr),
      names = map(let_binding_name, bindings),
      inits = map(binding -> eval_expr(let_binding_init(binding), env),
                  bindings),
      extended_env = augment_environment(names, inits, env)
    eval_expr(let_body(expr), extended_env)
  end

#=
Julia's bindings appear in lots of places, so let's generalize it:
=#

julia_binding_name(binding) =
  is_call(binding.args[1]) ?
    call_operator(binding.args[1]) :
    binding.args[1]
julia_binding_init(binding) =
  is_call(binding.args[1]) ?
    :(($(call_operands(binding.args[1])...),) -> $(binding.args[2])) :
    binding.args[2]

#=
For lets, we have:
=#

let_binding_name(binding) = julia_binding_name(binding)
let_binding_init(binding) = julia_binding_init(binding)

#=
Julia supports definitions (the previous def) and assignments (the previous set!).
However, they all use the same operator (=), which makes it difficult to decide
whether we are facing a definition or an assigment. We will start by considering
definitions. We will consider assigments later.
=#

is_def(expr) = expr isa Expr && expr.head === :(=)
def_name(expr) = julia_binding_name(expr)
def_init(expr) = julia_binding_init(expr)

#=
Assignments in Julia are a complete mess. According to the documentation, in a
local scope, all variables are inherited from its parent global scope block,
unless an assignment would result in a modified global variable, or a variable
is specifically marked with the keyword local. Thus global variables are only
inherited for reading, not for writing. In order to inherit them for writing, it
is necessary to mark them with the global keyword. This last case is identical to
the gdef form that we invented in the Scheme evaluator so we can take care of it
immediatly.
=#

is_gdef(expr) = expr isa Expr && expr.head === :global
gdef_name(expr) = julia_binding_name(expr.args[1])
gdef_init(expr) = julia_binding_init(expr.args[1])
eval_gdef(expr, env) =
  let value = eval_expr(gdef_init(expr), env)
    define_name!(gdef_name(expr), value, initial_environment)
    value
  end

#=
However, this does not solve the problem of inner scopes accessing variables in
outer non-global scopes. This is one of the situations where we need to have a
special evaluation rule.

These are the rules implemented for Scheme for, respetively, definitions and
assignments.

eval_def(expr, env) =
  let value = eval_expr(def_init(expr), env)
    define_name!(def_name(expr), value, env)
    value
  end

eval_set(expr, env) =
  let value = eval_expr(assignment_expression(expr), env)
    update_name!(assignment_name(expr), value, env)
    value
  end

Given the Julia uses the same operator for both definition and assignment, we
somehow need to merge those two definitions.
In the case of Julia, it seems that the semantics is that we only make a definition
if there is a global for the same name or if there is no variable at all. Otherwise
we must treat it as an assignment.
=#

exists_environment_binding(name, env) =
  isnothing(env) ?
    false :
    begin
      for binding in env.bindings
        if name === binding_name(binding)
          return true
        end
      end
      exists_environment_binding(name, env.parent)
    end

exists_non_global_environment_binding(name, env) =
  env === initial_environment ?
    false :
    begin
      for binding in env.bindings
        if name === binding_name(binding)
          return true
        end
      end
      exists_non_global_environment_binding(name, env.parent)
    end

eval_def(expr, env) =
  let name = def_name(expr)
    if env === initial_environment
      let value = eval_expr(def_init(expr), env)
        exists_environment_binding(name, env) ?
          update_name!(name, value, env) :
          define_name!(name, value, env)
        value
      end
    elseif exists_non_global_environment_binding(name, env)
      let value = eval_expr(def_init(expr), env)
        update_name!(name, value, env)
        value
      end
    elseif exists_environment_binding(name, initial_environment)
      define_name!(name, nothing, env)
      let value = eval_expr(def_init(expr), env)
        define_name!(name, value, env)
        value
      end
    else
      let value = eval_expr(def_init(expr), env)
        define_name!(name, value, env)
        value
      end
    end
  end

#=
The non-short form for function definitions can be handled by the previous fdef.
However, we do not need special evaluation rules because these forms can be
transformed into the corresponding short-form definitions using a source-to-source
transformation.
=#

is_fdef(expr) = expr isa Expr && expr.head === :function

fdef_name(expr) = call_operator(expr.args[1])
fdef_parameters(expr) = call_operands(expr.args[1])
fdef_body(expr) = expr.args[2]

eval_fdef(expr, env) =
  eval_expr(:($(fdef_name(expr)) =
                ($(fdef_parameters(expr)...),) -> $(fdef_body(expr))),
            env)

#=
Boolean values in Julia are more restrictive than in Scheme. In boolean contexts
only true and false are allowed.
=#

is_true(value) =
  value === true ?
    true :
    value === false ?
      false :
      error("Non boolean used in a boolean context")

is_if(expr) = expr isa Expr && expr.head === :if

if_condition(expr) = expr.args[1]
if_consequent(expr) = expr.args[2]
if_alternative(expr) = expr.args[3]

#=
We also need to support elseif. The simplest way, it seems, is to treat it as an if.
=#

is_if(expr) = expr isa Expr && (expr.head === :if || expr.head === :elseif)

#=
Logical operators need short-circuiting. Given that we ended up implementing
them in Scheme using macro transformations, we recover the original non-macro-based
implementations:
=#

eval_and(expr, env) =
  let exprs = and_expressions(expr)
    for i in 1:length(exprs)-1
      is_true(eval_expr(exprs[i], env)) || return false
    end
    eval_expr(exprs[end], env)
  end

eval_or(expr, env) =
  let exprs = or_expressions(expr)
    for i in 1:length(exprs)-1
      let res = eval_expr(exprs[i], env)
        is_true(res) && return res
      end
    end
    eval_expr(exprs[end], env)
  end

#=
The syntax of logical operators is different in Julia:
=#

is_and(expr) = expr isa Expr && expr.head === :&&
and_expressions(expr) = expr.args

is_or(expr) = expr isa Expr && expr.head === :||
or_expressions(expr) = expr.args

#=
Now, macros. They are just like functions except that their name starts with @
and Julia automatically provides an extra initial argument.
=#

is_mdef(expr) = expr isa Expr && expr.head === :macro
mdef_name(expr) = Symbol("@" * string(call_operator(expr.args[1])))
mdef_parameters(expr) = [:linenumbernode, fdef_parameters(expr)...]
mdef_body(expr) = fdef_body(expr)

is_quote(expr) = expr isa Expr && expr.head === :quote
quoted_form(expr) = expr.args[1]
#=
We need to implement the unquote form for interpolation:
=#

is_unquote(expr) = expr isa Expr && expr.head === :$
unquote_form(expr) = expr.args[1]

eval_quote(expr, env) = expand(quoted_form(expr), env)
#For one-level quote, unquote
expand(expr, env) =
  if is_unquote(expr)
    eval_expr(unquote_form(expr), env)
  elseif expr isa Expr
    Expr(expr.head, map(subform -> expand(subform, env), expr.args)...)
  else
    expr
  end

#=
Syntatically speaking, macro calls are just like function calls:
=#

is_call(expr) = expr isa Expr && (expr.head === :call || expr.head === :macrocall)

#=
Finally, we need to handle the replacement done at macro call sites.
=#

replace(source, target) =
  begin
    source.head = target.head
    source.args = target.args
  end

@test eval_expr(jl"1") == 1
@test eval_expr(jl"\"Hello, World!\"") == "Hello, World!"

#=
For basic arithmetic:
=#
eval_expr(jl"1+2")
@test eval_expr(jl"1+2") == 3
@test eval_expr(jl"(2 + 3)*(4 + 5)") === 45

#
@test eval_expr(jl"(1+2; 2*3; 3/4)") == 0.75
@test eval_expr(jl"begin 1+2; 2*3; 3/4 end") == 0.75

@test eval_expr(jl"((x,y)->x+y)(1,2)") == 3

@test eval_expr(jl"1+2") == 3
@test eval_expr(jl"pi+1") === 4.14159
@test eval_expr(jl"pi+pi") == 6.28318
@test eval_expr(jl"let x=1; x; end") === 1
@test eval_expr(jl"let x=2; x*pi; end") == 6.28318
@test eval_expr(jl"let a=1, b=2; let a=3; a+b; end; end") == 5
@test eval_expr(jl"""
let a = 1
  a + 2
end
""") === 3
@test eval_expr(jl"let x(y)=y+1; x(1); end") === 2
@test eval_expr(jl"let x(y,z)=y+z; x(1,2); end") === 3
@test eval_expr(jl"let x = 1, y(x) = x+1; y(x+1); end") == 3

@test eval_expr(jl"x = 1+2") === 3
@test eval_expr(jl"x+2") === 5
eval_expr(jl"triple(a) = a + a + a")
@test eval_expr(jl"triple(x+3)") === 18
@test eval_expr(jl"foo = 1") === 1
@test eval_expr(jl"foo + (foo = 2)") == 3 # But it could have been 4
@test eval_expr(jl"bar = 1") === 1
@test eval_expr(jl"(bar = 2) + bar") === 4 # But it could have been 3
@test eval_expr(jl"baz = 3") === 3
@test eval_expr(jl"let x = 0; baz = 5; end + baz") === 8
@test eval_expr(jl"let ; baz = 6; end + baz") === 9

@test eval_expr(jl"counter = 0") === 0
eval_expr(jl"incr() = global counter = counter + 1")
@test eval_expr(jl"incr()") === 1
@test eval_expr(jl"incr()") === 2

eval_expr(jl"let secret = 1234; global show_secret() = secret; end")
@test eval_expr(jl"show_secret()") === 1234
@test_throws Exception eval_expr(jl"secret")

eval_expr(jl"""
incr =
  let priv_counter = 0
    () -> priv_counter = priv_counter + 1
  end
""")

@test eval_expr(jl"incr()") === 1
@test eval_expr(jl"incr()") === 2
@test eval_expr(jl"incr()") === 3
@test_throws Exception eval_expr(jl"priv_counter")

eval_expr(jl"""
let priv_balance = 0
  global deposit = quantity -> priv_balance = priv_balance + quantity
  global withdraw = quantity -> priv_balance = priv_balance - quantity
end
""")

@test eval_expr(jl"deposit(200)") === 200
@test eval_expr(jl"withdraw(50)") === 150
@test_throws Exception eval_expr(jl"priv_balance")

#=
Similarly to Scheme, we too need a function definition for negation:
=#

eval_expr(jl"foo(b) = b ? false : true")
eval_expr(jl"function foo(x); x+1; end")
@test eval_expr(jl"foo(1)") === 2

@test eval_expr(jl"3 > 2 ? 1 : 0") == 1
@test eval_expr(jl"3 < 2 ? 1 : 0") == 0
@test eval_expr(jl"""
if 3 > 2
  1
else
  0
end
""") == 1
@test eval_expr(jl"""
if 3 < 2
  1
elseif 2 > 3
  2
else
  0
end
""") == 0


#eval_expr(jl"!(b) = b ? false : true")
eval_expr(jl"""
quotient_or_zero(a, b) =
  (!(b == 0) && a/b) || 0
""")
@test_throws Exception eval_expr(jl"quotient_or_zero(6, 2)") === 3.0
@test eval_expr(jl"quotient_or_zero(6, 0)") === 0

#=
=#

eval_expr(jl"reflexive_addition(x) = x + x")
@test eval_expr(jl"reflexive_addition(3)") === 6
eval_expr(jl"reflexive_product(x) = x * x")
@test eval_expr(jl"reflexive_product(3)") === 9
eval_expr(jl"reflexive_operation(f, x) = f(x, x)")
@test eval_expr(jl"reflexive_operation(+, 3)") === 6
@test eval_expr(jl"reflexive_operation(*, 3)") === 9
@test eval_expr(jl"reflexive_operation(/, 3)") === 1.0
@test eval_expr(jl"reflexive_operation(-, 3)") === 0

eval_expr(jl"""
lie(truth) = "it is not true that " * truth
""")

@test eval_expr(jl"""lie("1+1=2")""") == "it is not true that 1+1=2"
@test eval_expr(jl"""lie("it is not true that 1+1=2")""") == "it is not true that it is not true that 1+1=2"
eval_expr(jl"""
make_it_true(lie) =
  lie(lie)
""")
@test_throws Exception eval_expr(jl"""make_it_true("1+1=3")""")

@test eval_expr(jl"balance = 0") === 0
eval_expr(jl"""
deposit(quantity) =
  global balance = balance + quantity
""")
eval_expr(jl"""
withdraw(quantity) =
  global balance = balance - quantity
""")
@test eval_expr(jl"deposit(200)") === 200
@test eval_expr(jl"withdraw(50)") === 150
eval_expr(jl"""
deposit_and_withdraw(deposited, withdrawed) = begin
  deposit(deposited)
  withdraw(withdrawed)
end
""")
@test eval_expr(jl"deposit_and_withdraw(100, 20)") === 230
eval_expr(jl"""
deposit_and_apply_taxes(deposit, tax) =
  deposit_and_withdraw(deposit, tax * deposit)
""")
@test eval_expr(jl"deposit_and_apply_taxes(100, 0.4)") === 290.0

eval_expr(jl"""
sum(f, a, b) =
  a > b ?
    0 :
    f(a) + sum(f, a + 1, b)
""")
eval_expr(jl"""cube(x) = x*x*x""")
@test eval_expr(jl"sum(cube, 1, 10)") === 3025
eval_expr(jl"identity(x) = x")
@test eval_expr(jl"sum(identity, 1, 100)") === 5050

eval_expr(jl"""
expt(x, n) =
  n == 0 ?
    1 :
    x * expt(x, n - 1)
""")
eval_expr(jl"""
approx_pi(n) =
  let term(i) = expt(-1.0, i)/(2i + 1)
    4*sum(term, 0, n)
  end
""")
@test eval_expr(jl"approx_pi(10)") === 3.232315809405593
@test eval_expr(jl"approx_pi(100)") === 3.151493401070991

eval_expr(jl"""
product(f, a, b) =
  a > b ?
    1 :
    f(a) * product(f, a + 1, b)
""")
eval_expr(jl"""
fact(n) =
  product(identity, 1, n)
""")
@test eval_expr(jl"fact(0)") === 1
@test eval_expr(jl"fact(10)") === 3628800

eval_expr(jl"""
accumulate(combiner, neutral, f, a, b) =
  a > b ?
    neutral :
    combiner(f(a),
             accumulate(combiner, neutral, f, a + 1, b))
""")
eval_expr(jl"""
fact(n) =
  accumulate(*, 1, identity, 1, n)
""")
@test eval_expr(jl"fact(0)") === 1
@test eval_expr(jl"fact(10)") === 3628800

eval_expr(jl"""
next(i) =
  i < 0 ?
    i + -1 :
    i + +1
""")
@test eval_expr(jl"next(3)") === 4
@test eval_expr(jl"next(-5)") === -6

#=
One possible improvement is to factor the addition to avoid repetition:
=#

eval_expr(jl"""
next(i) =
  i + (i < 0 ? -1 : +1)
""")

@test eval_expr(jl"next(3)") === 4
@test eval_expr(jl"next(-5)") === -6

#=
On the other hand, had the function be defined in a slightly different way:
=#

eval_expr(jl"""
next(i) =
  i < 0 ?
    i - 1 :
    i + 1
""")

@test eval_expr(jl"next(3)") === 4
@test eval_expr(jl"next(-5)") === -6

#=
and the factorization would look different:
=#

eval_expr(jl"""
next(i) =
  (i < 0 ?
    (-) :
    (+))(i, 1)
""")

@test eval_expr(jl"next(3)") === 4
@test eval_expr(jl"next(-5)") === -6

eval_expr(jl"""
next(i) =
  (if i < 0
     -
   else
     +
   end)(i, 1)
""")

@test eval_expr(jl"next(3)") === 4
@test eval_expr(jl"next(-5)") === -6

eval_expr(jl"""
approx_pi(n) =
  4*sum(i -> expt(-1.0, i)/(2i + 1), 0, n)
""")
@test eval_expr(jl"approx_pi(10)") === 3.232315809405593
@test eval_expr(jl"approx_pi(100)") === 3.151493401070991

eval_expr(jl"""
fact(n) =
  accumulate(*, 1, i -> i, 1, n)
""")
@test eval_expr(jl"fact(0)") === 1
@test eval_expr(jl"fact(10)") === 3628800

eval_expr(jl"""
approx_e(n) =
  sum(i -> 1.0/fact(i), 0, n)
""")
@test eval_expr(jl"approx_e(10)") === 2.7182818011463845
@test eval_expr(jl"approx_e(20)") === 2.718281828459045
@test eval_expr(jl"approx_e(30)") === 2.718281828459045

eval_expr(jl"""
second_order_sum(a, b, c, i0, i1) =
  sum(x -> a*x*x + b*x + c, i0, i1)
""")
@test eval_expr(jl"second_order_sum(10, 5, 0, -1, +1)") === 20

eval_expr(jl"""
compose(f, g) =
  x -> f(g(x))
""")
eval_expr(jl"foo(x) = x + 5")
eval_expr(jl"bar(x) = x * 3")
eval_expr(jl"foobar = compose(foo, bar)")
@test eval_expr(jl"foobar(2)") === 11

@test eval_expr(jl"""
let fact = false
  fact = n ->
    n == 0 ?
      1 :
      n * fact(n - 1)
  fact(3)
end
""") === 6

@test eval_expr(jl"""
let ;
  fact(n) =
    n == 0 ?
      1 :
      n * fact(n - 1)
  fact(3)
end
""") === 6

@test eval_expr(jl":(a+b)") == :(a+b)
@test eval_expr(jl":(a+$(1+2))") == jl"a + 3"

eval_expr(jl"""
macro and(b0, b1)
  :($(b0) ? $(b1) : false)
end
""")
eval_expr(jl"""
quotient_or_false(a, b) =
  @and(!(b == 0), a/b)
""")

@test eval_expr(jl"quotient_or_false(6, 2)") === 3.0
@test eval_expr(jl"quotient_or_false(6, 0)") === false

julia_repl() =
  while true
    prompt_for_input()
    let expression = julia_read(stdin),
        value = eval_expr(expression)
      println(stdout, value)
    end
  end
