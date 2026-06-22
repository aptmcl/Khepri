using Grasshopper;
using Grasshopper.GUI;
using Grasshopper.GUI.Canvas;
using Grasshopper.Kernel;
using Grasshopper.Kernel.Attributes;
using Grasshopper.Kernel.Data;
using Grasshopper.Kernel.Parameters;
using Grasshopper.Kernel.Types;
using Rhino;
using Rhino.Geometry;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Timers;
using System.Windows.Forms;

namespace KhepriGrasshopper {

    public static class Ext {
        public static bool In<T>(this T t, params T[] values) {
            return values.Contains(t);
        }
    }

    internal static class NativeMethods {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern bool SetDllDirectory(string lpPathName);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void jl_init();

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        internal static extern IntPtr jl_eval_string([MarshalAs(UnmanagedType.LPUTF8Str)] string input);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_float64(Double value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Double jl_unbox_float64(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_int8(Byte value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Byte jl_unbox_int8(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_bool(Byte value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Byte jl_unbox_bool(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_uint8(Byte value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Byte jl_unbox_uint8(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_int16(Int16 value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Int16 jl_unbox_int16(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_int32(Int32 value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Int32 jl_unbox_int32(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_int64(Int64 value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Int64 jl_unbox_int64(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_box_uint64(UInt64 value);
        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern UInt64 jl_unbox_uint64(IntPtr value);

        //[DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        //internal static extern IntPtr jl_cellref(IntPtr a, UInt64 i); //0-indexed

        //[DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        //internal static extern void jl_cellset(IntPtr a, IntPtr v, UInt64 i); //0-indexed

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern UInt64 jl_array_size(IntPtr a, int dim);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_apply_array_type(IntPtr atype, int dim);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_alloc_array_1d(IntPtr atype, int nrows);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_alloc_array_2d(IntPtr atype, int nrows, int ncols);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_array_to_string(IntPtr a);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void jl_gc_queue_root(IntPtr parent);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_string_ptr(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_cstr_to_string([MarshalAs(UnmanagedType.LPUTF8Str)] string str);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_typeof_str(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Int32 jl_isa(IntPtr value, IntPtr type);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_get_global(IntPtr module, [MarshalAs(UnmanagedType.LPUTF8Str)] string name);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_call0(IntPtr func);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_call1(IntPtr func, IntPtr v1);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_call2(IntPtr func, IntPtr v1, IntPtr v2);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_call3(IntPtr func, IntPtr v1, IntPtr v2, IntPtr v3);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_call(IntPtr func, IntPtr args, Int32 nargs);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void jl_atexit_hook(Int32 a);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_exception_occurred();

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_exception_clear();
    }


    /*
     * The goal is to translate from
     * 
     * pt < GHPoint(""Point"", ""P"", ""Input Point"", :item, xy(1,0))
     * r  > GHNumber(""Radius"", ""R"", ""Radius of polar coordinates"", :item)
     * a  > GHNumber(""Angle"", ""A"", ""Angle of polar coordinates"", :item)
     * 
     * r = pol_rho(pt)
     * a = pol_phi(pt)
     * 
     * to
     * 
     * function foo(p0)
     *   pt = p0
     *   r = pol_rho(pt)
     *   a = pol_phi(pt)
     *   (r,a)
     * end
     *   
     *  The use of ans allows us to simplify a bit. We will transform
     * 
     * pt  < GHPoint(""Point"", ""P"", ""Input Point"", :item, xy(1,0))
     * _   > GHNumber(""Angle"", ""A"", ""Angle of polar coordinates"", :item)
     * 
     * pol_phi(pt)
     * 
     * to
     * 
     * function foo(p0)
     *   pt = p0
     *   r = pol_rho(pt)
     *   pol_phi(pt)
     * end
     */

    public class KhepriComponent : GH_Component, IGH_VariableParameterComponent {

        private static bool initialized = false;
        private static bool trace = true;
        private static bool debug = false;
        private static string externalEditor;

        static void JLError(string msg) {
            RhinoApp.WriteLine($"Julia error: {msg}");
            throw new Exception($"Julia error: {msg}");
        }

        static void JLInfo(string msg) {
            RhinoApp.WriteLine($"Julia info: {msg}");
        }

        static IntPtr JLEvaluate(string expr) {
            //For debug: 
            if (debug) {
                JLInfo(expr);
            }
            IntPtr resPtr = NativeMethods.jl_eval_string(expr);
            CheckForException();
            return resPtr;
        }

        static void CheckForException() {
            IntPtr exception = NativeMethods.jl_exception_occurred();
            if (exception != IntPtr.Zero) {
                //IntPtr errStrPtr = NativeMethods.jl_call2(jl_sprint, jl_showerror, exception);
                IntPtr errStrPtr = NativeMethods.jl_call1(jl_errormsg, exception);
                JLError(Marshal.PtrToStringAnsi(NativeMethods.jl_string_ptr(errStrPtr)));
            }
        }

        static IntPtr JLGetFunction(string name) {
            //We should use something like jl_get_function(jl_base_module, "sqrt") but, for now, we will just evaluate the function name
            return JLEvaluate(name);
        }

        const int word_size = 8;
        private static IntPtr jl_Nothing;
        private static IntPtr jl_Missing;
        private static IntPtr jl_Float64;
        private static IntPtr jl_Int64;
        private static IntPtr jl_String;
        private static IntPtr jl_Bool;
        private static IntPtr jl_UInt8;
        private static IntPtr jl_length;
        private static IntPtr jl_getindex;
        private static IntPtr jl_setindex;
        private static IntPtr jl_isempty;
        private static IntPtr jl_empty_it;
        private static IntPtr jl_sprint;
        private static IntPtr jl_repr;
        private static IntPtr jl_showerror;
        private static IntPtr jl_errormsg;
        private static IntPtr jl_xyz;
        private static IntPtr jl_vxyz;
        private static IntPtr jl_cx;
        private static IntPtr jl_cy;
        private static IntPtr jl_cz;
        private static IntPtr jl_raw_point;
        private static IntPtr jl_raw_plane;
        private static IntPtr jl_has_current_backend;
        private static IntPtr jl_XYZ;
        private static IntPtr jl_VXYZ;
        private static IntPtr jl_delete_shapes;
        private static IntPtr jl_highlight_shapes;
        private static IntPtr jl_unhighlight_shapes;

        static void DefineBase() {
            jl_Nothing = NativeMethods.jl_eval_string("Base.Nothing");
            jl_Missing = NativeMethods.jl_eval_string("Base.Missing");
            jl_Float64 = NativeMethods.jl_eval_string("Base.Float64");
            jl_Int64 = NativeMethods.jl_eval_string("Base.Int64");
            jl_UInt8 = NativeMethods.jl_eval_string("Base.UInt8");
            jl_String = NativeMethods.jl_eval_string("Base.String");
            jl_Bool = NativeMethods.jl_eval_string("Base.Bool");
            jl_length = NativeMethods.jl_eval_string("Base.length");
            jl_getindex = NativeMethods.jl_eval_string("Base.getindex");
            jl_setindex = NativeMethods.jl_eval_string("Base.setindex!");
            jl_isempty = NativeMethods.jl_eval_string("Base.isempty");
            jl_empty_it = NativeMethods.jl_eval_string("Base.empty!");
            jl_sprint = NativeMethods.jl_eval_string("Base.sprint");
            jl_repr = NativeMethods.jl_eval_string("Base.repr");
            jl_showerror = NativeMethods.jl_eval_string("Base.showerror");
        }
        static void DefineKhepri() {
            jl_errormsg = JLGetFunction("KhepriBase.errormsg");
            jl_xyz = JLGetFunction("KhepriBase.xyz");
            jl_vxyz = JLGetFunction("KhepriBase.vxyz");
            jl_cx = JLGetFunction("KhepriBase.cx");
            jl_cy = JLGetFunction("KhepriBase.cy");
            jl_cz = JLGetFunction("KhepriBase.cz");
            jl_raw_point = JLGetFunction("KhepriBase.raw_point");
            jl_raw_plane = JLGetFunction("KhepriBase.raw_plane");
            jl_has_current_backend = JLGetFunction("KhepriBase.has_current_backend");
            jl_XYZ = JLEvaluate("KhepriBase.XYZ");
            jl_VXYZ = JLEvaluate("KhepriBase.VXYZ");
            jl_delete_shapes = JLEvaluate("KhepriBase.delete_shapes");
            jl_highlight_shapes = JLEvaluate("KhepriBase.highlight_shapes");
            jl_unhighlight_shapes = JLEvaluate("KhepriBase.unhighlight_shapes");
        }

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        public delegate void Callback();
        static Callback Info = () => JLInfo("Testing");

        /*static void DefineCallbacks() {
            IntPtr jl_setCallback = JLGetFunction("KhepriGrasshopper.set_callback");
            NativeMethods.jl_call2(jl_setCallback, asJLString("cs_info"), Info as UnmanagedType.FunctionPtr);


        }*/
        static bool JLIsaNothing(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Nothing) != 0;
        static bool JLIsaMssing(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Missing) != 0;
        static bool JLIsaFloat64(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Float64) != 0;
        static bool JLIsaInt64(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Int64) != 0;
        static bool JLIsaBool(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Bool) != 0;
        static bool JLIsaString(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_String) != 0;
        static bool JLIsaXYZ(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_XYZ) != 0;
        static bool JLIsaVXYZ(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_VXYZ) != 0;

        static int JLLength(IntPtr arrPtr) =>
            // We must use length because jl_array_size returns the full size, which might be bigger than the valid size.
            //(int)NativeMethods.jl_array_size(arrPtr, 1);
            (int)NativeMethods.jl_unbox_int64(NativeMethods.jl_call1(jl_length, arrPtr));
        static IntPtr JLGetIndex0(IntPtr arrPtr, int idx) =>
            NativeMethods.jl_call2(jl_getindex, arrPtr, NativeMethods.jl_box_int64(idx + 1));
            //NativeMethods.jl_cellref(arrPtr, (UInt64)idx);
        static void JLSetIndex0(IntPtr arrPtr, IntPtr valPtr, int idx) =>
        //Julia arrays are indexed starting from 1
            NativeMethods.jl_call3(jl_setindex, arrPtr, valPtr, NativeMethods.jl_box_int64(idx + 1));
        //static void JLSetIndex0(IntPtr arrPtr, IntPtr valPtr, int idx) {
        //NativeMethods.jl_arrayset(arrPtr, valPtr, (UInt64)idx);
        //NativeMethods.jl_gc_queue_root(arrPtr);
        //}
        static bool JLIsEmpty(IntPtr arrPtr) => NativeMethods.jl_unbox_bool(NativeMethods.jl_call1(jl_isempty, arrPtr)) != 0;
        static void JLEmptyIt(IntPtr arrPtr) => NativeMethods.jl_call1(jl_empty_it, arrPtr);
        static bool JLHasShapes(IntPtr arrPtr) => arrPtr != IntPtr.Zero && !JLIsEmpty(arrPtr);
        static void JLDeleteShapes(IntPtr arrPtr) => NativeMethods.jl_call1(jl_delete_shapes, arrPtr);
        static void JLHighlightShapes(IntPtr arrPtr) => NativeMethods.jl_call1(jl_highlight_shapes, arrPtr);
        static void JLUnhighlightShapes(IntPtr arrPtr) => NativeMethods.jl_call1(jl_unhighlight_shapes, arrPtr);

        static string asString(IntPtr ptr) {
            //Julia uses UTF8 while C# uses UTF16
            IntPtr p = NativeMethods.jl_string_ptr(ptr);
            int len = 0;
            while (Marshal.ReadByte(p, len) != 0) { ++len; }
            byte[] buffer = new byte[len];
            Marshal.Copy(p, buffer, 0, buffer.Length);
            return Encoding.UTF8.GetString(buffer);
        }

        static IntPtr asJLString(String s) => NativeMethods.jl_cstr_to_string(s);

        static IntPtr asJLBool(bool b) => NativeMethods.jl_box_bool((byte)(b ? 1 : 0));
        static bool asBool(IntPtr ptr) => NativeMethods.jl_unbox_bool(ptr) != 0;

        static IntPtr asJLInt32(int d) => NativeMethods.jl_box_int32(d);
        static int asInt(IntPtr ptr) => NativeMethods.jl_unbox_int32(ptr);

        static IntPtr asJLInt64(long d) => NativeMethods.jl_box_int64(d);
        static long asLong(IntPtr ptr) => NativeMethods.jl_unbox_int64(ptr);

        static IntPtr asJLFloat64(double d) => NativeMethods.jl_box_float64(d);
        //static double asDouble(IntPtr ptr) => NativeMethods.jl_unbox_float64(ptr);
        static double asDouble(IntPtr ptr) =>
            JLIsaFloat64(ptr) ?
            NativeMethods.jl_unbox_float64(ptr) :
            JLIsaInt64(ptr) ?
            (double)NativeMethods.jl_unbox_int64(ptr) : // Convert missing to NaN
            JLIsaMssing(ptr) ?
            Double.NaN :
            NativeMethods.jl_unbox_float64(NativeMethods.jl_call1(jl_Float64, ptr));

        // HACK Improve performance by making a direct call
        static IntPtr asJLLoc(Point3d p) => JLEvaluate($"KhepriBase.xyz({p.X}, {p.Y}, {p.Z})");
        //static IntPtr asJLLoc(Point3d p) =>
        //    NativeMethods.jl_call3(
        //        jl_xyz,
        //        NativeMethods.jl_box_float64(p.X),
        //        NativeMethods.jl_box_float64(p.Y),
        //        NativeMethods.jl_box_float64(p.Z));
        static Point3d asPoint3d(IntPtr ptr) {
            //HACK: Most probably, must turn off GC
            IntPtr p = NativeMethods.jl_call1(jl_raw_point, ptr);
            CheckForException();
            return new Point3d(
                NativeMethods.jl_unbox_float64(p),
                NativeMethods.jl_unbox_float64(IntPtr.Add(p, word_size)),
                NativeMethods.jl_unbox_float64(IntPtr.Add(p, 2 * word_size)));
        }

        // HACK Improve performance by making a direct call
        static IntPtr asJLVec(Vector3d v) => JLEvaluate($"KhepriBase.vxyz({v.X}, {v.Y}, {v.Z})");
        static Vector3d asVector3d(IntPtr ptr) {
            //HACK: Most probably, must turn off GC
            IntPtr p = NativeMethods.jl_call1(jl_raw_point, ptr);
            CheckForException();
            return new Vector3d(
                NativeMethods.jl_unbox_float64(p),
                NativeMethods.jl_unbox_float64(IntPtr.Add(p, word_size)),
                NativeMethods.jl_unbox_float64(IntPtr.Add(p, 2 * word_size)));
        }
        static string asShow(IntPtr ptr) => asString(NativeMethods.jl_call1(jl_repr, ptr));
        static IntPtr asJLDynamic(Object obj) {
            if (obj is string) {
                return asJLString((string)obj);
            } else if (obj is bool) {
                return asJLBool((bool)obj);
            } else if (obj is long) {
                return asJLInt64((long)obj);
            } else if (obj is double) {
                return asJLFloat64((double)obj);
            } else if (obj is Point3d) {
                return asJLLoc((Point3d)obj);
            } else if (obj is Vector3d) {
                return asJLVec((Vector3d)obj);
            } else if (obj is IntPtr) {
                return (IntPtr)obj;
            } else {
                throw new Exception("Unknown type of object:" + obj);
            }
        }
        static Object asObject(IntPtr ptr) {
            if (JLIsaString(ptr)) {
                return asString(ptr);
            } else if (JLIsaBool(ptr)) {
                return asBool(ptr);
            } else if (JLIsaInt64(ptr)) {
                return asLong(ptr);
            } else if (JLIsaFloat64(ptr)) {
                return asDouble(ptr);
            } else if (JLIsaXYZ(ptr)) {
                return asPoint3d(ptr);
            } else if (JLIsaVXYZ(ptr)) {
                return asVector3d(ptr);
            } else if (JLIsaNothing(ptr) || JLIsaMssing(ptr)) {
                return null;
            } else {
                // Opaque Julia value (e.g. a shape ref): pass the pointer through so
                // asJLDynamic can round-trip it back unchanged.
                return ptr;
            }
        }
        static List<T> asTypes<T>(Func<IntPtr, T> func, IntPtr arrPtr) {
            List<T> data = new List<T>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(func(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<string> asStrings(IntPtr arrPtr) => asTypes(asString, arrPtr);
        static List<bool> asBools(IntPtr arrPtr) => asTypes(asBool, arrPtr);
        static List<long> asLongs(IntPtr arrPtr) => asTypes(asLong, arrPtr);
        static List<double> asDoubles(IntPtr arrPtr) => asTypes(asDouble, arrPtr);
        static List<Point3d> asPoint3ds(IntPtr arrPtr) => asTypes(asPoint3d, arrPtr);
        static List<Vector3d> asVector3ds(IntPtr arrPtr) => asTypes(asVector3d, arrPtr);
        static List<IntPtr> asAnys(IntPtr arrPtr) => asTypes(p => p, arrPtr);
        static List<string> asShows(IntPtr arrPtr) => asTypes(asShow, arrPtr);
        static List<Object> asObjects(IntPtr arrPtr) => asTypes(asObject, arrPtr);

        static DataTree<T> asTypess<T>(Func<IntPtr, List<T>> func, IntPtr arrPtr) {
            DataTree<T> data = new DataTree<T>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.AddRange(func(JLGetIndex0(arrPtr, idx)), new GH_Path(0, idx));
            }
            return data;
        }
        static DataTree<string> asStringss(IntPtr arrPtr) => asTypess(asStrings, arrPtr);
        static DataTree<bool> asBoolss(IntPtr arrPtr) => asTypess(asBools, arrPtr);
        static DataTree<long> asLongss(IntPtr arrPtr) => asTypess(asLongs, arrPtr);
        static DataTree<double> asDoubless(IntPtr arrPtr) => asTypess(asDoubles, arrPtr);
        static DataTree<Point3d> asPoint3dss(IntPtr arrPtr) => asTypess(asPoint3ds, arrPtr);
        static DataTree<Vector3d> asVector3dss(IntPtr arrPtr) => asTypess(asVector3ds, arrPtr);
        static DataTree<IntPtr> asAnyss(IntPtr arrPtr) => asTypess(asAnys, arrPtr);
        static DataTree<string> asShowss(IntPtr arrPtr) => asTypess(asShows, arrPtr);
        static DataTree<Object> asObjectss(IntPtr arrPtr) => asTypess(asObjects, arrPtr);

        static bool JLHasCurrentBackend() => asBool(NativeMethods.jl_call0(jl_has_current_backend));

        // IO pattern
        static readonly string IOPattern =
            @"(?'var'\w*)\s*(?'dir'[<=>])\s*(?'func'\w+)\s*\(" +
            @"\s*""(?'desc'.+)""\s*," +
            @"\s*""(?'shortdesc'.+)""\s*," +
            @"\s*""(?'message'.+)""\s*," +
            @"\s*:(?'access'\w+)\s*" +
            @"(,\s*(?'value'.+)\s*)?\)";

        // Predefined scripts
        static string scriptBase = @"# Title
# v < Type(""Input"", ""I"", ""Parameter I"", default)
a < Number()
b < Number()
_ > Number()

sqrt(a^2 + b^2)
";

        /*static string scriptXYPol = @"
pt < Point(""Point"", ""P"", ""Input Point"", :item, xy(1,0))
r  > Number(""Radius"", ""R"", ""Radius of polar coordinates"", :item)
a  > Number(""Angle"", ""A"", ""Angle of polar coordinates"", :item)

r = pol_rho(pt)
a = pol_phi(pt)";
        static string scriptRenata = @"
b  < JLEval(""Backend"", ""B"", ""Backend to use"", :item, autocad)
e  < Integer(""Edges"", ""N"", ""Number of edges"", :item, 5)
bc < Point(""Base Center"", ""BP"", ""Base center"", :item)
br < Number(""Base Radius"", ""BR"", ""Base radius"", :item, 2.0)
tc < Point(""Top Center"", ""TP"", ""Top center"", :item, xyz(1,2,3))
tr < Number(""Top Radius"", ""TR"", ""Top radius"", :item, 1.0)
a  < Number(""Angle"", ""A"", ""Angle"", :item, 0.0)
backend(b)
regular_pyramid_frustum(e, bc, br, a, tc, tr)
cylinder(tc, tr, tc+(tc-bc))";
*/
        private static int counter = 0;
        public int LocalId {
            get;
        }

        private readonly string codeKey = "KhepriCode";
        private IntPtr docInps;
        private IntPtr docOuts;
        private IntPtr inps;
        private IntPtr outs;
        private IntPtr func;
        private IntPtr tracing_func;
        private IntPtr shapes = IntPtr.Zero;

        //private static bool ReverseTraceabilityActive = false;

        List<Func<IGH_DataAccess, IntPtr, bool>> toJLConverters = new List<Func<IGH_DataAccess, IntPtr, bool>>();
        List<Action<IGH_DataAccess, IntPtr>> fromJLConverters = new List<Action<IGH_DataAccess, IntPtr>>();
        private JuliaEditor editor = null;
        // "Edit in Editor" external-edit session: one watcher + temp file per component,
        // torn down before a new session and on removal so repeated clicks do not leak
        // watchers or temp files.
        private FileSystemWatcher editWatcher = null;
        private string editTempPath = null;
        private static System.Timers.Timer aTimer;

        private void SetTimer() {
            aTimer = new System.Timers.Timer(1000);
            aTimer.Enabled = true;
            aTimer.AutoReset = true;
            //aTimer.Elapsed += OnTimeEvent;
        }
        private void EnableTimer(bool state) =>
            aTimer.Enabled = state;

        private string script = scriptBase;

        public string Script {
            get {
                return script;
            }
            set {
                script = value;
                try {
                    ParseJuliaProgram(script);
                    Params.OnParametersChanged();
                    //Is this the best place to do this? It will be repeatedly done...
                    Instances.ActiveCanvas.Document.SolutionEnd += Document_SolutionEnd;
                    if (ForDefinitions()) {
                        foreach (IGH_DocumentObject obj in Instances.ActiveCanvas.Document.Objects) {
                            if ((obj is KhepriComponent) && (obj != this)) {
                                obj.ExpireSolution(true);
                            }
                        }
                    } else {
                        ExpireSolution(true);
                    }
                } catch (Exception e) {
                    AddRuntimeMessage(GH_RuntimeMessageLevel.Error, e.Message);
                    JLInfo("Error in the code: " + e.Message);
                }
                string info = RelevantText(script);
                if (NickName == "Khepri") {
                    NickName = FractionText(info, 10);
                }
                Message = FractionText(info, 20);
                Description = FractionText(info, 50);
                Instances.RedrawCanvas();
            }
        }

        static string FractionText(string txt, int length) =>
            (txt.Length <= length) ? txt : txt.Substring(0, length - 3) + "...";

        static string RelevantText(string script) {
            MatchCollection ms = Regex.Matches(script, IOPattern);
            if (ms.Count == 0) {
                return script.Trim();
            } else {
                Match lastMatch = ms[ms.Count - 1];
                return script.Substring(lastMatch.Index + lastMatch.Length).Trim();
            }
        }

        public bool ForDefinitions() =>
             toJLConverters.Count == 0 && fromJLConverters.Count == 0;

        static readonly Regex JuliaVersionPattern =
            new Regex(@"^(?:Julia[- ]?|julia-)([0-9]+(?:\.[0-9]+){0,3})", RegexOptions.IgnoreCase);

        static readonly string[] JuliaBinEnvironmentVariables = {
            "KHEPRI_JULIA_BINDIR",
            "JULIA_BINDIR"
        };

        static string FindJuliaBinDirectory() =>
            CandidateJuliaBinDirectories()
                .Select(NormalizeJuliaBinDirectory)
                .FirstOrDefault(IsJuliaBinDirectory);

        static IEnumerable<string> CandidateJuliaBinDirectories() {
            foreach (string variable in JuliaBinEnvironmentVariables) {
                string value = Environment.GetEnvironmentVariable(variable);
                if (!string.IsNullOrWhiteSpace(value)) {
                    yield return value;
                }
            }

            string juliaDirectory = Environment.GetEnvironmentVariable("JULIA_DIR");
            if (!string.IsNullOrWhiteSpace(juliaDirectory)) {
                yield return Path.Combine(juliaDirectory, "bin");
            }

            foreach (string root in JuliaInstallRoots()) {
                foreach (string directory in VersionedJuliaDirectories(root)) {
                    yield return Path.Combine(directory, "bin");
                }
            }

            string path = Environment.GetEnvironmentVariable("PATH") ?? "";
            foreach (string entry in path.Split(Path.PathSeparator)) {
                if (!string.IsNullOrWhiteSpace(entry)) {
                    yield return entry;
                }
            }
        }

        static IEnumerable<string> JuliaInstallRoots() {
            string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            if (string.IsNullOrWhiteSpace(userProfile)) {
                userProfile = Environment.GetEnvironmentVariable("USERPROFILE");
            }

            yield return Path.Combine(userProfile ?? "", @".julia\juliaup");
            yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs");
            yield return Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            yield return Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        }

        static IEnumerable<string> VersionedJuliaDirectories(string root) {
            if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) {
                yield break;
            }

            foreach (var candidate in Directory.GetDirectories(root)
                .Select(directory => Tuple.Create(directory, JuliaVersionPattern.Match(Path.GetFileName(directory))))
                .Where(candidate => candidate.Item2.Success)
                .Select(candidate => Tuple.Create(candidate.Item1, ParseVersion(candidate.Item2.Groups[1].Value)))
                .Where(candidate => candidate.Item2 != null)
                .OrderByDescending(candidate => candidate.Item2)) {
                yield return candidate.Item1;
            }
        }

        static Version ParseVersion(string value) {
            Version version;
            return Version.TryParse(value, out version) ? version : null;
        }

        static string NormalizeJuliaBinDirectory(string directory) {
            if (string.IsNullOrWhiteSpace(directory)) {
                return null;
            }

            directory = directory.Trim().Trim('"');
            if (IsJuliaBinDirectory(directory)) {
                return Path.GetFullPath(directory);
            }

            return Path.GetFullPath(Path.Combine(directory, "bin"));
        }

        static bool IsJuliaBinDirectory(string directory) =>
            !string.IsNullOrWhiteSpace(directory)
            && Directory.Exists(directory)
            && File.Exists(Path.Combine(directory, "libjulia.dll"));

        static void LoadJuliaRuntime(string juliaBinDirectory) {
            string libJuliaPath = Path.Combine(juliaBinDirectory, "libjulia.dll");
            JLInfo($"Loading Julia runtime from {libJuliaPath}");

            if (!NativeMethods.SetDllDirectory(juliaBinDirectory)) {
                int error = Marshal.GetLastWin32Error();
                JLError($"Failed to add Julia bin directory to the DLL search path: {juliaBinDirectory} (Win32 error {error})");
            }

            if (NativeMethods.LoadLibrary(libJuliaPath) == IntPtr.Zero) {
                int error = Marshal.GetLastWin32Error();
                JLError($"Failed to load {libJuliaPath} (Win32 error {error}). Make sure Julia is installed for 64-bit Windows and its bin directory contains libjulia.dll.");
            }
        }

        static void UsePackage(string name, string package) {
            NativeMethods.jl_eval_string($"using {name}");
            if (NativeMethods.jl_exception_occurred() != IntPtr.Zero) {
                JLInfo($"Installing {name}...");
                NativeMethods.jl_eval_string("import Pkg");
                if (NativeMethods.jl_exception_occurred() != IntPtr.Zero) {
                    JLError($"Unable to use Julia's package manager. Please, install {name} in Julia!");
                } else {
                    NativeMethods.jl_eval_string($"Pkg.add({package})");
                    if (NativeMethods.jl_exception_occurred() != IntPtr.Zero) {
                        JLError($"Unable to install {name}. Please, install {name} in Julia!");
                    } else {
                        NativeMethods.jl_eval_string($"using {name}");
                        if (NativeMethods.jl_exception_occurred() != IntPtr.Zero) {
                            JLError($"Unable to use {name} after installing it. Please, install {name} in Julia!");
                        }
                    }
                }
            }
        }
        public KhepriComponent() : base("Khepri", "Khepri", "Allows the use of the Khepri portable API.", "Maths", "Script") {
            LocalId = counter++;
            if (!initialized) {
                string juliaBinDirectory = FindJuliaBinDirectory();
                if (juliaBinDirectory == null) {
                    JLError("Could not find libjulia.dll. Set KHEPRI_JULIA_BINDIR to Julia's bin directory.");
                } else {
                    LoadJuliaRuntime(juliaBinDirectory);
                    NativeMethods.jl_init();
                    DefineBase();
                    //We cannot yet use JLEvaluate because it depends on using Khepri
                    UsePackage("KhepriBase", "\"KhepriBase\"");
                    UsePackage("KhepriGrasshopper", "url=\"https://github.com/aptmcl/KhepriGrasshopper.jl\"");
                    //Now that we have KhepriGrasshopper we can rely on JLEvaluate
                    //JLEvaluate("KhepriGrasshopper.is_collecting_shapes(true)");
                    DefineKhepri();
                    externalEditor = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\Microsoft VS Code\Code.exe");
                    //Uncomment for Reverse Traceability
                    //SetTimer();
                    initialized = true;
                }
            }
        }

        internal void Document_SolutionEnd(object sender, GH_SolutionEventArgs e) {
        }

        bool HasShapes() => JLHasShapes(shapes);

        void EraseShapes() {
            if (JLHasShapes(shapes)) {
                JLDeleteShapes(shapes);
                CheckForException();
                JLEmptyIt(shapes);
            }
            CheckForException();
            //JLEvaluate($@"delete_shapes(__shapes{localId})");
        }

        public void HighlightShapes() {
            if (trace && JLHasShapes(shapes)) {
                JLHighlightShapes(shapes);
            }
            CheckForException();
        }
        public void UnhighlightShapes() {
            if (trace && JLHasShapes(shapes)) {
                JLUnhighlightShapes(shapes);
            }
            CheckForException();
        }

        static bool ContainsSelectedShape(int id) =>
            JLLength(JLEvaluate($@"KhepriBase.pre_selected_shapes_from_set(__shapes_{id})")) > 0;

        delegate void Highlighter(GH_Document document);
        /*
        private void OnTimeEvent(object source, ElapsedEventArgs e) {
            var editor = Instances.DocumentEditor;
            Highlighter func = KhepriComponent.HighlightSelectedShapes;
            if (Instances.ActiveCanvas != null &&
                Instances.ActiveCanvas.Document != null) {
                editor.Invoke(func, new object[] { Grasshopper.Instances.ActiveCanvas.Document });
            }
        }

        internal static void HighlightSelectedShapes(GH_Document document) {
            // To support reverse traceability, we look for selected shapes and we highlight the component that generated them
            if (ReverseTraceabilityActive) {
                if (document.Objects != null) {
                    foreach (IGH_DocumentObject obj in document.Objects) {
                        if (obj is KhepriComponent) {
                            if (ContainsSelectedShape((obj as KhepriComponent).LocalId)) {
                                obj.Attributes.Selected = true;
                            }
                        }
                    }
                }
                Instances.RedrawCanvas();
                //GH_InstanceServer.RegenCanvas();
            }
            // Now, direct traceability
            int[] ids = document.SelectedObjects().Where(o => o is KhepriComponent).Select(o => o as KhepriComponent).Where(k => k.HasShapes()).Select(k => k.LocalId).ToArray();
            HighlightShapes(ids);
        }
        */
        void ParseJuliaProgram(string text) {
            toJLConverters.Clear();
            fromJLConverters.Clear();
            //First, save previous inputs and output parameter names
            List<string> unusedInputNames = Params.Input.Select(p => p.Name).ToList();
            List<string> unusedOutputNames = Params.Output.Select(p => p.Name).ToList();
            JLEvaluate($"KhepriGrasshopper.define_kgh_function(\"{LocalId}\", raw\"\"\"{text}\"\"\")");
            func = JLEvaluate($"Main.__func_{LocalId}");
            tracing_func = JLEvaluate($"Main.__tracing_func_{LocalId}");
            docInps = JLEvaluate($"Main.__doc_inps_{LocalId}");
            docOuts = JLEvaluate($"Main.__doc_outs_{LocalId}");
            inps = JLEvaluate($"Main.__inps_{LocalId}");
            outs = JLEvaluate($"Main.__outs_{LocalId}");
            shapes = JLEvaluate($"Main.__shapes_{LocalId}");
            int inpsCount = JLLength(inps);
            int outsCount = JLLength(outs);
            for (int idx = 0; idx < inpsCount; idx++) {
                IntPtr doc = JLGetIndex0(docInps, idx);
                string type = asString(JLGetIndex0(doc, 0));
                string name = asString(JLGetIndex0(doc, 1));
                string shortdesc = asString(JLGetIndex0(doc, 2));
                string message = asString(JLGetIndex0(doc, 3));
                unusedInputNames.Remove(name);
                ParseToJL(
                    idx,
                    type,
                    name,
                    shortdesc,
                    message,
                    JLGetIndex0(doc, 4));
            }
            for (int idx = 0; idx < outsCount; idx++) {
                IntPtr doc = JLGetIndex0(docOuts, idx);
                string type = asString(JLGetIndex0(doc, 0));
                string name = asString(JLGetIndex0(doc, 1));
                string shortdesc = asString(JLGetIndex0(doc, 2));
                string message = asString(JLGetIndex0(doc, 3));
                unusedOutputNames.Remove(name);
                ParseFromJL(
                    idx,
                    type,
                    name,
                    shortdesc,
                    message);
            }
            //By convention, if there are neither inputs nor outputs, this is just a text file
            //and is evaluated at commit time.
            if (inpsCount == 0 && outsCount == 0) {
                JLEvaluate(text);
            } else {
            }
            //Finally, remove unused names
            foreach (string name in unusedInputNames) {
                Params.UnregisterInputParameter(Params.Input.Find(p => p.Name == name));
            }
            foreach (string name in unusedOutputNames) {
                Params.UnregisterOutputParameter(Params.Output.Find(p => p.Name == name));
            }
        }

        IGH_Param ParamTypeForFunction(string func, string desc, string shortdesc, string message) {
            IGH_Param param =
                func.In("String", "Strings", "Stringss", "Eval", "Evals", "Evalss") ? new Param_String() :
                func.In("Boolean", "Booleans", "Booleanss") ? new Param_Boolean() :
                func.In("Integer", "Integers", "Integerss") ? new Param_Integer() :
                func.In("Number", "Numbers", "Numberss") ? new Param_Number() :
                func.In("Point", "Points", "Pointss") ? new Param_Point() :
                func.In("Vector", "Vectors", "Vectorss") ? new Param_Vector() :
                func.In("Point", "Points", "Pointss") ? new Param_Point() :
                func.In("Path", "Paths", "Pathss") ? new Param_FilePath() :
                (IGH_Param)new Param_GenericObject();
            param.Name = desc;
            param.Access =
                func.In("Stringss", "Booleanss", "Integerss", "Numberss", "Pointss", "Vectorss", "Pathss", "Manies", "Evalss", "JLss") ?
                GH_ParamAccess.tree :
                func.In("Strings", "Booleans", "Integers", "Numbers", "Points", "Vectors", "Paths", "Many", "Evals", "JLs") ?
                GH_ParamAccess.list :
                GH_ParamAccess.item;
            param.Optional = true;
            param.NickName = shortdesc;
            param.Description = message;
            return param;
        }

        bool EqualParams(IGH_Param newParam, IGH_Param oldParam) =>
            newParam.GetType().Equals(oldParam.GetType()) &&
            newParam.Name.Equals(oldParam.Name) &&
            newParam.Access.Equals(oldParam.Access) &&
            newParam.Optional.Equals(oldParam.Optional) &&
            newParam.NickName.Equals(oldParam.NickName) &&
            newParam.Description.Equals(oldParam.Description);

        void ParseToJL(int i, string func, string desc, string shortdesc, string message, IntPtr value) {
            IGH_Param oldParam = Params.Input.Find(p => p.Name == desc);
            IGH_Param newParam = ParamTypeForFunction(func, desc, shortdesc, message);
            switch (func) {
                case "String":
                    toJLConverters.Add((da, ptr) => ToJLString(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_String)newParam).PersistentData.Append(new GH_String(asString(value)));
                    }
                    break;
                case "Path":
                    toJLConverters.Add((da, ptr) => ToJLString(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_FilePath)newParam).PersistentData.Append(new GH_String(asString(value)));
                    }
                    break;
                case "Boolean":
                    toJLConverters.Add((da, ptr) => ToJLBool(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_Boolean)newParam).PersistentData.Append(new GH_Boolean(asBool(value)));
                    }
                    break;
                case "Integer":
                    toJLConverters.Add((da, ptr) => ToJLInt64(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_Integer)newParam).PersistentData.Append(new GH_Integer(checked((int)asLong(value))));
                    }
                    break;
                case "Number":
                    toJLConverters.Add((da, ptr) => ToJLFloat64(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_Number)newParam).PersistentData.Append(new GH_Number(asDouble(value)));
                    }
                    break;
                case "Point":
                    toJLConverters.Add((da, ptr) => ToJLLoc(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_Point)newParam).PersistentData.Append(new GH_Point(asPoint3d(value)));
                    }
                    break;
                case "Vector":
                    toJLConverters.Add((da, ptr) => ToJLVec(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_Vector)newParam).PersistentData.Append(new GH_Vector(asVector3d(value)));
                    }
                    break;
                case "Any":
                    toJLConverters.Add((da, ptr) => ToJLAny(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        throw new Exception("Any cannot have default initialization: " + value);
                    }
                    break;
                case "Eval":
                    toJLConverters.Add((da, ptr) => ToJLEval(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        ((Param_String)newParam).PersistentData.Append(new GH_String(asString(value)));
                    }
                    break;
                case "JL":
                    toJLConverters.Add((da, ptr) => ToJL(i, da, ptr));
                    if (!JLIsaNothing(value)) {
                        throw new Exception("JL cannot have default initialization: " + value);
                    }
                    break;
                case "Strings":
                case "Paths":
                    toJLConverters.Add((da, ptr) => ToJLStrings(i, da, ptr));
                    break;
                case "Booleans":
                    toJLConverters.Add((da, ptr) => ToJLBools(i, da, ptr));
                    break;
                case "Integers":
                    toJLConverters.Add((da, ptr) => ToJLInt64s(i, da, ptr));
                    break;
                case "Numbers":
                    toJLConverters.Add((da, ptr) => ToJLFloat64s(i, da, ptr));
                    break;
                case "Points":
                    toJLConverters.Add((da, ptr) => ToJLLocs(i, da, ptr));
                    break;
                case "Vectors":
                    toJLConverters.Add((da, ptr) => ToJLVecs(i, da, ptr));
                    break;
                case "Many":
                    toJLConverters.Add((da, ptr) => ToJLAnys(i, da, ptr));
                    break;
                case "Evals":
                    toJLConverters.Add((da, ptr) => ToJLEvals(i, da, ptr));
                    break;
                case "JLs":
                    toJLConverters.Add((da, ptr) => ToJLs(i, da, ptr));
                    break;
                case "Pathss":
                    toJLConverters.Add((da, ptr) => ToJLStringss(i, da, ptr));
                    break;
                case "Booleanss":
                    toJLConverters.Add((da, ptr) => ToJLBoolss(i, da, ptr));
                    break;
                case "Integerss":
                    toJLConverters.Add((da, ptr) => ToJLInt64ss(i, da, ptr));
                    break;
                case "Numberss":
                    toJLConverters.Add((da, ptr) => ToJLFloat64ss(i, da, ptr));
                    break;
                case "Pointss":
                    toJLConverters.Add((da, ptr) => ToJLLocss(i, da, ptr));
                    break;
                case "Vectorss":
                    toJLConverters.Add((da, ptr) => ToJLVecss(i, da, ptr));
                    break;
                case "Manies":
                    toJLConverters.Add((da, ptr) => ToJLAnyss(i, da, ptr));
                    break;
                case "Evalss":
                    toJLConverters.Add((da, ptr) => ToJLEvalss(i, da, ptr));
                    break;
                case "JLss":
                    toJLConverters.Add((da, ptr) => ToJLss(i, da, ptr));
                    break;

                default:
                    throw new Exception("Unknown function: " + func);
            }
            if (oldParam == null) {
                Params.RegisterInputParam(newParam, i);
            } else if (!EqualParams(newParam, oldParam)) {
                Params.UnregisterInputParameter(oldParam);
                foreach (IGH_Param source in oldParam.Sources) {
                    newParam.AddSource(source);
                }
                Params.RegisterInputParam(newParam, i);
            }
        }

        void ParseFromJL(int i, string func, string desc, string shortdesc, string message) {
            IGH_Param oldParam = Params.Output.Find(p => p.Name == desc);
            IGH_Param newParam = ParamTypeForFunction(func, desc, shortdesc, message);
            switch (func) {
                case "String":
                case "Path":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asString(JLGetIndex0(ptr, i))));
                    break;
                case "Boolean":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asBool(JLGetIndex0(ptr, i))));
                    break;
                case "Integer":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, checked((int)asLong(JLGetIndex0(ptr, i)))));
                    break;
                case "Number":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asDouble(JLGetIndex0(ptr, i))));
                    break;
                case "Point":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asPoint3d(JLGetIndex0(ptr, i))));
                    break;
                case "Vector":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asVector3d(JLGetIndex0(ptr, i))));
                    break;
                case "Any":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, new GH_ObjectWrapper(asObject(JLGetIndex0(ptr, i)))));
                    break;
                case "Eval":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asShow(JLGetIndex0(ptr, i))));
                    break;
                case "JL":
                    fromJLConverters.Add((da, ptr) => da.SetData(i, new GH_ObjectWrapper(JLGetIndex0(ptr, i))));
                    break;
                case "Strings":
                case "Paths":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asStrings(JLGetIndex0(ptr, i))));
                    break;
                case "Booleans":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asBools(JLGetIndex0(ptr, i))));
                    break;
                case "Integers":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asLongs(JLGetIndex0(ptr, i))));
                    break;
                case "Numbers":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asDoubles(JLGetIndex0(ptr, i))));
                    break;
                case "Points":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asPoint3ds(JLGetIndex0(ptr, i))));
                    break;
                case "Vectors":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asVector3ds(JLGetIndex0(ptr, i))));
                    break;
                case "Many":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asObjects(JLGetIndex0(ptr, i))));
                    break;
                case "Evals":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asShows(JLGetIndex0(ptr, i))));
                    break;
                case "JLs":
                    fromJLConverters.Add((da, ptr) => da.SetDataList(i, asAnys(JLGetIndex0(ptr, i))));
                    break;
                case "Stringss":
                case "Pathss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asStringss(JLGetIndex0(ptr, i))));
                    break;
                case "Booleanss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asBoolss(JLGetIndex0(ptr, i))));
                    break;
                case "Integerss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asLongss(JLGetIndex0(ptr, i))));
                    break;
                case "Numberss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asDoubless(JLGetIndex0(ptr, i))));
                    break;
                case "Pointss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asPoint3dss(JLGetIndex0(ptr, i))));
                    break;
                case "Vectorss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asVector3dss(JLGetIndex0(ptr, i))));
                    break;
                case "Manies":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asObjectss(JLGetIndex0(ptr, i))));
                    break;
                case "Evalss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asShowss(JLGetIndex0(ptr, i))));
                    break;
                case "JLss":
                    fromJLConverters.Add((da, ptr) => da.SetDataTree(i, asAnyss(JLGetIndex0(ptr, i))));
                    break;
                default:
                    throw new Exception("Unknown function: " + func);
            }
            if (oldParam == null) {
                Params.RegisterOutputParam(newParam, i);
            } else if (!EqualParams(newParam, oldParam)) {
                Params.UnregisterOutputParameter(oldParam);
                List<IGH_Param> oldRecipients = new List<IGH_Param>(oldParam.Recipients);
                foreach (IGH_Param recipient in oldRecipients) {
                    recipient.AddSource(newParam);
                }
                Params.RegisterOutputParam(newParam, i);
            }
        }

        //Converters from Grasshopper to Khepri
        bool ToJL<T>(Func<T, IntPtr> asJL, T data, int i, IGH_DataAccess DA, IntPtr arrPtr) {
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJL(data), i);
            return true;
        }
        bool ToJLString(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(asJLString, "", i, DA, arrPtr);
        bool ToJLBool(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(asJLBool, false, i, DA, arrPtr);
        bool ToJLInt64(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(x => asJLInt64(x), 0, i, DA, arrPtr);
        bool ToJLFloat64(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(asJLFloat64, 0.0, i, DA, arrPtr);
        bool ToJLLoc(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(asJLLoc, Point3d.Origin, i, DA, arrPtr);
        bool ToJLVec(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(asJLVec, Vector3d.Zero, i, DA, arrPtr);
        bool ToJLEval(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(JLEvaluate, "", i, DA, arrPtr);
        bool ToJL(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(x => (IntPtr)x.Value, (GH_ObjectWrapper)null, i, DA, arrPtr);
        bool ToJLAny(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJL(x => asJLDynamic(x.Value), (GH_ObjectWrapper)null, i, DA, arrPtr);

        bool IsProperList(int i, IGH_DataAccess DA) {
            List<Object> test = new List<Object>();
            return (DA.GetDataList(i, test) && DA.Util_CountNullRefs(test) == 0);
        }
        bool ToJLTypes<T>(Func<T, IntPtr> asJL, string type, int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<T> data = new List<T>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data)) {
                IntPtr vals = JLEvaluate($"Array{{{type}, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJL(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLStrings(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<string>(asJLString, "String", i, DA, arrPtr);
        bool ToJLBools(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<bool>(asJLBool, "Bool", i, DA, arrPtr);
        bool ToJLInt64s(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<int>(x => asJLInt64(x), "Int64", i, DA, arrPtr);
        bool ToJLFloat64s(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<double>(asJLFloat64, "Float64", i, DA, arrPtr);
        bool ToJLLocs(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<Point3d>(asJLLoc, "KhepriBase.Loc", i, DA, arrPtr);
        bool ToJLVecs(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<Vector3d>(asJLVec, "KhepriBase.Vec", i, DA, arrPtr);
        bool ToJLs(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<GH_ObjectWrapper>(x => (IntPtr)x.Value, "Any", i, DA, arrPtr);
        bool ToJLEvals(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<string>(JLEvaluate, "Any", i, DA, arrPtr);
        bool ToJLAnys(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypes<GH_ObjectWrapper>(x => asJLDynamic(x.Value), "Any", i, DA, arrPtr);

        bool ToJLTypess<T,GT>(Func<T, IntPtr> asJL, string type, int i, IGH_DataAccess DA, IntPtr arrPtr) where GT : IGH_Goo {
            if (DA.GetDataTree(i, out GH_Structure<GT> data)) {
                IntPtr vals = JLEvaluate($"Array{{Array{{{type}, 1}}, 1}}(undef, {data.Paths.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Paths.Count; j++) {
                    GH_Path pth = data.Paths[j];
                    IntPtr subvals = JLEvaluate($"Array{{{type}, 1}}(undef, {data[pth].Count})");
                    JLSetIndex0(vals, subvals, j); //To prevent GC from collecting
                    for (int k = 0; k < data[pth].Count; k++) {
                        data[pth][k].CastTo(out T val);
                        JLSetIndex0(subvals, asJL(val), k);
                    }
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLStringss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<string, GH_String>(asJLString, "String", i, DA, arrPtr);
        bool ToJLBoolss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<bool, GH_Boolean>(asJLBool, "Bool", i, DA, arrPtr);
        bool ToJLInt64ss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<int, GH_Integer>(x => asJLInt64(x), "Int64", i, DA, arrPtr);
        bool ToJLFloat64ss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<double, GH_Number>(asJLFloat64, "Float64", i, DA, arrPtr);
        bool ToJLLocss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<Point3d, GH_Point>(asJLLoc, "KhepriBase.Loc", i, DA, arrPtr);
        bool ToJLVecss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<Vector3d, GH_Vector>(asJLVec, "KhepriBase.Vec", i, DA, arrPtr);
        bool ToJLss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<IntPtr, IGH_Goo>(x => x, "Any", i, DA, arrPtr);
        bool ToJLEvalss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<string, GH_String>(JLEvaluate, "Any", i, DA, arrPtr);
        bool ToJLAnyss(int i, IGH_DataAccess DA, IntPtr arrPtr) => ToJLTypess<Object, IGH_Goo>(asJLDynamic, "Any", i, DA, arrPtr);

        protected override void BeforeSolveInstance() {
            EraseShapes();
        }

        protected override void SolveInstance(IGH_DataAccess DA) {
            if (func != IntPtr.Zero) {
                if (toJLConverters.All(conv => conv(DA, inps))) {
                    NativeMethods.jl_call0(trace ? tracing_func : func);
                    CheckForException();
                    foreach (var conv in fromJLConverters) {
                        conv(DA, outs);
                    }
                }
            }
        }

        protected override void AfterSolveInstance() {
            if (Attributes.Selected) {
                HighlightShapes();
            }
        }
        public override void RemovedFromDocument(GH_Document document) {
            EraseShapes();
            if (editor != null) {
                editor.Dispose();
            }
            DisposeEditWatcher();
            base.RemovedFromDocument(document);
        }

        public bool CanInsertParameter(GH_ParameterSide side, int index) {
            return false;
        }
        public bool CanRemoveParameter(GH_ParameterSide side, int index) {
            return false;
        }
        public bool DestroyParameter(GH_ParameterSide side, int index) {
            return false;
        }
        public IGH_Param CreateParameter(GH_ParameterSide side, int index) {
            return new Param_Boolean();
        }
        public void VariableParameterMaintenance() {
            try {
                ParseJuliaProgram(script);
            } catch (Exception e) {
                //Do nothing, user will have to fix this manually
                AddRuntimeMessage(GH_RuntimeMessageLevel.Error, e.Message);
                JLInfo("Error in the code: " + e.Message);
            }
        }

        protected override void RegisterInputParams(GH_InputParamManager pManager) {
        }

        protected override void RegisterOutputParams(GH_OutputParamManager pManager) {
        }

        protected override void AppendAdditionalComponentMenuItems(ToolStripDropDown menu) {
            ToolStripMenuItem item;
            item = Menu_AppendItem(menu, "Edit in Editor", (sender, e) => Menu_EditInEditorClicked(menu));
            item.ToolTipText = "Edit the code in a dedicated editor.";
            item = Menu_AppendItem(menu, "Toggle Traceability", (sender, e) => Menu_ToggleTraceabilityClicked(menu));
            item.ToolTipText = "Toggle traceability.";
            item = Menu_AppendItem(menu, "Debug", (sender, e) => Menu_ToggleDebugClicked(menu));
            item.ToolTipText = "Toggle debug.";
        }

        public override void CreateAttributes() {
            m_attributes = new JuliaEditorAttribute(this);
        }

        internal void EditScript() {
            if (editor == null) {
                editor = new JuliaEditor();
            }
            editor.EditScript(this);
            editor.Show(Grasshopper.Instances.DocumentEditor);
        }

        private void Menu_EditInEditorClicked(ToolStripDropDown menu) {
            // Tear down any previous external-edit session so repeated clicks do not
            // accumulate watchers/temp files.
            DisposeEditWatcher();
            // Dump contents on file
            string path = Path.ChangeExtension(Path.GetTempFileName(), "jl");
            File.WriteAllText(path, script);
            editTempPath = path;
            // Create a new FileSystemWatcher and set its properties.
            FileSystemWatcher watcher = new FileSystemWatcher {
                Path = Path.GetDirectoryName(path),
                Filter = Path.GetFileName(path),
                NotifyFilter = NotifyFilters.LastWrite
            };
            // Add event handlers.
            watcher.Changed += new FileSystemEventHandler((source, e) => {
                menu.Invoke(new Action(() => {
                    //Unfortunately, Windows is stupid and the file might
                    //still be locked when the watcher is informed
                    for (int numTries = 0; numTries < 10; numTries++) {
                        try {
                            Script = File.ReadAllText(path);
                            break;
                        } catch (IOException) {
                            Thread.Sleep(50);
                        }
                    }
                }));
            });
            // Begin watching.
            watcher.EnableRaisingEvents = true;
            editWatcher = watcher;
            Process.Start(externalEditor, path);
        }

        // Disposes the active external-edit watcher and deletes its temp file, if any.
        private void DisposeEditWatcher() {
            if (editWatcher != null) {
                editWatcher.EnableRaisingEvents = false;
                editWatcher.Dispose();
                editWatcher = null;
            }
            if (editTempPath != null) {
                try {
                    if (File.Exists(editTempPath)) {
                        File.Delete(editTempPath);
                    }
                } catch (IOException) {
                    // Best-effort: the editor may still hold the file; leave it to the OS.
                }
                editTempPath = null;
            }
        }

        private void Menu_ToggleTraceabilityClicked(ToolStripDropDown menu) {
            trace = !trace;
        }

        private void Menu_ToggleDebugClicked(ToolStripDropDown menu) {
            debug = !debug;
        }

        public override bool Write(GH_IO.Serialization.GH_IWriter writer) {
            writer.SetString(codeKey, script);
            return base.Write(writer);
        }
        public override bool Read(GH_IO.Serialization.GH_IReader reader) {
            if (reader.ItemExists(codeKey)) {
                script = reader.GetString(codeKey);
            }
            return base.Read(reader);
        }

        /// The Exposure property controls where in the panel a component icon 
        /// will appear. There are seven possible locations (primary to septenary), 
        /// each of which can be combined with the GH_Exposure.obscure flag, which 
        /// ensures the component will only be visible on panel dropdowns.
        /// </summary>
        public override GH_Exposure Exposure {
            get {
                return GH_Exposure.primary;
            }
        }

        /// <summary>
        /// Provides an Icon for every component that will be visible in the User Interface.
        /// Icons need to be 24x24 pixels.
        /// </summary>
        protected override System.Drawing.Bitmap Icon {
            get {
                return Properties.Resources.KhepriGHIcon;
            }
        }

        /// <summary>
        /// Each component must have a unique Guid to identify it. 
        /// It is vital this Guid doesn't change otherwise old ghx files 
        /// that use the old ID will partially fail during loading.
        /// </summary>
        public override Guid ComponentGuid {
            get {
                return new Guid("cf519637-6e7c-4bd3-ba48-891ca984f5cc");
            }
        }
    }

    class JuliaEditorAttribute : GH_ComponentAttributes {

        KhepriComponent component;

        public JuliaEditorAttribute(KhepriComponent owner) : base(owner) {
            this.component = owner;
        }

        public override GH_ObjectResponse RespondToMouseDoubleClick(GH_Canvas sender, GH_CanvasMouseEvent e) {
            component.EditScript();
            return base.RespondToMouseDoubleClick(sender, e);
        }

        public override bool Selected {
            get {
                return base.Selected;
            }
            set {
                base.Selected = value;
                if (value) {
                    component.HighlightShapes();
                } else {
                    component.UnhighlightShapes();
                }
            }
        }
    }
}
