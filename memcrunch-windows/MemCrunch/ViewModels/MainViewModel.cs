using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using MemCrunch.Models;
using MemCrunch.Services;

namespace MemCrunch.ViewModels;

public class MainViewModel : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    // -----------------------------------------------------------------------
    // Observable state
    // -----------------------------------------------------------------------

    public ObservableCollection<VolumeInfo> Volumes { get; } = new();

    private VolumeInfo? _selectedVolume;
    public VolumeInfo? SelectedVolume
    {
        get => _selectedVolume;
        set { _selectedVolume = value; OnPropertyChanged(); OnPropertyChanged(nameof(CanScan)); }
    }

    private bool _isScanning;
    public bool IsScanning
    {
        get => _isScanning;
        set { _isScanning = value; OnPropertyChanged(); OnPropertyChanged(nameof(ShowVolumes)); OnPropertyChanged(nameof(ShowScanProgress)); OnPropertyChanged(nameof(ShowResults)); }
    }

    private bool _scanComplete;
    public bool ScanComplete
    {
        get => _scanComplete;
        set { _scanComplete = value; OnPropertyChanged(); OnPropertyChanged(nameof(ShowVolumes)); OnPropertyChanged(nameof(ShowScanProgress)); OnPropertyChanged(nameof(ShowResults)); }
    }

    public bool ShowVolumes => !IsScanning && !ScanComplete;
    public bool ShowScanProgress => IsScanning;
    public bool ShowResults => ScanComplete;
    public bool CanScan => SelectedVolume != null && !IsScanning;

    private int? _rootNodeId;
    public int? RootNodeId { get => _rootNodeId; set { _rootNodeId = value; OnPropertyChanged(); } }

    private int? _selectedNodeId;
    public int? SelectedNodeId { get => _selectedNodeId; set { _selectedNodeId = value; OnPropertyChanged(); } }

    private ulong _filesScanned;
    public ulong FilesScanned { get => _filesScanned; set { _filesScanned = value; OnPropertyChanged(); } }

    private ulong _dirsScanned;
    public ulong DirsScanned { get => _dirsScanned; set { _dirsScanned = value; OnPropertyChanged(); } }

    private ulong _bytesScanned;
    public ulong BytesScanned { get => _bytesScanned; set { _bytesScanned = value; OnPropertyChanged(); } }

    private string _currentPath = "";
    public string CurrentPath { get => _currentPath; set { _currentPath = value; OnPropertyChanged(); } }

    private ulong _totalSize;
    public ulong TotalSize { get => _totalSize; set { _totalSize = value; OnPropertyChanged(); } }

    private ulong _totalFiles;
    public ulong TotalFiles { get => _totalFiles; set { _totalFiles = value; OnPropertyChanged(); } }

    private ulong _scanningVolumeTotal;
    public ulong ScanningVolumeTotal { get => _scanningVolumeTotal; set { _scanningVolumeTotal = value; OnPropertyChanged(); } }

    private string _fullPath = "";
    public string FullPath { get => _fullPath; set { _fullPath = value; OnPropertyChanged(); } }

    public ObservableCollection<FileNodeDTO> SidebarChildren { get; } = new();
    public ObservableCollection<int> NavigationPath { get; } = new();

    private TreemapRect[] _treemapRects = [];
    public TreemapRect[] TreemapRects { get => _treemapRects; set { _treemapRects = value; OnPropertyChanged(); } }

    private FileTypeStatsResponse? _fileTypeStats;
    public FileTypeStatsResponse? FileTypeStats { get => _fileTypeStats; set { _fileTypeStats = value; OnPropertyChanged(); } }

    private double _progressFraction;
    public double ProgressFraction { get => _progressFraction; set { _progressFraction = value; OnPropertyChanged(); } }

    // -----------------------------------------------------------------------
    // Actions
    // -----------------------------------------------------------------------

    public void LoadVolumes()
    {
        Volumes.Clear();
        foreach (var v in RustBridge.ListVolumes())
            Volumes.Add(v);
        if (Volumes.Count > 0 && SelectedVolume == null)
            SelectedVolume = Volumes[0];
    }

    public async Task StartScanAsync()
    {
        if (SelectedVolume == null || IsScanning) return;

        IsScanning = true;
        ScanComplete = false;
        FilesScanned = 0;
        DirsScanned = 0;
        BytesScanned = 0;
        CurrentPath = "";
        ScanningVolumeTotal = SelectedVolume.UsedBytes;
        NavigationPath.Clear();
        SidebarChildren.Clear();
        TreemapRects = [];
        FileTypeStats = null;

        string path = SelectedVolume.MountPoint;

        var result = await Task.Run(() =>
            RustBridge.StartScan(path, json =>
            {
                if (json.Contains("\"Progress\""))
                {
                    try
                    {
                        var wrapper = JsonSerializer.Deserialize<ProgressWrapper>(json,
                            new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower });
                        if (wrapper?.Data != null)
                        {
                            Application.Current?.Dispatcher.Invoke(() =>
                            {
                                FilesScanned = wrapper.Data.FilesScanned;
                                DirsScanned = wrapper.Data.DirsScanned;
                                BytesScanned = wrapper.Data.BytesScanned;
                                CurrentPath = wrapper.Data.CurrentPath;
                                ProgressFraction = ScanningVolumeTotal > 0
                                    ? Math.Min(1.0, (double)BytesScanned / ScanningVolumeTotal)
                                    : 0;
                            });
                        }
                    }
                    catch { }
                }
            })
        );

        IsScanning = false;

        if (result.Ok && result.RootId.HasValue)
        {
            ScanComplete = true;
            RootNodeId = result.RootId;
            TotalSize = result.TotalSize ?? 0;
            TotalFiles = result.TotalFiles ?? 0;
            SelectedNodeId = result.RootId;
            NavigationPath.Add(result.RootId.Value);
            LoadSidebarChildren(result.RootId.Value);
            UpdateFullPath();
            FileTypeStats = RustBridge.GetFileTypeStats(result.RootId.Value);
        }
    }

    public void CancelScan() => RustBridge.CancelScan();

    public void GoBackToVolumes()
    {
        if (IsScanning) CancelScan();
        ScanComplete = false;
        IsScanning = false;
        RootNodeId = null;
        SelectedNodeId = null;
        NavigationPath.Clear();
        SidebarChildren.Clear();
        TreemapRects = [];
        FileTypeStats = null;
        FullPath = "";
        LoadVolumes();
    }

    public void DrillDown(int nodeId)
    {
        NavigationPath.Add(nodeId);
        SelectedNodeId = nodeId;
        LoadSidebarChildren(nodeId);
        UpdateFullPath();
        FileTypeStats = RustBridge.GetFileTypeStats(nodeId);
        OnPropertyChanged(nameof(SelectedNodeId));
    }

    public void NavigateUp()
    {
        if (NavigationPath.Count <= 1) return;
        NavigationPath.RemoveAt(NavigationPath.Count - 1);
        int last = NavigationPath[^1];
        SelectedNodeId = last;
        LoadSidebarChildren(last);
        UpdateFullPath();
        FileTypeStats = RustBridge.GetFileTypeStats(last);
        OnPropertyChanged(nameof(SelectedNodeId));
    }

    public void UpdateTreemap(double width, double height)
    {
        if (SelectedNodeId == null || width <= 0 || height <= 0)
        {
            TreemapRects = [];
            return;
        }
        TreemapRects = RustBridge.GetTreemap(SelectedNodeId.Value, width, height);
    }

    private void LoadSidebarChildren(int nodeId)
    {
        SidebarChildren.Clear();
        foreach (var child in RustBridge.GetChildren(nodeId))
            SidebarChildren.Add(child);
    }

    private void UpdateFullPath()
    {
        var names = new System.Collections.Generic.List<string>();
        foreach (int id in NavigationPath)
        {
            var node = RustBridge.GetNode(id);
            names.Add(node?.Name ?? "?");
        }
        string root = SelectedVolume?.MountPoint ?? names[0];
        if (names.Count <= 1) { FullPath = root; return; }
        string sub = string.Join("\\", names.GetRange(1, names.Count - 1));
        FullPath = root.EndsWith("\\") ? root + sub : root + "\\" + sub;
    }

    // JSON wrapper for tagged enum progress events
    private class ProgressWrapper
    {
        public string Event { get; set; } = "";
        public ScanProgress? Data { get; set; }
    }
}
