using System;
using System.Runtime.InteropServices;

public static class DesktopPicker
{
    private delegate IntPtr MouseProc(int code, IntPtr message, IntPtr data);
    private static readonly MouseProc Callback = OnMouse;
    private static IntPtr hook;
    private static IntPtr overlay;
    private static IntPtr memoryDC, dib, previousBitmap, pixelsAddress;
    private static int lastX = int.MinValue, lastY = int.MinValue;
    private static Point selectedPoint;
    public static bool Ready { get; private set; }
    public static string Color { get; private set; }
    [StructLayout(LayoutKind.Sequential)] private struct Point { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("gdi32.dll")] private static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr value);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr dc, IntPtr value);
    [DllImport("gdi32.dll")] private static extern bool BitBlt(IntPtr destination, int x, int y, int width, int height, IntPtr source, int sourceX, int sourceY, uint flags);
    [DllImport("gdi32.dll")] private static extern bool GdiFlush();
    [StructLayout(LayoutKind.Sequential)] private struct BitmapHeader {
        public uint Size; public int Width, Height; public ushort Planes, Bits; public uint Compression, ImageSize; public int X, Y; public uint Used, Important;
    }
    [DllImport("gdi32.dll")] private static extern IntPtr CreateDIBSection(IntPtr dc, ref BitmapHeader header, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SetWindowsHookEx(int id, MouseProc proc, IntPtr module, uint thread);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr value);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr value, int code, IntPtr message, IntPtr data);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] private static extern bool GetPhysicalCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr window, int index);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr window, int index, int value);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr window);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr window, IntPtr dc);
    [DllImport("gdi32.dll")] private static extern uint GetPixel(IntPtr dc, int x, int y);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    public static bool EscapePressed { get { return (GetAsyncKeyState(27) & 0x8000) != 0; } }
    public static string PixelToHex(uint pixel) { return string.Format("#{0:X2}{1:X2}{2:X2}", pixel & 255, (pixel >> 8) & 255, (pixel >> 16) & 255); }
    public sealed class Frame { public int X, Y; public string Hex; public byte[] Bgra; }
    public static void MakeOverlay(IntPtr window)
    {
        overlay = window;
        SetWindowLong(window, -20, GetWindowLong(window, -20) | 0x20 | 0x80 | 0x08000000);
    }
    private static void ClearSampleArea(Point point)
    {
        Rect bounds;
        if (overlay == IntPtr.Zero || !GetWindowRect(overlay, out bounds)) { return; }
        if (point.X < bounds.Left - 8 || point.X >= bounds.Right + 8 || point.Y < bounds.Top - 8 || point.Y >= bounds.Bottom + 8) { return; }
        int width = bounds.Right - bounds.Left, height = bounds.Bottom - bounds.Top;
        int right = GetSystemMetrics(76) + GetSystemMetrics(78), bottom = GetSystemMetrics(77) + GetSystemMetrics(79);
        int x = point.X + 28, y = point.Y + 28;
        if (x + width > right) { x = point.X - width - 28; }
        if (y + height > bottom) { y = point.Y - height - 28; }
        SetWindowPos(overlay, IntPtr.Zero, x, y, 0, 0, 0x15);
    }
    public static byte[] EncodeBitmap(uint[] pixels)
    {
        if (pixels.Length != 225) { throw new ArgumentException("Expected 15 x 15 pixels."); }
        using (var stream = new System.IO.MemoryStream())
        using (var writer = new System.IO.BinaryWriter(stream))
        {
            writer.Write((ushort)0x4D42); writer.Write(54 + 48 * 15); writer.Write(0); writer.Write(54);
            writer.Write(40); writer.Write(15); writer.Write(15); writer.Write((ushort)1); writer.Write((ushort)24);
            writer.Write(0); writer.Write(48 * 15); writer.Write(0); writer.Write(0); writer.Write(0); writer.Write(0);
            for (int y = 14; y >= 0; y--)
            {
                for (int x = 0; x < 15; x++)
                {
                    uint pixel = pixels[y * 15 + x];
                    writer.Write((byte)(pixel >> 16)); writer.Write((byte)(pixel >> 8)); writer.Write((byte)pixel);
                }
                writer.Write(new byte[3]);
            }
            return stream.ToArray();
        }
    }
    public static Frame Capture()
    {
        Point logical, physical;
        if (!GetCursorPos(out logical)) { return null; }
        IntPtr previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        IntPtr dc = IntPtr.Zero;
        try
        {
            if (!GetPhysicalCursorPos(out physical)) { return null; }
            if (physical.X == lastX && physical.Y == lastY) { return null; }
            ClearSampleArea(physical);
            Frame frame = CapturePoint(physical);
            frame.X = logical.X; frame.Y = logical.Y;
            lastX = physical.X; lastY = physical.Y;
            return frame;
        }
        finally
        {
            if (dc != IntPtr.Zero) { ReleaseDC(IntPtr.Zero, dc); }
            if (previous != IntPtr.Zero) { SetThreadDpiAwarenessContext(previous); }
        }
    }
    public static void Begin()
    {
        Stop(); Ready = false; Color = null;
        lastX = int.MinValue; lastY = int.MinValue;
        hook = SetWindowsHookEx(14, Callback, GetModuleHandle(null), 0);
        if (hook == IntPtr.Zero) { throw new InvalidOperationException("Impossibile attivare la pipetta."); }
    }
    private static Frame CapturePoint(Point point)
    {
        IntPtr screen = GetDC(IntPtr.Zero);
        try
        {
            if (memoryDC == IntPtr.Zero)
            {
                memoryDC = CreateCompatibleDC(screen);
                var header = new BitmapHeader { Size = 40, Width = 15, Height = -15, Planes = 1, Bits = 32 };
                dib = CreateDIBSection(screen, ref header, 0, out pixelsAddress, IntPtr.Zero, 0);
                if (dib == IntPtr.Zero || memoryDC == IntPtr.Zero) { throw new InvalidOperationException("Impossibile leggere lo schermo."); }
                previousBitmap = SelectObject(memoryDC, dib);
            }
            if (!BitBlt(memoryDC, 0, 0, 15, 15, screen, point.X - 7, point.Y - 7, 0x00CC0020)) { throw new InvalidOperationException("Pixel non leggibili."); }
            GdiFlush();
            var data = new byte[900];
            Marshal.Copy(pixelsAddress, data, 0, data.Length);
            int center = 112 * 4;
            string hex = string.Format("#{0:X2}{1:X2}{2:X2}", data[center + 2], data[center + 1], data[center]);
            return new Frame { Bgra = data, Hex = hex };
        }
        finally { ReleaseDC(IntPtr.Zero, screen); }
    }
    public static string CompleteSelection()
    {
        IntPtr previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        try { ClearSampleArea(selectedPoint); Color = CapturePoint(selectedPoint).Hex; return Color; }
        finally { if (previous != IntPtr.Zero) { SetThreadDpiAwarenessContext(previous); } }
    }
    public static void Stop()
    {
        if (hook != IntPtr.Zero) { UnhookWindowsHookEx(hook); hook = IntPtr.Zero; }
        if (memoryDC != IntPtr.Zero && previousBitmap != IntPtr.Zero) { SelectObject(memoryDC, previousBitmap); }
        if (dib != IntPtr.Zero) { DeleteObject(dib); }
        if (memoryDC != IntPtr.Zero) { DeleteDC(memoryDC); }
        dib = memoryDC = previousBitmap = pixelsAddress = IntPtr.Zero;
    }
    private static IntPtr OnMouse(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0)
        {
            long id = message.ToInt64();
            if (id == 0x201) { return new IntPtr(1); }
            if (id == 0x202)
            {
                // Keep the desktop input hook short: sample later on the UI timer.
                selectedPoint = (Point)Marshal.PtrToStructure(data, typeof(Point));
                Ready = true;
                return new IntPtr(1);
            }
        }
        return CallNextHookEx(hook, code, message, data);
    }
}
