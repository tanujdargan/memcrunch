using System.Windows;
using MemCrunch.ViewModels;
using MemCrunch.Views;

namespace MemCrunch;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm = new();

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _vm;
        _vm.LoadVolumes();
        ShowVolumeSelector();

        _vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(MainViewModel.ScanComplete) or
                nameof(MainViewModel.IsScanning))
            {
                UpdateSidebar();
            }

            if (e.PropertyName is nameof(MainViewModel.SelectedNodeId) or
                nameof(MainViewModel.TreemapRects))
            {
                TreemapPanel.Render(_vm.TreemapRects, _vm);
            }

            if (e.PropertyName == nameof(MainViewModel.FileTypeStats))
            {
                FileTypePanelView.Update(_vm.FileTypeStats);
            }
        };
    }

    private void UpdateSidebar()
    {
        if (_vm.ScanComplete)
            ShowTreeSidebar();
        else if (_vm.IsScanning)
            ShowScanProgress();
        else
            ShowVolumeSelector();
    }

    private void ShowVolumeSelector()
    {
        var view = new VolumeSelector();
        view.DataContext = _vm;
        view.ScanRequested += async () => await _vm.StartScanAsync();
        SidebarContent.Content = view;
    }

    private void ShowScanProgress()
    {
        var view = new ScanProgressView();
        view.DataContext = _vm;
        SidebarContent.Content = view;
    }

    private void ShowTreeSidebar()
    {
        var view = new TreeSidebar();
        view.DataContext = _vm;
        view.NodeDrillDown += (nodeId) => _vm.DrillDown(nodeId);
        SidebarContent.Content = view;
    }

    private void BackToVolumes_Click(object sender, RoutedEventArgs e) => _vm.GoBackToVolumes();
    private void NavigateUp_Click(object sender, RoutedEventArgs e) => _vm.NavigateUp();
    private void CancelScan_Click(object sender, RoutedEventArgs e) => _vm.CancelScan();

    protected override void OnContentRendered(System.EventArgs e)
    {
        base.OnContentRendered(e);
        // Initial treemap render
        if (_vm.ScanComplete)
        {
            _vm.UpdateTreemap(TreemapPanel.ActualWidth, TreemapPanel.ActualHeight);
        }
    }
}
