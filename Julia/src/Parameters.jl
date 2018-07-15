export with, Parameter, LazyParameter

mutable struct Parameter{T}
  value::T
end

(p::Parameter{T}){T}()::T = p.value
(p::Parameter{T}){T}(newvalue::T) = p.value = newvalue

function with{T}(f, p::Parameter{T}, newvalue::T)
  oldvalue, p.value = p.value, newvalue
  try
    f()
  finally
    p.value = oldvalue
  end
end

# A more generic version (presumably, compatible with the previous one)
function with(f, p, newvalue)
  oldvalue = p()
  p(newvalue)
  try
    f()
  finally
    p(oldvalue)
  end
end

mutable struct LazyParameter{T}
  initializer::Function #This should be a more specific type: None->T
  value::Nullable{T}
end

LazyParameter(T::DataType, initializer::Function) = LazyParameter(initializer, Nullable{T}())

(p::LazyParameter{T}){T}()::T = isnull(p.value) ? (init = p.initializer(); p.value = Nullable(init); init) : get(p.value)
(p::LazyParameter{T}){T}(newvalue::T) = p.value = Nullable(newvalue)

import Base.reset
reset(p::LazyParameter{T}) where {T} = p.value = Nullable{T}()
