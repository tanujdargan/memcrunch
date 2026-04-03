using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using MemCrunch.Models;
using MemCrunch.ViewModels;

namespace MemCrunch.Views;

public partial class VolumeSelector : UserControl
{
    public event Action? ScanRequested;

    public VolumeSelector()
    {
        InitializeComponent();
    }

    private void Volume_Click(object sender, MouseButtonEventArgs e)
    {
        if (sender is FrameworkElement fe && fe.DataContext is VolumeInfo vol)
        {
            if (DataContext is MainViewModel vm)
                vm.SelectedVolume = vol;
        }
    }

    private void Scan_Click(object sender, RoutedEventArgs e)
    {
        ScanRequested?.Invoke();
    }
}

// Converter for usage bar width
public class UsageWidthConverter : IMultiValueConverter
{
    public static readonly UsageWidthConverter Instance = new();

    public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
    {
        if (values.Length == 2 && values[0] is ulong used && values[1] is ulong total && total > 0)
            return Math.Min(180.0, 180.0 * used / total);
        return 0.0;
    }

    public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
