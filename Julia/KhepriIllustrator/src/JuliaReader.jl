export julia_read, @jl_str

const pushed_string = Ref{Any}(nothing)

push_string(t) =
  isnothing(pushed_string[]) ?
    pushed_string[] = t :
    error("String already pushed!!!")

pop_string() =
  isnothing(pushed_string[]) ?
    error("No string was pushed!!!") :
    let t = pushed_string[]
      pushed_string[] = nothing
      t
    end

is_string_pushed() = ! isnothing(pushed_string[])

julia_read(io=stdin) =
  let str = is_string_pushed() ? pop_string() : readline(io),
      (expr, pos) = Meta.parse(str, 1, greedy=true, raise=true, depwarn=false)
    while expr == nothing || expr isa Expr && expr.head === :incomplete
      str = str*"\n"*readline(io)
      #println("Trying to parse----\n$str\n---")
      expr, pos = Meta.parse(str, 1, greedy=true, raise=true, depwarn=false)
    end
    if pos < length(str)
      push_string(str[pos:end])
    end
    expr
  end

#=
str1 = """
if x + y > z
  z*2
else
  x+1
end
w*2
"""
julia_read(IOBuffer(str1))

str2 = "1 2 3+4"
julia_read(IOBuffer(str2))
=#

macro jl_str(str)
    QuoteNode(julia_read(IOBuffer(str)))
end
