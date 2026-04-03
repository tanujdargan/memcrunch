using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using MemCrunch.Converters;
using MemCrunch.Models;

namespace MemCrunch.Views;

public partial class FileTypePanel : UserControl
{
    public FileTypePanel()
    {
        InitializeComponent();
    }

    public void Update(FileTypeStatsResponse? stats)
    {
        PanelContent.Children.Clear();
        if (stats == null) return;

        // Header
        PanelContent.Children.Add(new TextBlock
        {
            Text = "File Types",
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)FindResource("TextPrimary"),
            Margin = new Thickness(0, 0, 0, 2),
        });
        PanelContent.Children.Add(new TextBlock
        {
            Text = $"{FormatHelpers.FormatNumber(stats.TotalFiles)} files, {FormatHelpers.FormatSize(stats.TotalSize)}",
            FontSize = 10,
            Foreground = (Brush)FindResource("TextSecondary"),
            Margin = new Thickness(0, 0, 0, 12),
        });

        // Category rows
        foreach (var cat in stats.Categories)
        {
            var pct = stats.TotalSize > 0 ? (double)cat.TotalSize / stats.TotalSize * 100 : 0;
            var color = ParseColor(cat.Color);

            var row = new DockPanel { Margin = new Thickness(0, 2, 0, 2) };

            // Color dot
            var dot = new Ellipse
            {
                Width = 10, Height = 10,
                Fill = new SolidColorBrush(color),
                Margin = new Thickness(0, 0, 8, 0),
                VerticalAlignment = VerticalAlignment.Top,
            };
            DockPanel.SetDock(dot, Dock.Left);
            row.Children.Add(dot);

            // Right side: size + pct
            var rightPanel = new StackPanel
            {
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Top,
            };
            rightPanel.Children.Add(new TextBlock
            {
                Text = FormatHelpers.FormatSize(cat.TotalSize),
                FontSize = 10,
                Foreground = (Brush)FindResource("TextPrimary"),
                TextAlignment = TextAlignment.Right,
            });
            rightPanel.Children.Add(new TextBlock
            {
                Text = $"{pct:F1}%",
                FontSize = 9,
                Foreground = (Brush)FindResource("TextTertiary"),
                TextAlignment = TextAlignment.Right,
            });
            DockPanel.SetDock(rightPanel, Dock.Right);
            row.Children.Add(rightPanel);

            // Category name
            row.Children.Add(new TextBlock
            {
                Text = cat.Category,
                FontSize = 12,
                Foreground = (Brush)FindResource("TextPrimary"),
                VerticalAlignment = VerticalAlignment.Top,
            });

            PanelContent.Children.Add(row);
        }
    }

    private static Color ParseColor(string hex)
    {
        try { return (Color)ColorConverter.ConvertFromString(hex); }
        catch { return Colors.Gray; }
    }
}
