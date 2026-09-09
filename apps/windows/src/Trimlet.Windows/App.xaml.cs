using Windows.ApplicationModel;
using Windows.ApplicationModel.Activation;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Data;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using Microsoft.UI.Xaml.Shapes;

// To learn more about WinUI, the WinUI project structure,
// and more about our project templates, see: http://aka.ms/winui-project-info.

namespace Trimlet_Windows;

/// <summary>
/// Provides application-specific behavior to supplement the default Application class.
/// </summary>
public partial class App : Application
{
    public static Window MainWindow { get; private set; } = null!;

    /// <summary>
    /// Initializes the singleton application object.  This is the first line of authored code
    /// executed, and as such is the logical equivalent of main() or WinMain().
    /// </summary>
    public App()
    {
        UnhandledException += (_, exception) =>
        {
            try
            {
                var directory = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Trimlet", "Diagnostics");
                System.IO.Directory.CreateDirectory(directory);
                // Deliberately omit exception messages: media paths can occur in them.
                System.IO.File.AppendAllText(System.IO.Path.Combine(directory, "application.log"),
                    $"{DateTimeOffset.UtcNow:O} {exception.Exception.GetType().Name} 0x{exception.Exception.HResult:X8}\n{exception.Exception.StackTrace}\n");
            }
            catch { /* Logging must not mask the original failure. */ }
        };
        InitializeComponent();
    }

    /// <summary>
    /// Invoked when the application is launched.
    /// </summary>
    /// <param name="args">Details about the launch request and process.</param>
    protected override void OnLaunched(Microsoft.UI.Xaml.LaunchActivatedEventArgs args)
    {
        var initialPath = Environment.GetCommandLineArgs().Skip(1).FirstOrDefault()?.Trim().Trim('"')
            ?? args.Arguments.Trim().Trim('"');
        var window = new MainWindow();
        MainWindow = window;
        MainWindow.Activate();
        if (!string.IsNullOrWhiteSpace(initialPath)) window.OpenInitialPath(initialPath);
    }
}
