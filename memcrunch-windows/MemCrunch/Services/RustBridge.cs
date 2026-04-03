using System;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace MemCrunch.Services;

/// <summary>
/// P/Invoke wrapper for the Rust core library (memcrunch_core.dll).
/// Same C FFI as the macOS Swift bridge — functions return JSON strings.
/// </summary>
public static class RustBridge
{
    private const string DllName = "memcrunch_core";

    // Callback type matching Rust's ScanProgressCallback
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void ScanProgressCallback(IntPtr eventJson);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void mc_free_string(IntPtr ptr);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr mc_start_scan(
        [MarshalAs(UnmanagedType.LPUTF8Str)] string path,
        ScanProgressCallback progressCb);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void mc_cancel_scan();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr mc_get_children(nuint nodeId);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr mc_get_node(nuint nodeId);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr mc_get_treemap(nuint nodeId, double width, double height, ushort maxDepth);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr mc_list_volumes();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr mc_get_file_type_stats(nuint nodeId);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    private static extern bool mc_has_full_disk_access();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void mc_open_full_disk_access_settings();

    // Helper: read C string, free it, return as C# string
    private static string ReadAndFree(IntPtr ptr)
    {
        if (ptr == IntPtr.Zero) return "";
        string result = Marshal.PtrToStringUTF8(ptr) ?? "";
        mc_free_string(ptr);
        return result;
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    public static T? Deserialize<T>(string json) =>
        JsonSerializer.Deserialize<T>(json, JsonOpts);

    public static Models.ScanResult StartScan(string path, Action<string> onProgress)
    {
        ScanProgressCallback cb = (jsonPtr) =>
        {
            string json = Marshal.PtrToStringUTF8(jsonPtr) ?? "";
            onProgress(json);
        };

        IntPtr resultPtr = mc_start_scan(path, cb);
        string resultJson = ReadAndFree(resultPtr);

        // Keep delegate alive during scan
        GC.KeepAlive(cb);

        return Deserialize<Models.ScanResult>(resultJson) ?? new Models.ScanResult();
    }

    public static void CancelScan() => mc_cancel_scan();

    public static Models.FileNodeDTO[] GetChildren(int nodeId)
    {
        string json = ReadAndFree(mc_get_children((nuint)nodeId));
        return Deserialize<Models.FileNodeDTO[]>(json) ?? [];
    }

    public static Models.FileNodeDTO? GetNode(int nodeId)
    {
        string json = ReadAndFree(mc_get_node((nuint)nodeId));
        if (json == "null") return null;
        return Deserialize<Models.FileNodeDTO>(json);
    }

    public static Models.TreemapRect[] GetTreemap(int nodeId, double width, double height, ushort maxDepth = 3)
    {
        string json = ReadAndFree(mc_get_treemap((nuint)nodeId, width, height, maxDepth));
        return Deserialize<Models.TreemapRect[]>(json) ?? [];
    }

    public static Models.VolumeInfo[] ListVolumes()
    {
        string json = ReadAndFree(mc_list_volumes());
        return Deserialize<Models.VolumeInfo[]>(json) ?? [];
    }

    public static Models.FileTypeStatsResponse? GetFileTypeStats(int nodeId)
    {
        string json = ReadAndFree(mc_get_file_type_stats((nuint)nodeId));
        return Deserialize<Models.FileTypeStatsResponse>(json);
    }

    public static bool HasFullDiskAccess() => mc_has_full_disk_access();
}
