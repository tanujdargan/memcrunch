using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace MemCrunch.Converters;

public static class FormatHelpers
{
    private static readonly string[] Units = ["B", "KB", "MB", "GB", "TB", "PB"];

    public static string FormatSize(ulong bytes)
    {
        if (bytes == 0) return "0 B";
        int i = (int)Math.Floor(Math.Log(bytes, 1024));
        i = Math.Min(i, Units.Length - 1);
        double v = bytes / Math.Pow(1024, i);
        return v >= 100 ? $"{v:F0} {Units[i]}" : v >= 10 ? $"{v:F1} {Units[i]}" : $"{v:F2} {Units[i]}";
    }

    public static string FormatNumber(ulong n) => n.ToString("N0");

    public static Brush HexToBrush(string hex)
    {
        try
        {
            var color = (Color)ColorConverter.ConvertFromString(hex);
            return new SolidColorBrush(color);
        }
        catch
        {
            return Brushes.Gray;
        }
    }
}

// WPF value converters for XAML binding

public class SizeConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => FormatHelpers.FormatSize(System.Convert.ToUInt64(value));
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class NumberConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => FormatHelpers.FormatNumber(System.Convert.ToUInt64(value));
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => (bool)value ? Visibility.Visible : Visibility.Collapsed;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

public class HexColorConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => FormatHelpers.HexToBrush((string)value);
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
