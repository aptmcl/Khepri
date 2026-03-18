using System;
using System.Diagnostics;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;

namespace KhepriBase {
    public class RMIfy {
        //Reflection machinery
        static MethodInfo GetMethod(Type t, String name) {
            try {
                MethodInfo m = t.GetMethod(name);
                if (m != null) {
                    return m;
                } else {
                    throw new Exception("There is no method named '" + name + "' in type '" + t + "'");
                }
            } catch (AmbiguousMatchException) {
                throw new Exception("The method '" + name + "' is ambiguous in type '" + t + "'");
            }
        }

        static MethodInfo TryGetMethod(Type t, String name, out String error) {
            try {
                MethodInfo m = t.GetMethod(name);
                if (m != null) {
                    error = null;
                    return m;
                } else {
                    error = "Method '" + name + "' not found in " + t.Name;
                    return null;
                }
            } catch (AmbiguousMatchException) {
                error = "Method '" + name + "' is ambiguous in " + t.Name;
                return null;
            }
        }

        // Get method with specific parameter type to avoid ambiguity when overloads exist
        static MethodInfo GetMethod(Type t, String name, Type paramType) {
            try {
                MethodInfo m = t.GetMethod(name, new Type[] { paramType });
                if (m != null) {
                    return m;
                } else {
                    throw new Exception("There is no method named '" + name + "(" + paramType + ")' in type '" + t + "'");
                }
            } catch (AmbiguousMatchException) {
                throw new Exception("The method '" + name + "(" + paramType + ")' is ambiguous in type '" + t + "'");
            }
        }

        static String MethodNameFromType(Type t) =>
            t.IsArray ? MethodNameFromType(t.GetElementType()) + "Array" : t.Name;

        static MethodCallExpression DeserializeParameter(ParameterExpression c, ParameterInfo p) =>
            Expression.Call(c, GetMethod(c.Type, "r" + MethodNameFromType(p.ParameterType)));

        static Expression SerializeReturn(ParameterExpression c, ParameterInfo p, Expression e) {
            var returnType = p.ParameterType;
            var methodName = "w" + MethodNameFromType(returnType);
            var wByteMethod = GetMethod(c.Type, "wByte");
            var okPrefix = Expression.Call(c, wByteMethod, Expression.Constant((byte)0));
            if (returnType == typeof(void)) {
                var writer = GetMethod(c.Type, methodName);
                return Expression.Block(e, okPrefix, Expression.Call(c, writer));
            } else {
                var writer = GetMethod(c.Type, methodName, returnType);
                var resultVar = Expression.Variable(returnType, "result");
                return Expression.Block(
                    new[] { resultVar },
                    Expression.Assign(resultVar, e),
                    okPrefix,
                    Expression.Call(c, writer, resultVar));
            }
        }

        //We need to visualize errors
        static Expression SerializeErrors(ParameterExpression c, ParameterInfo p, Expression e) {
            var wByteMethod = GetMethod(c.Type, "wByte");
            var wStringMethod = GetMethod(c.Type, "wString");
            var notokPrefix = Expression.Call(c, wByteMethod, Expression.Constant((byte)1));
            var ex = Expression.Parameter(typeof(Exception), "ex");
            var errorMsg = Expression.Call(
                typeof(string).GetMethod("Concat", new[] { typeof(string), typeof(string), typeof(string) }),
                Expression.Property(ex, "Message"),
                Expression.Constant("\n"),
                Expression.Property(ex, "StackTrace"));
            return Expression.TryCatch(e,
                Expression.Catch(ex,
                    Expression.Block(notokPrefix, Expression.Call(c, wStringMethod, errorMsg))));
        }

        static Action<C,P> GenerateRMIFor<C,P>(C channel, P primitives, MethodInfo f) {
            ParameterExpression c = Expression.Parameter(typeof(C), "channel");
            ParameterExpression p = Expression.Parameter(typeof(P), "primitives");
            BlockExpression block = Expression.Block(
                SerializeErrors(
                    c,
                    f.ReturnParameter,
                    SerializeReturn(
                        c,
                        f.ReturnParameter,
                        Expression.Call(
                            p,
                            f,
                            f.GetParameters().Select(pr => DeserializeParameter(c, pr))))));
            return Expression.Lambda<Action<C, P>>(block, new ParameterExpression[] { c, p }).Compile();
        }

        static string CanonicalFromReflection(MethodInfo m) {
            var ret = MethodNameFromType(m.ReturnType);
            var parms = string.Join(",", m.GetParameters().Select(p => MethodNameFromType(p.ParameterType)));
            return $"{ret}({parms})";
        }

        public static Action<C,P> RMIFor<C,P>(C channel, P primitives, String name, String expectedCanonical) where C : Channel {
            String error;
            MethodInfo f = TryGetMethod(primitives.GetType(), name, out error);
            if (f == null) {
                channel.wByte(1);
                channel.wString(error);
                channel.Flush();
                return null;
            }
            var actualCanonical = CanonicalFromReflection(f);
            if (expectedCanonical != actualCanonical) {
                channel.wByte(1);
                channel.wString($"Signature mismatch for '{name}': Julia expects {expectedCanonical} but C# has {actualCanonical}");
                channel.Flush();
                return null;
            }
            return GenerateRMIFor(channel, primitives, f);
        }
    }
}
