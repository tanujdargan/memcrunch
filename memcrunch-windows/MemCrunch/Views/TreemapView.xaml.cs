using System;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using MemCrunch.Converters;
using MemCrunch.Models;
using MemCrunch.ViewModels;

namespace MemCrunch.Views;

public partial class TreemapView : UserControl
{
    private TreemapRect[] _rects = [];
    private MainViewModel? _vm;
    private TreemapRect? _hovered;

    public TreemapView()
    {
        InitializeComponent();
    }

    public void Render(TreemapRect[] rects, MainViewModel vm)
    {
        _rects = rects;
        _vm = vm;
        DrawRects();
    }

    private void DrawRects()
    {
        TreemapCanvas.Children.Clear();

        foreach (var rect in _rects)
        {
            var color = ParseColor(rect.Color);
            bool isHov = _hovered?.Id == rect.Id;
            byte alpha = isHov ? (byte)240 : rect.IsDir ? (byte)128 : (byte)200;

            var border = new Border
            {
                Width = Math.Max(0, rect.W),
                Height = Math.Max(0, rect.H),
                CornerRadius = new CornerRadius(Math.Min(4, Math.Min(rect.W, rect.H) / 6)),
                Background = new SolidColorBrush(Color.FromArgb(alpha, color.R, color.G, color.B)),
                BorderBrush = isHov
                    ? new SolidColorBrush(Color.FromArgb(180, 255, 255, 255))
                    : new SolidColorBrush(Color.FromArgb(40, 0, 0, 0)),
                BorderThickness = new Thickness(isHov ? 2 : 0.5),
                ClipToBounds = true,
                Tag = rect,
            };

            // Labels
            if (rect.W > 44 && rect.H > 16)
            {
                var panel = new StackPanel { Margin = new Thickness(5, 4, 5, 0) };

                double fontSize = Math.Min(12, Math.Max(9, Math.Min(rect.W / 10, rect.H / 3)));
                panel.Children.Add(new TextBlock
                {
                    Text = rect.Name,
                    FontSize = fontSize,
                    FontWeight = FontWeights.Medium,
                    Foreground = new SolidColorBrush(Color.FromArgb(230, 255, 255, 255)),
                    TextTrimming = TextTrimming.CharacterEllipsis,
                });

                if (rect.H > 32)
                {
                    panel.Children.Add(new TextBlock
                    {
                        Text = FormatHelpers.FormatSize(rect.Size),
                        FontSize = Math.Max(8, fontSize - 2),
                        Foreground = new SolidColorBrush(Color.FromArgb(128, 255, 255, 255)),
                    });
                }

                border.Child = panel;
            }

            Canvas.SetLeft(border, rect.X);
            Canvas.SetTop(border, rect.Y);
            TreemapCanvas.Children.Add(border);
        }
    }

    private void Canvas_MouseMove(object sender, MouseEventArgs e)
    {
        var pos = e.GetPosition(TreemapCanvas);
        var hit = FindRect(pos.X, pos.Y);

        if (hit != _hovered)
        {
            _hovered = hit;
            DrawRects();
        }

        if (hit != null)
        {
            TipName.Text = hit.Name;
            TipSize.Text = FormatHelpers.FormatSize(hit.Size);
            TipExt.Text = hit.Extension != null ? $".{hit.Extension}" : "";
            TipHint.Text = hit.IsDir ? "Click to open" : "";
            TipExt.Visibility = hit.Extension != null ? Visibility.Visible : Visibility.Collapsed;
            TipHint.Visibility = hit.IsDir ? Visibility.Visible : Visibility.Collapsed;
            TooltipPanel.Visibility = Visibility.Visible;

            double tipX = Math.Min(pos.X + 12, ActualWidth - 170);
            double tipY = Math.Max(pos.Y - 40, 4);
            Canvas.SetLeft(TooltipPanel, tipX);
            Canvas.SetTop(TooltipPanel, tipY);
        }
        else
        {
            TooltipPanel.Visibility = Visibility.Collapsed;
        }
    }

    private void Canvas_MouseLeave(object sender, MouseEventArgs e)
    {
        _hovered = null;
        TooltipPanel.Visibility = Visibility.Collapsed;
        DrawRects();
    }

    private void Canvas_Click(object sender, MouseButtonEventArgs e)
    {
        var pos = e.GetPosition(TreemapCanvas);
        var hit = FindRect(pos.X, pos.Y);
        if (hit == null || _vm == null) return;

        if (hit.IsDir)
            _vm.DrillDown(hit.Id);
    }

    private void Canvas_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        _vm?.UpdateTreemap(e.NewSize.Width, e.NewSize.Height);
    }

    private TreemapRect? FindRect(double x, double y)
    {
        for (int i = _rects.Length - 1; i >= 0; i--)
        {
            var r = _rects[i];
            if (x >= r.X && x <= r.X + r.W && y >= r.Y && y <= r.Y + r.H)
                return r;
        }
        return null;
    }

    private static Color ParseColor(string hex)
    {
        try
        {
            var c = (Color)ColorConverter.ConvertFromString(hex);
            return c;
        }
        catch { return Colors.Gray; }
    }
}
