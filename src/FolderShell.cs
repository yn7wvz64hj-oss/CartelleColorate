using System;
using System.Runtime.InteropServices;
public static class FolderShell {
 [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern void SHChangeNotify(uint e, uint f, string a, IntPtr b);
 [DllImport("shell32.dll", EntryPoint="SHChangeNotify", CharSet=CharSet.Unicode)] public static extern void SHRenameNotify(uint e, uint f, string a, string b);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint WritePrivateProfileString(string section, string key, string value, string file);
}
