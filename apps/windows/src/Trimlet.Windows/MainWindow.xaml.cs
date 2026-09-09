using Microsoft.UI.Xaml;
using Microsoft.UI.Windowing;
using Windows.Graphics;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace Trimlet_Windows;

/// <summary>
/// The application window. This hosts a Frame that displays pages. Add your
/// UI and logic to MainPage.xaml / MainPage.xaml.cs instead of here so you
/// can use Page features such as navigation events and the Loaded lifecycle.
/// </summary>
public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        var iconPath = System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
        if (System.IO.File.Exists(iconPath)) AppWindow.SetIcon(iconPath);
        SetInitialWindowBounds();

        // Navigate the root frame to the main page on startup.
        RootFrame.Navigate(typeof(MainPage));
        AppWindow.Closing += async (sender, args) =>
        {
            if (_closeApproved) return;
            args.Cancel = true;
            if (RootFrame.Content is MainPage current && await current.ConfirmCloseAsync())
            {
                _closeApproved = true;
                Close();
            }
        };

    }

    public void OpenInitialPath(string path)
    {
        // Media and native pickers require an activated window, not constructor-time loading.
        DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, async () =>
        {
            if (RootFrame.Content is MainPage page) await page.OpenPathAsync(path);
        });
    }

    private bool _closeApproved;

    private void SetInitialWindowBounds()
    {
        var displayArea = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary);
        var workArea = displayArea.WorkArea;
        var width = Math.Min(1440, workArea.Width);
        var height = Math.Min(1000, workArea.Height);

        AppWindow.Resize(new SizeInt32(width, height));
        AppWindow.Move(new PointInt32(
            workArea.X + Math.Max(0, (workArea.Width - width) / 2),
            workArea.Y + Math.Max(0, (workArea.Height - height) / 2)));
    }
}
