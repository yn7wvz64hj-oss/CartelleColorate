using System;
using System.Runtime.InteropServices;
public static class FolderShell {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct FileInfo { public IntPtr Icon; public int Index; public uint Attributes; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string Display; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=80)] public string Type; }
 [DllImport("shell32.dll",CharSet=CharSet.Unicode)] static extern IntPtr SHGetFileInfo(string path,uint attributes,out FileInfo info,uint size,uint flags);
 [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr icon);
 public static byte[] ReadFolderPreview(string path) {
  FileInfo info; if(SHGetFileInfo(path,0,out info,(uint)Marshal.SizeOf(typeof(FileInfo)),0x100)==IntPtr.Zero || info.Icon==IntPtr.Zero) throw new System.IO.IOException("Folder icon unavailable");
  try { using(var icon=System.Drawing.Icon.FromHandle(info.Icon)) using(var bitmap=icon.ToBitmap()) using(var stream=new System.IO.MemoryStream()) { bitmap.Save(stream,System.Drawing.Imaging.ImageFormat.Png); return stream.ToArray(); } } finally { DestroyIcon(info.Icon); }
 }

 [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern void SHChangeNotify(uint e, uint f, string a, IntPtr b);
 [DllImport("shell32.dll", EntryPoint="SHChangeNotify", CharSet=CharSet.Unicode)] public static extern void SHRenameNotify(uint e, uint f, string a, string b);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint WritePrivateProfileString(string section, string key, string value, string file);
}
