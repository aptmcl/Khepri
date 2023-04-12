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
@test eval_expr(jl"pi+1") === 4.141592653589793
@test eval_expr(jl"let x=1; x; end") === 1
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

@test eval_expr(jl"""
let x = 1, y = 2
  x + y
end
""") == 3

@test eval_expr(jl"""
let (x, y) = (1, 2)
  x + y
end
""") == 3

@test eval_expr(jl"""
let x = 1, y = x + 1
  y
end
""") === 2