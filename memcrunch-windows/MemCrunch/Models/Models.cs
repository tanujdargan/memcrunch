using System.Text.Json.Serialization;

namespace MemCrunch.Models;

public class FileNodeDTO
{
    public int Id { get; set; }
    public int? ParentId { get; set; }
    public string Name { get; set; } = "";
    public ulong Size { get; set; }
    public bool IsDir { get; set; }
    public string? Extension { get; set; }
    public uint ChildrenCount { get; set; }
    public ushort Depth { get; set; }
}

public class TreemapRect
{
    public int Id { get; set; }
    public double X { get; set; }
    public double Y { get; set; }
    public double W { get; set; }
    public double H { get; set; }
    public string Name { get; set; } = "";
    public ulong Size { get; set; }
    public bool IsDir { get; set; }
    public string? Extension { get; set; }
    public string Color { get; set; } = "#6B7280";
}

public class VolumeInfo
{
    public string Name { get; set; } = "";
    public string MountPoint { get; set; } = "";
    public ulong TotalBytes { get; set; }
    public ulong AvailableBytes { get; set; }
    public ulong UsedBytes { get; set; }
    public string Filesystem { get; set; } = "";
    public string Kind { get; set; } = "Unknown";
    public bool IsRemovable { get; set; }
    public bool IsReadOnly { get; set; }
}

public class FileTypeStats
{
    public string Extension { get; set; } = "";
    public string Category { get; set; } = "";
    public ulong Count { get; set; }
    public ulong TotalSize { get; set; }
    public double Percentage { get; set; }
}

public class CategoryStats
{
    public string Category { get; set; } = "";
    public ulong Count { get; set; }
    public ulong TotalSize { get; set; }
    public double Percentage { get; set; }
    public string Color { get; set; } = "";
    public FileTypeStats[] TopExtensions { get; set; } = [];
}

public class FileTypeStatsResponse
{
    public CategoryStats[] Categories { get; set; } = [];
    public ulong TotalSize { get; set; }
    public ulong TotalFiles { get; set; }
}

public class ScanResult
{
    public bool Ok { get; set; }
    public int? RootId { get; set; }
    public ulong? TotalSize { get; set; }
    public ulong? TotalFiles { get; set; }
    public ulong? TotalDirs { get; set; }
    public string? Error { get; set; }
}

public class ScanProgress
{
    public ulong FilesScanned { get; set; }
    public ulong DirsScanned { get; set; }
    public ulong BytesScanned { get; set; }
    public string CurrentPath { get; set; } = "";
}
