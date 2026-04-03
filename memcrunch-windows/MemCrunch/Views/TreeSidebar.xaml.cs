using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using MemCrunch.Models;
using MemCrunch.ViewModels;

namespace MemCrunch.Views;

public partial class TreeSidebar : UserControl
{
    public event Action<int>? NodeDrillDown;

    public TreeSidebar()
    {
        InitializeComponent();
    }

    private void Node_Click(object sender, MouseButtonEventArgs e)
    {
        if (sender is FrameworkElement fe && fe.DataContext is FileNodeDTO node)
        {
            if (node.IsDir)
                NodeDrillDown?.Invoke(node.Id);
        }
    }
}

public class DirIconConverter : IValueConverter
{
    public static readonly DirIconConverter Instance = new();

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => (bool)value ? "📁" : "📄";
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
