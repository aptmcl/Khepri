using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KhepriBase {
    public class Primitives {
        /*
         * For extra flexibility, we will accept a dictionary of property/value pairs and use reflection
        */
        public void Set(object obj, string prop, object val) => obj.GetType().GetProperty(prop).SetValue(obj, val, null);
        public void Set(object obj, Options propValues) {
            Type type = obj.GetType();
            foreach (var kv in propValues) {
                type.GetProperty(kv.Key).SetValue(obj, kv.Value, null);
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