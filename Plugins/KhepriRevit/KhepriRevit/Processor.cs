using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using System.IO;

namespace KhepriRevit {
    public class Processor<C,P> : KhepriBase.Processor<C,P> where C : Channel where P : Primitives {

        public Document doc;

        public Processor(Document doc, C c, P p) : base(c, p) {
            this.doc = doc;
        }

        public new bool ExecuteReadAndRepeat(int op) {
            using (Transaction t = new Transaction(doc, "Execute")) {
                primitives.CurrentTransaction = t;
                t.Start();
                WarningSwallower.KhepriWarnings(t);
                while (true) {
                    if (op == -1) {
                        return false;
                    }
                    Execute(op);
                    channel.SetReadTimeout(20);
                    try {
                        op = ReadOperation();
                    } catch (IOException) {
                        break;
                    } finally {
                        channel.SetReadTimeout(-1);
                    }
                }
                t.Commit();
                return true;
            }
        }
        /*
        public bool ExecuteOperation(int op) {
            using (Transaction t = new Transaction(doc, "Execute")) {
                primitives.CurrentTransaction = t;
                t.Start();
                WarningSwallower.KhepriWarnings(t);
                while (true) {
                    if (op == -1) {
                        t.Commit();
                        return false;
                    }
                    operations[op](this, primitives);
                    flush();
                    stream.ReadTimeout = 20;
                    try {
                        op = ReadOperation();
                    } catch (IOException) {
                        break;
                    } finally {
                        stream.ReadTimeout = -1;
                    }
                }
                t.Commit();
                return true;
            }
        }
        */
    }
}
