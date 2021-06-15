using System;
using System.Collections.Generic;

using Grasshopper.Kernel;
using Grasshopper.Kernel.Parameters;
using Grasshopper.Kernel.Types;
using Rhino.Geometry;
using System.Diagnostics;

using System.Runtime.InteropServices;
using System.IO;
using System.Windows.Forms;
using Rhino;
using System.Threading;
using System.Text.RegularExpressions;
using System.Linq;
using Grasshopper.Kernel.Attributes;
using Grasshopper.GUI.Canvas;
using Grasshopper.GUI;
using System.ComponentModel;
using System.Timers;
using Grasshopper;
using System.Text;

namespace KhepriGrasshopper {

    public static class Ext {
        public static bool In<T>(this T t, params T[] values) {
            return values.Contains(t);
        }
    }

    internal static class NativeMethods {
        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern bool SetDllDirectory(string lpPathName);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void jl_init__threading();

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_eval_string(string input);

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

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_arrayref(IntPtr a, UInt64 i); //0-indexed

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void jl_arrayset(IntPtr a, IntPtr v, UInt64 i); //0-indexed

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern UInt64 jl_array_size(IntPtr a, int d);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_string_ptr(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_typeof_str(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern Int32 jl_isa(IntPtr value, IntPtr type);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr jl_get_global(IntPtr module, string name);

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
        private static string atomExec;

        static void JLError(string msg) {
            JLInfo($"Julia error: {msg}");
            throw new Exception($"Julia error: {msg}");
        }

        static void JLInfo(string msg) {
            RhinoApp.WriteLine($"Julia info: {msg}");
        }

        static IntPtr JLEvaluate(string expr) {
            //For debug: JLInfo(expr);
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
        static IntPtr jl_length;
        static IntPtr jl_getindex;
        static IntPtr jl_setindex;
        static IntPtr jl_sprint;
        static IntPtr jl_repr;
        static IntPtr jl_showerror;
        static IntPtr jl_errormsg;
        static IntPtr jl_xyz;
        static IntPtr jl_vxyz;
        static IntPtr jl_cx;
        static IntPtr jl_cy;
        static IntPtr jl_cz;
        static IntPtr jl_circle;
        static IntPtr jl_circle_center;
        static IntPtr jl_circle_radius;
        static IntPtr jl_raw_point;
        static IntPtr jl_raw_plane;
        static IntPtr jl_has_current_backend;
        static IntPtr jl_Nothing;
        static IntPtr jl_Float64;
        static IntPtr jl_Int64;
        static IntPtr jl_String;
        static IntPtr jl_Bool;
        static IntPtr jl_XYZ;
        static IntPtr jl_VXYZ;

        static void DefineJuliaFunctions() {
            jl_length = JLGetFunction("Base.length");
            jl_getindex = JLGetFunction("Base.getindex");
            jl_setindex = JLGetFunction("Base.setindex!");
            jl_sprint = JLGetFunction("Base.sprint");
            jl_repr = JLGetFunction("Base.repr");
            jl_showerror = JLGetFunction("Base.showerror");
            jl_errormsg = JLGetFunction("Khepri.errormsg");
            jl_xyz = JLGetFunction("Khepri.xyz");
            jl_vxyz = JLGetFunction("Khepri.vxyz");
            jl_cx = JLGetFunction("Khepri.cx");
            jl_cy = JLGetFunction("Khepri.cy");
            jl_cz = JLGetFunction("Khepri.cz");
            jl_circle = JLGetFunction("Khepri.circle");
            jl_circle_center = JLGetFunction("Khepri.circle_center");
            jl_circle_radius = JLGetFunction("Khepri.circle_radius");
            jl_raw_point = JLGetFunction("Khepri.raw_point");
            jl_raw_plane = JLGetFunction("Khepri.raw_plane");
            jl_has_current_backend = JLGetFunction("Khepri.has_current_backend");
            jl_Nothing = JLEvaluate("Base.Nothing");
            jl_Float64 = JLEvaluate("Base.Float64");
            jl_Int64 = JLEvaluate("Base.Int64");
            jl_String = JLEvaluate("Base.String");
            jl_Bool = JLEvaluate("Base.Bool");
            jl_XYZ = JLEvaluate("Khepri.XYZ");
            jl_VXYZ = JLEvaluate("Khepri.VXYZ");
        }
        static bool JLIsaNothing(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Nothing) != 0;
        static bool JLIsaFloat64(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Float64) != 0;
        static bool JLIsaInt64(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Int64) != 0;
        static bool JLIsaBool(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_Bool) != 0;
        static bool JLIsaString(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_String) != 0;
        static bool JLIsaXYZ(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_XYZ) != 0;
        static bool JLIsaVXYZ(IntPtr ptr) => NativeMethods.jl_isa(ptr, jl_VXYZ) != 0;

        static int JLLength(IntPtr arrPtr) => (int)NativeMethods.jl_array_size(arrPtr, 1);
        //(int)NativeMethods.jl_unbox_int64(NativeMethods.jl_call1(jl_length, arrPtr));
        static IntPtr JLGetIndex0(IntPtr arrPtr, int idx) => NativeMethods.jl_arrayref(arrPtr, (UInt64)idx);
        //Julia arrays are indexed starting from 1
        //NativeMethods.jl_call2(jl_getindex, arrPtr, NativeMethods.jl_box_int64(idx + 1));
        static void JLSetIndex0(IntPtr arrPtr, IntPtr valPtr, int idx) => NativeMethods.jl_arrayset(arrPtr, valPtr, (UInt64)idx);
            //Julia arrays are indexed starting from 1
            //NativeMethods.jl_call3(jl_setindex, arrPtr, valPtr, NativeMethods.jl_box_int64(idx + 1));

        // HACK: Find a better approach for this
        static IntPtr asJLString(string s) => JLEvaluate($"raw\"\"\"{s}\"\"\"");
        static string asString(IntPtr ptr) {
            //Julia uses UTF8 while C# uses UTF16
            IntPtr p = NativeMethods.jl_string_ptr(ptr);
            int len = 0;
            while (Marshal.ReadByte(p, len) != 0) { ++len; }
            byte[] buffer = new byte[len];
            Marshal.Copy(p, buffer, 0, buffer.Length);
            return Encoding.UTF8.GetString(buffer);
        }
        //=> Marshal.PtrToStringUni(NativeMethods.jl_string_ptr(ptr));

        static IntPtr asJLBool(bool b) => NativeMethods.jl_box_bool((byte)(b ? 1 : 0));
        static bool asBool(IntPtr ptr) => NativeMethods.jl_unbox_bool(ptr) != 0;

        static IntPtr asJLInt32(int d) => NativeMethods.jl_box_int32(d);
        static int asInt(IntPtr ptr) => NativeMethods.jl_unbox_int32(ptr);

        static IntPtr asJLInt64(long d) => NativeMethods.jl_box_int64(d);
        static long asLong(IntPtr ptr) => NativeMethods.jl_unbox_int64(ptr);

        static IntPtr asJLFloat64(double d) => NativeMethods.jl_box_float64(d);
        //static double asDouble(IntPtr ptr) => NativeMethods.jl_unbox_float64(ptr);
        static double asDouble(IntPtr ptr) =>
            JLIsaInt64(ptr) ?
            (double)NativeMethods.jl_unbox_int64(ptr) :
            NativeMethods.jl_unbox_float64(ptr);

        // HACK Improve performance by making a direct call
        static IntPtr asJLLoc(Point3d p) => JLEvaluate($"Khepri.xyz({p.X}, {p.Y}, {p.Z})");
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
        static IntPtr asJLVec(Vector3d v) => JLEvaluate($"Khepri.vxyz({v.X}, {v.Y}, {v.Z})");
        static Vector3d asVector3d(IntPtr ptr) {
            //HACK: Most probably, must turn off GC
            IntPtr p = NativeMethods.jl_call1(jl_raw_point, ptr);
            CheckForException();
            return new Vector3d(
                NativeMethods.jl_unbox_float64(p),
                NativeMethods.jl_unbox_float64(IntPtr.Add(p, word_size)),
                NativeMethods.jl_unbox_float64(IntPtr.Add(p, 2 * word_size)));
        }

        static Plane PlaneFromJLLoc(IntPtr ptr) {
            //HACK: Most probably, must turn off GC
            IntPtr p = NativeMethods.jl_call1(jl_raw_plane, ptr);
            Point3d o = asPoint3d(p);
            Vector3d vx = asVector3d(IntPtr.Add(p, 3 * word_size));
            Vector3d vy = asVector3d(IntPtr.Add(p, 6 * word_size));
            return new Plane(o, vx, vy);
        }
        static string asShow(IntPtr ptr) =>
            asString(NativeMethods.jl_call1(jl_repr, ptr));
        static IntPtr asEval(string expr) =>
            JLEvaluate(expr);

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
            } else {
                return ptr;
            }
        }

        static List<string> asStrings(IntPtr arrPtr) {
            List<string> data = new List<string>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asString(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<bool> asBools(IntPtr arrPtr) {
            List<bool> data = new List<bool>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asBool(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<long> asLongs(IntPtr arrPtr) {
            List<long> data = new List<long>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asLong(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<double> asDoubles(IntPtr arrPtr) {
            List<double> data = new List<double>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asDouble(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<Point3d> asPoint3ds(IntPtr arrPtr) {
            List<Point3d> data = new List<Point3d>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asPoint3d(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<Vector3d> asVector3ds(IntPtr arrPtr) {
            List<Vector3d> data = new List<Vector3d>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asVector3d(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<IntPtr> asAnys(IntPtr arrPtr) {
            List<IntPtr> data = new List<IntPtr>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(JLGetIndex0(arrPtr, idx));
            }
            return data;
        }
        static List<string> asShows(IntPtr arrPtr) {
            List<string> data = new List<string>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asShow(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }
        static List<Object> asObjects(IntPtr arrPtr) {
            List<Object> data = new List<Object>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asObject(JLGetIndex0(arrPtr, idx)));
            }
            return data;
        }

        static bool JLHasCurrentBackend() =>
            asBool(NativeMethods.jl_call0(jl_has_current_backend));

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

sqrt(a^2 + b^2)";

        /*static string scriptXYPol = @"
pt < GHPoint(""Point"", ""P"", ""Input Point"", :item, xy(1,0))
r  > GHNumber(""Radius"", ""R"", ""Radius of polar coordinates"", :item)
a  > GHNumber(""Angle"", ""A"", ""Angle of polar coordinates"", :item)

r = pol_rho(pt)
a = pol_phi(pt)";
        static string scriptRenata = @"
b  < JLEval(""Backend"", ""B"", ""Backend to use"", :item, autocad)
e  < GHInteger(""Edges"", ""N"", ""Number of edges"", :item, 5)
bc < GHPoint(""Base Center"", ""BP"", ""Base center"", :item)
br < GHNumber(""Base Radius"", ""BR"", ""Base radius"", :item, 2.0)
tc < GHPoint(""Top Center"", ""TP"", ""Top center"", :item, xyz(1,2,3))
tr < GHNumber(""Top Radius"", ""TR"", ""Top radius"", :item, 1.0)
a  < GHNumber(""Angle"", ""A"", ""Angle"", :item, 0.0)
backend(b)
regular_pyramid_frustum(e, bc, br, a, tc, tr)
cylinder(tc, tr, tc+(tc-bc))";
*/
        private static int counter = 0;
        public int LocalId {
            get;
        }

        private readonly string codeKey = "KhepriCode";
        private readonly string paramNamePrefix = "_kgh_param";
        private IntPtr shapesPtr;

        private IntPtr docInps;
        private IntPtr docOuts;
        private IntPtr inps;
        private IntPtr outs;
        private IntPtr func;
        private IntPtr shapes;

        private static bool ReverseTraceabilityActive = false;

        List<Func<IGH_DataAccess, IntPtr, bool>> toJLConverters = new List<Func<IGH_DataAccess, IntPtr, bool>>();
        List<Action<IGH_DataAccess, IntPtr>> fromJLConverters = new List<Action<IGH_DataAccess, IntPtr>>();
        private JuliaEditor editor = null;
        private static System.Timers.Timer aTimer;

        private void SetTimer() {
            aTimer = new System.Timers.Timer(1000);
            aTimer.Enabled = true;
            aTimer.AutoReset = true;
            aTimer.Elapsed += OnTimeEvent;
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

        string findJuliaPath(string juliaParentFolder, Regex regex) =>
            Directory.GetDirectories(juliaParentFolder)
                    .Select(f => Tuple.Create(f, regex.Match(f)))
                    .Where(t => t.Item2.Success)
                    .Select(t => Tuple.Create(t.Item1, Version.Parse(t.Item2.Groups[1].Value)))
                    .OrderByDescending(t => t.Item2)
                    .Select(t => t.Item1).FirstOrDefault();

        public KhepriComponent() : base("Khepri", "Khepri", "Allows the use of the Khepri portable API.", "Maths", "Script") {
            LocalId = counter++;
            if (!initialized) {
                string juliaParentFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), @"..\Local\Programs\");
                Regex regex = new Regex(@"Julia.([0-9.]+)");
                JLInfo($"Searching for Julia in {juliaParentFolder}");
                var juliaPath = findJuliaPath(juliaParentFolder, regex);
                if (juliaPath == null) {
                    JLError($"Could not find an acceptable Julia version in {juliaParentFolder}");
                } else {
                    JLInfo($"Using Julia folder {juliaPath}");
                    string juliaDLLPath = Path.Combine(juliaPath, "bin");
                    NativeMethods.SetDllDirectory(juliaDLLPath);
                    NativeMethods.jl_init__threading();
                    //We cannot yet use JLEvaluate because it depends on using Khepri
                    IntPtr resPtr = NativeMethods.jl_eval_string("using Khepri");
                    IntPtr exception = NativeMethods.jl_exception_occurred();
                    if (exception != IntPtr.Zero) {
                        JLError("Unable to start Khepri. Please, install Khepri in Julia!");
                    }
                    //Now that we have Khepri we can rely on JLEvaluate
                    JLEvaluate("Khepri.in_shape_collection(true)");
                    DefineJuliaFunctions();
                    atomExec = Path.Combine(juliaParentFolder, @"atom\atom.exe");
                    //Uncomment for Reverse Traceability
                    //SetTimer();
                    initialized = true;
                }
            }
            shapesPtr = JLEvaluate($"__shapes{LocalId} = Shape[]");
        }

        internal void Document_SolutionEnd(object sender, GH_SolutionEventArgs e) {
            HighlightSelectedShapes(e.Document);
            //ExpireSolution(false);
        }

        static void StartShapeCollection() {
            JLEvaluate(@"Khepri.collected_shapes(Shape[])");
        }

        static void SaveShapeCollection(int id) {
            JLEvaluate($@"__shapes{id} = Khepri.collected_shapes();");
        }

        static void EraseShapes(int id) {
            JLEvaluate($@"delete_shapes(__shapes{id})");
        }

        static bool ContainsSelectedShape(int id) =>
            JLLength(JLEvaluate($@"Khepri.pre_selected_shapes_from_set(__shapes{id})")) > 0;

        delegate void Highlighter(GH_Document document);

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
            int[] ids = document.SelectedObjects().Where(o => o is KhepriComponent).Select(k => ((KhepriComponent)k).LocalId).ToArray();
            HighlightShapes(ids);
        }

        internal static void HighlightShapes(int[] ids) {
            // This might be called from the deserialization
            if (JLHasCurrentBackend()) {
                string template = $@"highlight_shapes(vcat(Shape[],{string.Join(",", ids.Select(id => $"__shapes{id}"))}))";
                NativeMethods.jl_eval_string(template);
                CheckForException();
            }
        }

        internal static void UnhighlightAllShapes() {
            // This might be called from the deserialization
            if (JLHasCurrentBackend()) {
                string template = $@"highlight_shapes(Shape[])";
                NativeMethods.jl_eval_string(template);
                CheckForException();
            }
        }

        void ParseJuliaProgram(string text) {
            toJLConverters.Clear();
            fromJLConverters.Clear();
            //First, save previous inputs and output parameter names
            List<string> unusedInputNames = Params.Input.Select(p => p.Name).ToList();
            List<string> unusedOutputNames = Params.Output.Select(p => p.Name).ToList();
            func = JLEvaluate($"Khepri.define_kgh_function(\"{LocalId}\", raw\"\"\"{text}\"\"\")");
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
            //By convention, if there are neither inputs nor outputs, this is just a text file.
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

        string JuliaFromString(Match m, int counter) {
            string dir = m.Groups["dir"].ToString();
            string func = m.Groups["func"].ToString();
            switch (dir) {
                case "<":
                case "=":
                    return $"{m.Groups["var"]} = {paramNamePrefix}{LocalId}[{counter + 1}]";
                case ">":
                    return "";
                default:
                    throw new Exception("Unknown data direction: " + dir);
            }
        }

        GH_ParamAccess ParseAccess(string access) {
            switch (access) {
                case "item": return GH_ParamAccess.item;
                case "list": return GH_ParamAccess.list;
                case "tree": return GH_ParamAccess.tree;
                default: throw new Exception($"Unknown kind: {access}");
            }
        }

        IGH_Param ParamTypeForFunction(string func, string desc, string shortdesc, string message) {
            IGH_Param param =
                func.In("String", "Strings", "Eval", "Evals") ? new Param_String() :
                func.In("Boolean", "Booleans") ? new Param_Boolean() :
                func.In("Integer", "Integers") ? new Param_Integer() :
                func.In("Number", "Numbers") ? new Param_Number() :
                func.In("Point", "Points") ? new Param_Point() :
                func.In("Vector", "Vectors") ? new Param_Vector() :
                func.In("Point", "Point") ? new Param_Point() :
                func.In("Path", "Paths") ? new Param_FilePath() :
                (IGH_Param)new Param_GenericObject();
            param.Name = desc;
            param.Access =
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
                        ((Param_Integer)newParam).PersistentData.Append(new GH_Integer(asInt(value)));
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
                    toJLConverters.Add((da, ptr) => ToJLArrayString(i, da, ptr));
                    break;
                case "Booleans":
                    toJLConverters.Add((da, ptr) => ToJLArrayBool(i, da, ptr));
                    break;
                case "Integers":
                    toJLConverters.Add((da, ptr) => ToJLArrayInt64(i, da, ptr));
                    break;
                case "Numbers":
                    toJLConverters.Add((da, ptr) => ToJLArrayFloat64(i, da, ptr));
                    break;
                case "Points":
                    toJLConverters.Add((da, ptr) => ToJLArrayLoc(i, da, ptr));
                    break;
                case "Vectors":
                    toJLConverters.Add((da, ptr) => ToJLArrayVec(i, da, ptr));
                    break;
                case "Many":
                    toJLConverters.Add((da, ptr) => ToJLArrayAny(i, da, ptr));
                    break;
                case "Evals":
                    toJLConverters.Add((da, ptr) => ToJLArrayEval(i, da, ptr));
                    break;
                case "JLs":
                    toJLConverters.Add((da, ptr) => ToJLArrayJL(i, da, ptr));
                    break;
                default:
                    throw new Exception("Unknown function: " + func);
            }
            if (oldParam == null) {
                Params.RegisterInputParam(newParam);
            } else if (! EqualParams(newParam, oldParam)) {
                Params.RegisterInputParam(newParam);
                foreach (IGH_Param source in oldParam.Sources) {
                        newParam.AddSource(source);
                    }
                    Params.UnregisterInputParameter(oldParam);
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
                    fromJLConverters.Add((da, ptr) => da.SetData(i, asLong(JLGetIndex0(ptr, i))));
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
                default:
                    throw new Exception("Unknown function: " + func);
            }
            if (oldParam == null) {
                Params.RegisterOutputParam(newParam);
            } else if (! EqualParams(newParam, oldParam)) {
                Params.RegisterOutputParam(newParam);
                List<IGH_Param> oldRecipients = new List<IGH_Param>(oldParam.Recipients);
                foreach (IGH_Param recipient in oldRecipients) {
                    recipient.AddSource(newParam);
                }
                Params.UnregisterOutputParameter(oldParam);
            }
        }


        bool ParseBoolean(string expr) =>
            (expr == "") ? false : asBool(JLEvaluate(expr));
        int ParseInteger(string expr) =>
            (expr == "") ? 0 : asInt(JLEvaluate($"Int32({expr})"));
        double ParseDouble(string expr) =>
            (expr == "") ? 0.0 : asDouble(JLEvaluate($"Float64({expr})"));
        Point3d ParsePoint(string expr) =>
            (expr == "") ? Point3d.Origin : asPoint3d(JLEvaluate(expr));
        Vector3d ParseVector(string expr) =>
            (expr == "") ? Vector3d.Zero : asVector3d(JLEvaluate(expr));

        //Converters from Grasshopper to Khepri
        bool ToJLString(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            string data = "";
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLString(data), i); 
            return true;
        }
        bool ToJLBool(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            bool data = false;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLBool(data), i);
            return true;
        }
        bool ToJLInt64(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            int data = 0;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLInt64(data), i);
            return true;
        }
        bool ToJLFloat64(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            double data = 0;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLFloat64(data), i);
            return true;
        }
        bool ToJLLoc(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            Point3d data = Point3d.Origin;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLLoc(data), i);
            return true;
        }
        bool ToJLVec(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            Vector3d data = Vector3d.Zero;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLVec(data), i);
            return true;
        }
        bool ToJLEval(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            string data = "";
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, JLEvaluate(data), i);
            return true;
        }
        bool ToJL(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            GH_ObjectWrapper data = null;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, (IntPtr)data.Value, i);
            return true;
        }
        bool ToJLAny(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            GH_ObjectWrapper data = null;
            if (!DA.GetData(i, ref data)) return false;
            JLSetIndex0(arrPtr, asJLDynamic(data.Value), i);
            return true;
        }
        bool IsProperList(int i, IGH_DataAccess DA) {
            List<Object> test = new List<Object>();
            return (DA.GetDataList(i, test) && DA.Util_CountNullRefs(test) == 0);
        }
        bool ToJLArrayString(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<string> data = new List<string>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data)) {
                IntPtr vals = JLEvaluate($"Array{{String, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLString(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayBool(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<bool> data = new List<bool>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data)) {
                IntPtr vals = JLEvaluate($"Array{{Bool, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLBool(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayInt64(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<int> data = new List<int>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data)) {
                IntPtr vals = JLEvaluate($"Array{{Int64, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLInt64(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayFloat64(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<double> data = new List<double>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data)) {
                IntPtr vals = JLEvaluate($"Array{{Float64, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLFloat64(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayLoc(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<Point3d> data = new List<Point3d>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data) && data.Count > 0) {
                IntPtr vals = JLEvaluate($"Array{{Khepri.Loc, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLLoc(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayVec(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<Vector3d> data = new List<Vector3d>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data) && data.Count > 0) {
                IntPtr vals = JLEvaluate($"Array{{Khepri.Vec, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLVec(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayJL(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<GH_ObjectWrapper> data = new List<GH_ObjectWrapper>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data) && data.Count > 0) {
                IntPtr vals = JLEvaluate($"Array{{Any, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, (IntPtr)data[j].Value, j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayEval(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<string> data = new List<string>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data) && data.Count > 0) {
                IntPtr vals = JLEvaluate($"Array{{Any, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, JLEvaluate(data[j]), j);
                }
                return true;
            } else {
                return false;
            }
        }
        bool ToJLArrayAny(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<GH_ObjectWrapper> data = new List<GH_ObjectWrapper>();
            if (IsProperList(i, DA) && DA.GetDataList(i, data) && data.Count > 0) {
                IntPtr vals = JLEvaluate($"Array{{Any, 1}}(undef, {data.Count})");
                JLSetIndex0(arrPtr, vals, i); //To prevent GC from collecting
                for (int j = 0; j < data.Count; j++) {
                    JLSetIndex0(vals, asJLDynamic(data[j].Value), i);
                }
                return true;
            } else {
                return false;
            }
        }
        //Converters from Khepri to Grasshopper
        void FromJLString(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, asString(ptr));
        }
        void FromJLBool(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, asBool(ptr));
        }
        void FromJLInt64(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, asLong(ptr));
        }
        void FromJLFloat64(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, asDouble(ptr));
        }
        void FromJLLoc(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, asPoint3d(ptr));
        }
        void FromJLVec(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, asVector3d(ptr));
        }
        void FromJLEval(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, new GH_ObjectWrapper(ptr));
        }
        void FromJLAny(int i, IGH_DataAccess DA, IntPtr ptr) {
            DA.SetData(i, new GH_ObjectWrapper(ptr));
        }
        void FromJLDynamic(int i, IGH_DataAccess DA, IntPtr ptr) {
            if (JLIsaString(ptr)) {
                FromJLString(i, DA, ptr);
            } else if (JLIsaBool(ptr)) {
                FromJLBool(i, DA, ptr);
            } else if (JLIsaInt64(ptr)) {
                FromJLInt64(i, DA, ptr);
            } else if (JLIsaFloat64(ptr)) {
                FromJLFloat64(i, DA, ptr);
            } else if (JLIsaXYZ(ptr)) {
                FromJLLoc(i, DA, ptr);
            } else if (JLIsaVXYZ(ptr)) {
                FromJLVec(i, DA, ptr);
            } else {
                FromJLAny(i, DA, ptr);
            }
        }
        void FromJLArrayString(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<string> data = new List<string>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asString(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayBool(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<bool> data = new List<bool>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asBool(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayInt64(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<long> data = new List<long>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asLong(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayFloat64(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<double> data = new List<double>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asDouble(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayLoc(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<Point3d> data = new List<Point3d>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asPoint3d(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayVec(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<Vector3d> data = new List<Vector3d>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asVector3d(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayAny(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<IntPtr> data = new List<IntPtr>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(JLGetIndex0(arrPtr, idx));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayEval(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<String> data = new List<String>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                data.Add(asShow(JLGetIndex0(arrPtr, idx)));
            }
            DA.SetDataList(i, data);
        }
        void FromJLArrayDynamic(int i, IGH_DataAccess DA, IntPtr arrPtr) {
            List<Object> data = new List<Object>();
            int n = JLLength(arrPtr);
            for (int idx = 0; idx < n; idx++) {
                IntPtr ptr = JLGetIndex0(arrPtr, idx);
                if (JLIsaString(ptr)) {
                    data.Add(asString(ptr));
                } else if (JLIsaBool(ptr)) {
                    data.Add(asBool(ptr));
                } else if (JLIsaInt64(ptr)) {
                    data.Add(asLong(ptr));
                } else if (JLIsaFloat64(ptr)) {
                    data.Add(asDouble(ptr));
                } else if (JLIsaXYZ(ptr)) {
                    data.Add(asPoint3d(ptr));
                } else if (JLIsaVXYZ(ptr)) {
                    data.Add(asVector3d(ptr));
                } else {
                    data.Add(ptr);
                }
            }
            DA.SetDataList(i, data);
        }
        protected override void BeforeSolveInstance() {
            EraseShapes(LocalId);
            StartShapeCollection();
        }

        protected override void SolveInstance(IGH_DataAccess DA) {
            if (func != IntPtr.Zero) {
                if (toJLConverters.All(conv => conv(DA, inps))) {
                    IntPtr res = NativeMethods.jl_call0(func);
                    CheckForException();
                    foreach (var conv in fromJLConverters) {
                        conv(DA, outs);
                    }
                }
            }
        }

        protected override void AfterSolveInstance() {
            SaveShapeCollection(LocalId);
        }
        public override void RemovedFromDocument(GH_Document document) {
            // Remove object count, so now can create another object
            EraseShapes(LocalId);
            if (editor != null) {
                editor.Dispose();
            }
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
            ParseJuliaProgram(script);
        }

        protected override void RegisterInputParams(GH_InputParamManager pManager) {
            // Use the pManager object to register your input parameters.
            // You can often supply default values when creating parameters.
            // All parameters must have the correct access type. If you want 
            // to import lists or trees of values, modify the ParamAccess flag.
            //pManager.AddTextParameter("Backend", "B", "Backend to use", GH_ParamAccess.item, "autocad");
            //pManager.AddTextParameter(codeKey, "K", "Script to use", GH_ParamAccess.item, script);
            /* pManager.AddIntegerParameter("Edges", "N", "Number of edges", GH_ParamAccess.item, 5);
             pManager.AddPointParameter("Base Center", "BP", "Base center", GH_ParamAccess.item, new Point3d(0, 0, 0));
             pManager.AddNumberParameter("Base Radius", "BR", "Base radius", GH_ParamAccess.item, 2.0);
             pManager.AddPointParameter("Top Center", "TP", "Top center", GH_ParamAccess.item, new Point3d(0, 0, 10));
             pManager.AddNumberParameter("Top Radius", "TR", "Top radius", GH_ParamAccess.item, 1.0);
             pManager.AddNumberParameter("Angle", "A", "Angle", GH_ParamAccess.item, 0.0);
            */ // If you want to change properties of certain parameters, 
               // you can use the pManager instance to access them by index:
               //pManager[0].Optional = true;
        }

        protected override void RegisterOutputParams(GH_OutputParamManager pManager) {
            //pManager.AddTextParameter("Output", "O", "Julia Output", GH_ParamAccess.item);
            // Sometimes you want to hide a specific parameter from the Rhino preview.
            // You can use the HideParameter() method as a quick way:
            //pManager.HideParameter(0);
        }

        protected override void AppendAdditionalComponentMenuItems(ToolStripDropDown menu) {
            ToolStripMenuItem item = Menu_AppendItem(menu, "Khepri Code", (sender, e) => Menu_KhepriCodeClicked(menu));
            item.ToolTipText = "Specify the Khepri Code you want to run.";
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

        private void Menu_KhepriCodeClicked(ToolStripDropDown menu) {
            // Dump contents on file
            string path = Path.ChangeExtension(Path.GetTempFileName(), "jl");
            File.WriteAllText(path, script);
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
            Process.Start(atomExec, path);
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
                    KhepriComponent.HighlightShapes(new int[] { component.LocalId });
                } else {
                    KhepriComponent.UnhighlightAllShapes();
                }
            }
        }
    }
}