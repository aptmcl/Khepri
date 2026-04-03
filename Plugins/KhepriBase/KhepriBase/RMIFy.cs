using System;
using System.Diagnostics;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;

namespace KhepriBase {
    /// <summary>
    /// Dynamic RMI via .NET Expression Trees. Given a method name from Julia, uses
    /// reflection to find it on the Primitives class, then builds a compiled delegate
    /// that deserializes parameters from the channel, calls the method, and serializes
    /// the result back. This compilation happens once per method (on first call);
    /// subsequent calls use the cached delegate directly.
    ///
    /// Constraint: method names must be unique (no overloads) because Type.GetMethod(name)
    /// throws AmbiguousMatchException for overloaded methods.
    /// </summary>
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

        // Maps .NET types to Channel read/write method names (e.g., Int32 → rInt32/wInt32,
        // Int32[] → rInt32Array/wInt32Array). This is the link between the type system
        // and the r/w naming convention in Channel.
        static String MethodNameFromType(Type t) =>
            t.IsArray ? MethodNameFromType(t.GetElementType()) + "Array" : t.Name;

        // Build a reader expression for a type. For arrays, inlines a
        // length-prefixed loop that recursively reads each element.
        static Expression BuildReader(ParameterExpression c, Type t) {
            if (t.IsArray) {
                Type elemType = t.GetElementType();
                var len = Expression.Variable(typeof(int), "len");
                var arr = Expression.Variable(t, "arr");
                var idx = Expression.Variable(typeof(int), "idx");
                var exit = Expression.Label(t);
                return Expression.Block(t,
                    new[] { len, arr, idx },
                    Expression.Assign(len, Expression.Call(c, GetMethod(c.Type, "rInt32"))),
                    Expression.Assign(arr, Expression.NewArrayBounds(elemType, len)),
                    Expression.Assign(idx, Expression.Constant(0)),
                    Expression.Loop(
                        Expression.IfThenElse(
                            Expression.LessThan(idx, len),
                            Expression.Block(
                                Expression.Assign(
                                    Expression.ArrayAccess(arr, idx),
                                    BuildReader(c, elemType)),
                                Expression.PostIncrementAssign(idx)),
                            Expression.Break(exit, arr)),
                        exit));
            }
            return Expression.Call(c, GetMethod(c.Type, "r" + t.Name));
        }

        static Expression DeserializeParameter(ParameterExpression c, ParameterInfo p) =>
            BuildReader(c, p.ParameterType);

        // Build a writer expression for a type. For arrays, inlines a
        // length-prefixed loop that recursively writes each element.
        static Expression BuildWriter(ParameterExpression c, Type t, Expression value) {
            if (t.IsArray) {
                Type elemType = t.GetElementType();
                var arr = Expression.Variable(t, "arr");
                var idx = Expression.Variable(typeof(int), "idx");
                var len = Expression.ArrayLength(arr);
                var exit = Expression.Label();
                return Expression.Block(
                    new[] { arr, idx },
                    Expression.Assign(arr, value),
                    Expression.Call(c, GetMethod(c.Type, "wInt32", typeof(int)), len),
                    Expression.Assign(idx, Expression.Constant(0)),
                    Expression.Loop(
                        Expression.IfThenElse(
                            Expression.LessThan(idx, len),
                            Expression.Block(
                                BuildWriter(c, elemType, Expression.ArrayIndex(arr, idx)),
                                Expression.PostIncrementAssign(idx)),
                            Expression.Break(exit)),
                        exit));
            }
            return Expression.Call(c, GetMethod(c.Type, "w" + t.Name, t), value);
        }

        // Generates the OK path of the response: writes a 0x00 status prefix byte followed
        // by the serialized return value (or just wVoid for void methods). The status prefix
        // is the application-layer mechanism for distinguishing success from error; it lives
        // inside the frame payload, keeping the framing layer (Int32 length prefix) clean.
        static Expression SerializeReturn(ParameterExpression c, ParameterInfo p, Expression e) {
            var returnType = p.ParameterType;
            var wByteMethod = GetMethod(c.Type, "wByte");
            var okPrefix = Expression.Call(c, wByteMethod, Expression.Constant((byte)0));
            if (returnType == typeof(void)) {
                var writer = GetMethod(c.Type, "wVoid");
                return Expression.Block(e, okPrefix, Expression.Call(c, writer));
            } else {
                var resultVar = Expression.Variable(returnType, "result");
                return Expression.Block(
                    new[] { resultVar },
                    Expression.Assign(resultVar, e),
                    okPrefix,
                    BuildWriter(c, returnType, resultVar));
            }
        }

        // Wraps the OK-path expression in a try-catch: on exception, writes a 0x01 (NOTOK)
        // prefix followed by the error message and stack trace. The Julia side reads the
        // prefix byte first and either decodes the return value (0x00) or throws a
        // BackendError (0x01).
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

        // Composes the full delegate: DeserializeParams → Call → SerializeReturn (OK prefix)
        // → SerializeErrors (try-catch with NOTOK prefix). The Expression Tree is compiled
        // once into a native delegate.
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

        // Canonical signature mechanism: Julia sends an expected signature string
        // (e.g., "Int32(Point3d,Double)") and C# computes the actual one from reflection.
        // If they don't match, the operation is rejected before registering, catching
        // protocol drift between Julia and C# at connection time rather than at runtime.
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
