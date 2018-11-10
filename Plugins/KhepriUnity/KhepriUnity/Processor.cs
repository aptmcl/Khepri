using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;

namespace KhepriUnity {
    public class Processor<C, P> : KhepriBase.Processor<C, P> where C : Channel where P : Primitives {

        public Processor(C c, P p) : base(c, p) {
        }

        public override void Execute(int op) {
            operations[op](channel, primitives);
            channel.Flush();
        }
    }
}
