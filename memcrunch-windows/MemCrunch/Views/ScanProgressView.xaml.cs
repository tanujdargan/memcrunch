using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using MemCrunch.ViewModels;

namespace MemCrunch.Views;

public partial class ScanProgressView : UserControl
{
    public ScanProgressView()
    {
        InitializeComponent();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        if (DataContext is MainViewModel vm)
            vm.CancelScan();
    }
}

public class FractionToWidthConverter : IValueConverter
{
    public static readonly FractionToWidthConverter Instance = new();

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        double fraction = System.Convert.ToDouble(value);
        double maxWidth = parameter != null ? double.Parse(parameter.ToString()!) : 260;
        return Math.Max(4, fraction * maxWidth);
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
