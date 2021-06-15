using System;
using System.Drawing;
using Grasshopper.Kernel;

namespace KhepriGrasshopper {
    public class KhepriGrasshopperInfo : GH_AssemblyInfo {
        public override string Name {
            get {
                return "Khepri";
            }
        }
        public override Bitmap Icon {
            get {
                return Properties.Resources.KhepriGHIcon;
            }
        }
        public override string Description {
            get {
                //Return a short string describing the purpose of this GHA library.
                return "";
            }
        }
        public override Guid Id {
            get {
                return new Guid("9246fc72-a637-4ff2-91db-8f3c334b8662");
            }
        }

        public override string AuthorName {
            get {
                //Return a string identifying you or your company.
                return "";
            }
        }
        public override string AuthorContact {
            get {
                //Return a string representing your preferred contact details.
                return "";
            }
        }
    }
}
