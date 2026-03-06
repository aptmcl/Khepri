namespace KhepriUnity {
    public class Processor<C, P> : KhepriBase.Processor<C, P> where C : Channel where P : Primitives {

        public Processor(C c, P p) : base(c, p) {
        }
    }
}
