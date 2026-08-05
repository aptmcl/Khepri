using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KhepriBase {
    public class Primitives {
        /*
         * Build-stamp handshake. Julia requests this once per fresh connection and
         * compares the answer against the vendored plugin binaries it shipped with,
         * so a host running a stale assembly — deployed-but-not-reloaded after
         * update_plugin(), or never updated at all — is diagnosed in one warning
         * line instead of debugged live. Inherited by every C# plugin's Primitives;
         * a plugin that predates this method answers the registration request with
         * NOTOK ("method does not exist"), which Julia downgrades to that same
         * warning, so old plugin + new Julia degrades cleanly.
         *
         * The stamp is the PE header link timestamp of the concrete plugin assembly
         * and of KhepriBase.dll (distinct builds of the two can drift apart — the
         * 2026-07 incidents shipped exactly that). Legacy csproj builds are
         * non-deterministic, so the timestamp is a real UTC build time.
         */
        public String KhepriBuildStamp() {
            var plugin = GetType().Assembly;
            var shared = typeof(Primitives).Assembly;
            return plugin == shared
                ? AssemblyBuildStamp(plugin)
                : AssemblyBuildStamp(plugin) + "; " + AssemblyBuildStamp(shared);
        }

        static String AssemblyBuildStamp(System.Reflection.Assembly a) {
            try {
                var ts = PeLinkTimestamp(a.Location);
                // InvariantCulture is load-bearing: the interpolated form would use
                // CurrentCulture, whose TimeSeparator replaces ':' (fi-FI => '.')
                // and whose default calendar replaces the year (th-TH => 2569) —
                // and Julia compares this string byte-for-byte against its own
                // fixed-format rendering of the vendored binaries (pe_link_stamp),
                // so a culture-shaped stamp would warn "stale plugin" forever.
                return a.GetName().Name + " built " +
                       ts.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'",
                                   System.Globalization.CultureInfo.InvariantCulture);
            } catch (Exception e) {
                // Dynamic or in-memory assemblies (empty Location) land here; the
                // handshake still succeeds, it just cannot vouch for that assembly.
                return $"{a.GetName().Name} stamp-unavailable ({e.GetType().Name})";
            }
        }

        static DateTime PeLinkTimestamp(String path) {
            using (var f = new System.IO.FileStream(path, System.IO.FileMode.Open,
                                                    System.IO.FileAccess.Read,
                                                    System.IO.FileShare.ReadWrite)) {
                var header = new byte[4096];
                int got = f.Read(header, 0, header.Length);
                int peOffset = BitConverter.ToInt32(header, 0x3C);
                if (peOffset < 0 || peOffset + 12 > got ||
                    header[peOffset] != 'P' || header[peOffset + 1] != 'E')
                    throw new InvalidOperationException("no PE header");
                uint secs = BitConverter.ToUInt32(header, peOffset + 8);
                return new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddSeconds(secs);
            }
        }

        /*
         * For extra flexibility, we will accept a dictionary of property/value pairs and use reflection
        */
        public void Set(object obj, string prop, object val) {
            var type = obj.GetType();
            var pi = type.GetProperty(prop);
            if (pi == null)
                throw new ArgumentException($"Type {type.Name} has no settable property '{prop}'");
            pi.SetValue(obj, val, null);
        }
        public void Set(object obj, Options propValues) {
            Type type = obj.GetType();
            foreach (var kv in propValues) {
                var pi = type.GetProperty(kv.Key);
                if (pi == null)
                    throw new ArgumentException($"Type {type.Name} has no settable property '{kv.Key}'");
                pi.SetValue(obj, kv.Value, null);
            }
        }
    }

    public class Options: IEnumerable<KeyValuePair<string, object>> {
        Dictionary<string, object> options = new Dictionary<string, object>();

        public object this[string index] {
            get => options[index];
            set => options[index] = value;
        }

        IEnumerator IEnumerable.GetEnumerator() =>
            options.GetEnumerator();
        IEnumerator<KeyValuePair<string, object>> IEnumerable<KeyValuePair<string, object>>.GetEnumerator() =>
            options.GetEnumerator();
    }
}