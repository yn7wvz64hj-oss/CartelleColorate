using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Windows.Forms;

internal static class Launcher {
    [STAThread] static int Main(string[] args) {
        try {
            Application.EnableVisualStyles();
            string home = AppDomain.CurrentDomain.BaseDirectory;
            bool test = args.Length == 2 && args[0] == "--test";
            bool preview = args.Length == 3 && args[0] == "--preview";
            string[] folders = args.Where(Directory.Exists).Select(Path.GetFullPath).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
            if (test || preview) home = Path.GetFullPath(args[1]);
            else if (folders.Length == 0) {
                using (var picker = new FolderBrowserDialog()) {
                    picker.Description = "Nova Prism: scegli una cartella / Choose a folder";
                    if (picker.ShowDialog() != DialogResult.OK) return 0;
                    folders = new[] {picker.SelectedPath};
                }
            }
            Environment.SetEnvironmentVariable("CC_PRO_PREVIEW", "1");
            Environment.SetEnvironmentVariable("NOVA_STORE", "1");
            var state = InitialSessionState.CreateDefault();
            state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
            using (var runspace = RunspaceFactory.CreateRunspace(state)) {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (var ps = PowerShell.Create()) {
                    ps.Runspace = runspace;
                    ps.AddCommand(Path.Combine(home, "CartelleColorate.ps1"));
                    if (test) ps.AddParameter("SelfTest").AddParameter("NoConsoleTest");
                    else if (preview) ps.AddParameter("Folder", home).AddParameter("Preview", args[2]);
                    else ps.AddParameter("Folder", folders[0]).AddParameter("SelectedFolders", folders);
                    ps.Invoke();
                    if (ps.Streams.Error.Count > 0) throw new Exception(string.Join(Environment.NewLine, ps.Streams.Error.Select(x => x.ToString()).ToArray()));
                }
            }
            return 0;
        } catch (Exception e) {
            if (args.Length > 0 && (args[0] == "--test" || args[0] == "--preview")) {
                File.WriteAllText(Path.Combine(Path.GetFullPath(args[1]), "launcher-error.txt"), e.ToString());
            } else MessageBox.Show(e.Message, "Nova Prism", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
