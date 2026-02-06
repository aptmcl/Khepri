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
                Debug.Assert(m != null, "There is no method named '" + name + "' in type '" + t + "'");
                if (m != null) {
                    return m;
                } else {
                    throw new Exception("There is no method named '" + name + "' in type '" + t + "'");
                }
            } catch (AmbiguousMatchException) {
                Debug.Assert(false, "The method '" + name + "' is ambiguous in type '" + t + "'");
                throw new Exception("The method '" + name + "' is ambiguous in type '" + t + "'");
                //return null;
            }
        }

        // Get method with specific parameter type to avoid ambiguity when overloads exist
        static MethodInfo GetMethod(Type t, String name, Type paramType) {
            try {
                MethodInfo m = t.GetMethod(name, new Type[] { paramType });
                Debug.Assert(m != null, "There is no method named '" + name + "(" + paramType + ")' in type '" + t + "'");
                if (m != null) {
                    return m;
                } else {
                    throw new Exception("There is no method named '" + name + "(" + paramType + ")' in type '" + t + "'");
                }
            } catch (AmbiguousMatchException) {
                Debug.Assert(false, "The method '" + name + "(" + paramType + ")' is ambiguous in type '" + t + "'");
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

        public static Action<C,P> RMIFor<C,P>(C channel, P primitives, String name) {
            MethodInfo f = GetMethod(primitives.GetType(), name);
            return (f == null) ? null : GenerateRMIFor(channel, primitives, f);
        }
    }
}
