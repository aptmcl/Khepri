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
            // Use the overload that specifies parameter type to avoid ambiguity
            // when multiple types have the same name (e.g., System.Drawing.Color vs Autodesk.AutoCAD.Colors.Color)
            var writer = returnType == typeof(void)
                ? GetMethod(c.Type, methodName)
                : GetMethod(c.Type, methodName, returnType);
            if (returnType == typeof(void))
                return Expression.Block(e, Expression.Call(c, writer));
            else
                return Expression.Call(c, writer, e);
        }

        //We need to visualize errors
        static Expression SerializeErrors(ParameterExpression c, ParameterInfo p, Expression e) {
            var reporter = GetMethod(c.Type, "e" + MethodNameFromType(p.ParameterType));
            var ex = Expression.Parameter(typeof(Exception), "ex");
            return Expression.TryCatch(e,
                Expression.Catch(ex,
                    Expression.Block(
                        Expression.Call(c, reporter, ex))));
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
                channel.wInt32(-1);
                channel.wString(error);
                channel.Flush();
                return null;
            }
            var actualCanonical = CanonicalFromReflection(f);
            if (expectedCanonical != actualCanonical) {
                channel.wInt32(-1);
                channel.wString($"Signature mismatch for '{name}': Julia expects {expectedCanonical} but C# has {actualCanonical}");
                channel.Flush();
                return null;
            }
            return GenerateRMIFor(channel, primitives, f);
        }
    }
}
