using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace KhepriAutoCAD {
    public class Processor<C, P> : KhepriBase.Processor<C, P> where C : Channel where P : Primitives {

        System.Windows.Forms.Control sync;

        public Processor(System.Windows.Forms.Control sync, C c, P p) : base(c, p) {
            this.sync = sync;
        }

        public override void Execute(int op) {
            sync.Invoke(operations[op], new object[] { channel, primitives });
            channel.Flush(); //This seems to be incorrect, as it is doing the flush _before_ the writing
        }
    }
}
