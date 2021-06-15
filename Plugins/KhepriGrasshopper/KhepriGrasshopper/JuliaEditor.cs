using System;
using System.Windows.Forms;

namespace KhepriGrasshopper {
    public partial class JuliaEditor : Form {

        public JuliaEditor() {
            InitializeComponent();
        }

        private void buttonCommit_Click(object sender, EventArgs e) {
            component.Script = juliaBuffer.Text;
            Hide();
        }

        private void buttonCancel_Click(object sender, EventArgs e) {
            Hide();
        }
    }
}
