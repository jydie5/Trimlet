using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Trimlet.Platform.Windows;
using Windows.Storage;

namespace Trimlet_Windows;

public sealed partial class MainPage
{
    private async void OnVideoToolsClicked(object sender, RoutedEventArgs e)
    {
        if (_projectBusy || _isExporting || _proxyInProgress || _confirmingClose) return;
        var content = new StackPanel { Spacing = 12 };
        content.Children.Add(new TextBlock
        {
            Text = Text(_toolchain is null ? "VideoToolsConsent" : "VideoToolsPresent"),
            TextWrapping = TextWrapping.Wrap, MaxWidth = 460,
        });
        content.Children.Add(new HyperlinkButton { Content = Text("VideoToolsDistributor"), NavigateUri = new Uri(VideoToolSetup.ReleaseUrl) });
        content.Children.Add(new HyperlinkButton { Content = "FFmpeg / LGPL / source", NavigateUri = new Uri("https://ffmpeg.org/legal.html") });
        content.Children.Add(new HyperlinkButton { Content = "LGPL 3.0", NavigateUri = new Uri("https://www.gnu.org/licenses/lgpl-3.0.html") });
        content.Children.Add(new HyperlinkButton { Content = Text("VideoToolsBuildSource"), NavigateUri = new Uri("https://github.com/BtbN/FFmpeg-Builds") });
        if (VideoToolSetup.IsInstalled)
        {
            var license = new Button { Content = Text("VideoToolsLocalLicense") };
            license.Click += async (_, _) => await Windows.System.Launcher.LaunchFileAsync(
                await StorageFile.GetFileFromPathAsync(Path.Combine(VideoToolSetup.InstallDirectory, "LICENSE.txt")));
            content.Children.Add(license);
        }
        _projectBusy = true;
        UpdateProjectDisplay();
        VideoToolsButton.IsEnabled = false;
        try
        {
            var consent = new ContentDialog
            {
                XamlRoot = XamlRoot, Title = Text("VideoToolsTitle"), Content = content,
                PrimaryButtonText = _toolchain is null ? Text("VideoToolsDownload") : "",
                CloseButtonText = Text("ProjectCancel"), DefaultButton = ContentDialogButton.Close,
            };
            if (await consent.ShowAsync() != ContentDialogResult.Primary) return;
            using var cancellation = new CancellationTokenSource();
            var progress = new ProgressBar { Minimum = 0, Maximum = 100, Width = 360 };
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot, Title = Text("VideoToolsPreparing"), Content = progress,
                CloseButtonText = Text("ProjectCancel"), DefaultButton = ContentDialogButton.Close,
            };
            dialog.CloseButtonClick += (_, _) => cancellation.Cancel();
            var display = dialog.ShowAsync();
            try
            {
                await VideoToolSetup.InstallAsync(new Progress<double>(p => progress.Value = p * 100), cancellation.Token);
            }
            finally { dialog.Hide(); await display; }
            _toolchain = FFmpegToolchain.Discover();
            if (_toolchain is null) throw new IOException("Tool discovery failed.");
            _inspector = new MediaInspector(_toolchain);
            _exportService = new ExportService(_toolchain, _inspector);
            _thumbnailService?.Dispose();
            _thumbnailService = new ThumbnailService(_toolchain);
            _proxyService = new PreviewProxyService(_toolchain, _inspector);
            if (_sourceFilePath is not null) await LoadMediaAsync(await StorageFile.GetFileFromPathAsync(_sourceFilePath));
            ShowStatus(InfoBarSeverity.Success, Text("VideoToolsReady"), "");
        }
        catch (OperationCanceledException) { ShowStatus(InfoBarSeverity.Informational, Text("VideoToolsCancelled"), ""); }
        catch (Exception) { ShowStatus(InfoBarSeverity.Error, Text("VideoToolsFailed"), Text("VideoToolsRetry")); }
        finally
        {
            _projectBusy = false;
            VideoToolsButton.IsEnabled = true;
            UpdateProjectDisplay();
        }
    }
}
