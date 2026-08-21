using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.Windows.ApplicationModel.Resources;
using Trimlet.Media;
using Trimlet.Platform.Windows;
using Windows.ApplicationModel.DataTransfer;
using Windows.Media.Core;
using Windows.Media.Playback;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.System;
using Windows.UI.Core;
using Rectangle = Microsoft.UI.Xaml.Shapes.Rectangle;

namespace Trimlet_Windows;

public sealed partial class MainPage : Page
{
    private static readonly TimeSpan FallbackFrameStep = TimeSpan.FromSeconds(1.0 / 30.0);

    private readonly MediaPlayer _mediaPlayer = new();
    private readonly DispatcherTimer _positionTimer = new() { Interval = TimeSpan.FromMilliseconds(100) };
    private readonly ResourceLoader _resources = new();
    private readonly FFmpegToolchain? _toolchain;
    private readonly MediaInspector? _inspector;
    private readonly ExportService? _exportService;
    private readonly List<Rectangle> _keyframeMarkers = [];
    private MediaSource? _mediaSource;
    private MediaMetadata? _metadata;
    private KeyframeIndex? _keyframeIndex;
    private CancellationTokenSource? _inspectionCancellation;
    private CancellationTokenSource? _exportCancellation;
    private ExportResult? _lastExport;
    private TimeSpan _duration;
    private TimeSpan _inPoint;
    private TimeSpan _outPoint;
    private TimeSpan _frameStep = FallbackFrameStep;
    private bool _updatingTimeline;
    private bool _mediaReady;
    private bool _previewingRange;
    private bool _isExporting;
    private bool _hasUserInPoint;
    private bool _hasUserOutPoint;

    public MainPage()
    {
        InitializeComponent();

        _toolchain = FFmpegToolchain.Discover();
        if (_toolchain is not null)
        {
            _inspector = new MediaInspector(_toolchain);
            _exportService = new ExportService(_toolchain, _inspector);
        }

        _mediaPlayer.CommandManager.IsEnabled = false;
        _mediaPlayer.MediaOpened += OnMediaOpened;
        _mediaPlayer.MediaFailed += OnMediaFailed;
        _mediaPlayer.CurrentStateChanged += OnPlayerStateChanged;
        PlayerElement.SetMediaPlayer(_mediaPlayer);

        _positionTimer.Tick += OnPositionTimerTick;
        _positionTimer.Start();
        Unloaded += OnPageUnloaded;

        if (_toolchain is null)
        {
            ShowStatus(InfoBarSeverity.Warning, Text("ToolchainMissingTitle"), Text("ToolchainMissingMessage"));
        }
    }

    private string Text(string resourceId) => _resources.GetString(resourceId);

    private async void OnOpenClicked(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        foreach (var extension in SupportedMedia.FileExtensions)
        {
            picker.FileTypeFilter.Add(extension);
        }

        InitializePicker(picker);
        var file = await picker.PickSingleFileAsync();
        if (file is not null)
        {
            await LoadMediaAsync(file);
        }
    }

    private void OnDragOver(object sender, DragEventArgs e)
    {
        if (e.DataView.Contains(StandardDataFormats.StorageItems))
        {
            e.AcceptedOperation = DataPackageOperation.Copy;
            e.DragUIOverride.Caption = Text("DropCaption");
            e.DragUIOverride.IsCaptionVisible = true;
        }
    }

    private async void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.DataView.Contains(StandardDataFormats.StorageItems))
        {
            return;
        }

        var items = await e.DataView.GetStorageItemsAsync();
        var file = items.OfType<StorageFile>().FirstOrDefault();
        if (file is null)
        {
            return;
        }

        if (!SupportedMedia.IsSupportedPath(file.Path))
        {
            ShowStatus(InfoBarSeverity.Error, Text("UnsupportedTitle"), Text("UnsupportedMessage"));
            return;
        }

        await LoadMediaAsync(file);
    }

    private async Task LoadMediaAsync(StorageFile file)
    {
        ResetPlayer();
        ClearRoutineStatus();

        try
        {
            FileNameText.Text = file.Name;
            ToolTipService.SetToolTip(FileNameText, file.Path);

            _mediaSource = MediaSource.CreateFromStorageFile(file);
            _mediaPlayer.Source = _mediaSource;

            if (_inspector is not null)
            {
                _inspectionCancellation = new CancellationTokenSource();
                await InspectMediaAsync(file.Path, _inspectionCancellation.Token);
            }
            else
            {
                MediaDetailsText.Text = Text("InspectionUnavailable");
            }
        }
        catch (OperationCanceledException)
        {
            // Opening another file cancels the previous inspection.
        }
        catch (MediaOperationException exception)
        {
            MediaDetailsText.Text = Text("InspectionFailed");
            ShowStatus(InfoBarSeverity.Warning, Text("InspectionFailedTitle"), $"[{exception.ErrorCode}] {exception.Message}");
        }
        catch (Exception exception)
        {
            ShowStatus(
                InfoBarSeverity.Error,
                Text("OpenFailedTitle"),
                string.Format(Text("OpenFailedFormat"), "source_unreadable", exception.Message));
        }
    }

    private async Task InspectMediaAsync(string path, CancellationToken cancellationToken)
    {
        if (_inspector is null)
        {
            return;
        }

        _metadata = await _inspector.InspectAsync(path, cancellationToken);
        _frameStep = _metadata.Video.AverageFrameRate?.FrameDuration ?? FallbackFrameStep;
        CurrentTimeText.Text = FormatTime(_mediaPlayer.PlaybackSession.Position);
        if (_duration > TimeSpan.Zero)
        {
            DurationText.Text = FormatTime(_duration);
        }
        MediaDetailsText.Text = FormatMediaDetails(_metadata);
        PopulateAudioStreams(_metadata);
        UpdateRangeDisplay();
        UpdateExportAvailability();

        KeyframeStatusText.Text = Text("KeyframeScanning");
        try
        {
            _keyframeIndex = await _inspector.InspectKeyframesAsync(_metadata, cancellationToken);
            UpdateKeyframeStatus();
            UpdateRangeTrack();
        }
        catch (MediaOperationException exception)
        {
            _keyframeIndex = null;
            KeyframeStatusText.Text = $"{Text("KeyframeUnavailable")} [{exception.ErrorCode}]";
        }
    }

    public async Task OpenPathAsync(string path)
    {
        if (!SupportedMedia.IsSupportedPath(path))
        {
            ShowStatus(InfoBarSeverity.Error, Text("UnsupportedTitle"), Text("UnsupportedMessage"));
            return;
        }

        try
        {
            var file = await StorageFile.GetFileFromPathAsync(Path.GetFullPath(path));
            await LoadMediaAsync(file);
        }
        catch (Exception exception)
        {
            ShowStatus(
                InfoBarSeverity.Error,
                Text("OpenFailedTitle"),
                string.Format(Text("OpenFailedFormat"), "source_unreadable", exception.Message));
        }
    }

    private void OnMediaOpened(MediaPlayer sender, object args)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            _duration = _mediaPlayer.PlaybackSession.NaturalDuration;
            if (_duration <= TimeSpan.Zero && _metadata is not null)
            {
                _duration = _metadata.Duration.ToTimeSpan();
            }

            if (_duration <= TimeSpan.Zero)
            {
                ShowStatus(InfoBarSeverity.Error, Text("OpenFailedTitle"), Text("DurationUnavailable"));
                return;
            }

            _mediaReady = true;
            _inPoint = TimeSpan.Zero;
            _outPoint = _duration;
            _hasUserInPoint = false;
            _hasUserOutPoint = false;
            TimelineSlider.Maximum = _duration.TotalSeconds;
            TimelineSlider.Value = 0;
            DurationText.Text = FormatTime(_duration);
            EmptyPlayerPanel.Visibility = Visibility.Collapsed;
            SetMediaControlsEnabled(true);
            UpdateRangeDisplay();
            UpdateRangeTrack();
            ClearRoutineStatus();
            Focus(FocusState.Programmatic);
        });
    }

    private void OnMediaFailed(MediaPlayer sender, MediaPlayerFailedEventArgs args)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            SetMediaControlsEnabled(false);
            ShowStatus(
                InfoBarSeverity.Error,
                Text("OpenFailedTitle"),
                string.Format(Text("OpenFailedFormat"), "unsupported_streams", args.ErrorMessage));
        });
    }

    private void OnPlayerStateChanged(MediaPlayer sender, object args)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            var playing = _mediaPlayer.PlaybackSession.PlaybackState == MediaPlaybackState.Playing;
            PlayPauseButton.Content = playing ? Text("PauseButtonText") : Text("PlayButtonText");
        });
    }

    private void OnPositionTimerTick(object? sender, object e)
    {
        if (!_mediaReady)
        {
            return;
        }

        var position = _mediaPlayer.PlaybackSession.Position;
        if (_previewingRange && position >= _outPoint)
        {
            _previewingRange = false;
            _mediaPlayer.Pause();
            position = _outPoint;
            _mediaPlayer.PlaybackSession.Position = position;
        }

        _updatingTimeline = true;
        TimelineSlider.Value = Math.Clamp(position.TotalSeconds, 0, TimelineSlider.Maximum);
        _updatingTimeline = false;
        CurrentTimeText.Text = FormatTime(position);
    }

    private void OnTimelineValueChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (!_mediaReady || _updatingTimeline)
        {
            return;
        }

        _previewingRange = false;
        var position = TimeSpan.FromSeconds(Math.Clamp(e.NewValue, 0, _duration.TotalSeconds));
        _mediaPlayer.PlaybackSession.Position = position;
        CurrentTimeText.Text = FormatTime(position);
    }

    private void OnPlayPauseClicked(object sender, RoutedEventArgs e) => TogglePlayback();

    private void TogglePlayback()
    {
        if (!_mediaReady)
        {
            return;
        }

        _previewingRange = false;
        if (_mediaPlayer.PlaybackSession.PlaybackState == MediaPlaybackState.Playing)
        {
            _mediaPlayer.Pause();
        }
        else
        {
            _mediaPlayer.Play();
        }
    }

    private void OnBackFiveClicked(object sender, RoutedEventArgs e) => SeekBy(TimeSpan.FromSeconds(-5));
    private void OnForwardFiveClicked(object sender, RoutedEventArgs e) => SeekBy(TimeSpan.FromSeconds(5));
    private void OnBackFrameClicked(object sender, RoutedEventArgs e) => StepBy(-1);
    private void OnForwardFrameClicked(object sender, RoutedEventArgs e) => StepBy(1);
    private void OnBackTenFrameClicked(object sender, RoutedEventArgs e) => StepBy(-10);
    private void OnForwardTenFrameClicked(object sender, RoutedEventArgs e) => StepBy(10);

    private void StepBy(int frames)
    {
        _mediaPlayer.Pause();
        SeekBy(TimeSpan.FromTicks(_frameStep.Ticks * frames));
    }

    private void SeekBy(TimeSpan delta)
    {
        if (!_mediaReady)
        {
            return;
        }

        _previewingRange = false;
        var seconds = Math.Clamp(
            _mediaPlayer.PlaybackSession.Position.TotalSeconds + delta.TotalSeconds,
            0,
            _duration.TotalSeconds);
        _mediaPlayer.PlaybackSession.Position = TimeSpan.FromSeconds(seconds);
    }

    private void OnMarkInClicked(object sender, RoutedEventArgs e) => SetInPoint();
    private void OnMarkOutClicked(object sender, RoutedEventArgs e) => SetOutPoint();

    private void SetInPoint()
    {
        var candidate = _mediaPlayer.PlaybackSession.Position;
        if (candidate >= _outPoint)
        {
            ShowStatus(InfoBarSeverity.Error, Text("InvalidRangeTitle"), Text("InvalidInMessage"));
            return;
        }

        _inPoint = candidate;
        _hasUserInPoint = true;
        _hasUserOutPoint = false;
        UpdateRangeDisplay();
        ClearRoutineStatus();
    }

    private void SetOutPoint()
    {
        var candidate = _mediaPlayer.PlaybackSession.Position;
        if (candidate <= _inPoint)
        {
            ShowStatus(InfoBarSeverity.Error, Text("InvalidRangeTitle"), Text("InvalidOutMessage"));
            return;
        }

        _outPoint = candidate;
        _hasUserOutPoint = true;
        UpdateRangeDisplay();
        ClearRoutineStatus();
    }

    private void OnGoToInClicked(object sender, RoutedEventArgs e) => SeekTo(_inPoint);
    private void OnGoToOutClicked(object sender, RoutedEventArgs e) => SeekTo(_outPoint);

    private void SeekTo(TimeSpan position)
    {
        if (!_mediaReady)
        {
            return;
        }

        _mediaPlayer.Pause();
        _previewingRange = false;
        _mediaPlayer.PlaybackSession.Position = position;
    }

    private void OnPreviewRangeClicked(object sender, RoutedEventArgs e)
    {
        if (!_mediaReady || _outPoint <= _inPoint)
        {
            return;
        }

        _mediaPlayer.PlaybackSession.Position = _inPoint;
        _previewingRange = true;
        _mediaPlayer.Play();
    }

    private async void OnExportClicked(object sender, RoutedEventArgs e)
    {
        if (_metadata is null || _exportService is null || _isExporting)
        {
            return;
        }

        var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.VideosLibrary };
        picker.FileTypeFilter.Add("*");
        InitializePicker(picker);
        var folder = await picker.PickSingleFolderAsync();
        if (folder is null)
        {
            return;
        }

        _mediaPlayer.Pause();
        _isExporting = true;
        _lastExport = null;
        _exportCancellation = new CancellationTokenSource();
        SetMediaControlsEnabled(false);
        ExportProgressPanel.Visibility = Visibility.Visible;
        ExportProgressBar.Value = 0;
        ExportProgressBar.IsIndeterminate = false;
        ExportProgressText.Text = Text("ExportStarting");
        CancelExportButton.IsEnabled = true;
        CancelExportButton.Visibility = Visibility.Visible;
        RevealOutputButton.Visibility = Visibility.Collapsed;
        ClearRoutineStatus();

        var progress = new Progress<ExportProgress>(value =>
        {
            ExportProgressBar.Value = value.Fraction;
            ExportProgressText.Text = value.Stage == "validating"
                ? Text("ExportValidating")
                : string.Format(Text("ExportProgressFormat"), Math.Round(value.Fraction * 100), FormatTime(value.Elapsed));
        });

        try
        {
            var range = CurrentRange();
            var mode = CurrentExportMode();
            var audioIndex = SelectedAudioIndex();
            var candidate = mode == ExportMode.Fast ? _keyframeIndex?.FastCandidate(range) : null;
            _lastExport = await _exportService.ExportAsync(
                _metadata,
                range,
                mode,
                folder.Path,
                audioIndex,
                candidate,
                progress,
                _exportCancellation.Token);

            ExportProgressBar.Value = 1;
            ExportProgressText.Text = string.Format(Text("ExportCompletedFormat"), Path.GetFileName(_lastExport.OutputPath));
            CancelExportButton.Visibility = Visibility.Collapsed;
            RevealOutputButton.Visibility = Visibility.Visible;
            ClearRoutineStatus();
        }
        catch (OperationCanceledException)
        {
            ExportProgressBar.Value = 0;
            ExportProgressText.Text = Text("ExportCancelledMessage");
            CancelExportButton.Visibility = Visibility.Collapsed;
            ClearRoutineStatus();
        }
        catch (MediaOperationException exception)
        {
            ExportProgressBar.Value = 0;
            ExportProgressText.Text = $"[{exception.ErrorCode}] {exception.Message}";
            CancelExportButton.Visibility = Visibility.Collapsed;
            ShowStatus(InfoBarSeverity.Error, Text("ExportFailedTitle"), $"[{exception.ErrorCode}] {exception.Message}");
        }
        catch (Exception exception)
        {
            ExportProgressBar.Value = 0;
            ExportProgressText.Text = exception.Message;
            CancelExportButton.Visibility = Visibility.Collapsed;
            ShowStatus(InfoBarSeverity.Error, Text("ExportFailedTitle"), $"[export_failed] {exception.Message}");
        }
        finally
        {
            _isExporting = false;
            _exportCancellation?.Dispose();
            _exportCancellation = null;
            SetMediaControlsEnabled(_mediaReady);
        }
    }

    private void OnCancelExportClicked(object sender, RoutedEventArgs e)
    {
        CancelExportButton.IsEnabled = false;
        ExportProgressText.Text = Text("ExportCancelling");
        _exportCancellation?.Cancel();
    }

    private void OnRevealOutputClicked(object sender, RoutedEventArgs e)
    {
        if (_lastExport is not null)
        {
            ExportService.RevealInExplorer(_lastExport.OutputPath);
        }
    }

    private void OnPageKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (!_mediaReady || _isExporting)
        {
            return;
        }

        var shift = (InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Shift) & CoreVirtualKeyStates.Down) != 0;
        switch (e.Key)
        {
            case VirtualKey.Space:
                TogglePlayback();
                e.Handled = true;
                break;
            case VirtualKey.Left:
                StepBy(shift ? -10 : -1);
                e.Handled = true;
                break;
            case VirtualKey.Right:
                StepBy(shift ? 10 : 1);
                e.Handled = true;
                break;
            case VirtualKey.I:
                SetInPoint();
                e.Handled = true;
                break;
            case VirtualKey.O:
                SetOutPoint();
                e.Handled = true;
                break;
        }
    }

    private void UpdateRangeDisplay()
    {
        InTimeText.Text = FormatTime(_inPoint);
        OutTimeText.Text = FormatTime(_outPoint);
        RangeDurationText.Text = _outPoint > _inPoint
            ? string.Format(Text("RangeDurationFormat"), FormatTime(_outPoint - _inPoint))
            : Text("RangeNotReadyText");
        UpdateRangeTrack();
        UpdateKeyframeStatus();
        UpdateExportAvailability();
        UpdateRangeWorkflow();
    }

    private void UpdateRangeWorkflow()
    {
        var accentStyle = (Style)Application.Current.Resources["AccentButtonStyle"];
        MarkInButton.Style = _mediaReady && !_hasUserInPoint ? accentStyle : null;
        MarkOutButton.Style = _mediaReady && _hasUserInPoint && !_hasUserOutPoint ? accentStyle : null;
    }

    private void UpdateRangeTrack()
    {
        if (!_mediaReady || _duration <= TimeSpan.Zero || RangeTrackCanvas.ActualWidth <= 0)
        {
            SelectionRangeHighlight.Width = 0;
            return;
        }

        var width = RangeTrackCanvas.ActualWidth;
        var start = Math.Clamp(_inPoint.TotalSeconds / _duration.TotalSeconds, 0, 1);
        var end = Math.Clamp(_outPoint.TotalSeconds / _duration.TotalSeconds, 0, 1);
        Canvas.SetLeft(SelectionRangeHighlight, width * start);
        SelectionRangeHighlight.Width = width * Math.Max(0, end - start);

        foreach (var marker in _keyframeMarkers)
        {
            RangeTrackCanvas.Children.Remove(marker);
        }

        _keyframeMarkers.Clear();
        if (_keyframeIndex is null || _keyframeIndex.Keyframes.Count == 0)
        {
            return;
        }

        var stride = Math.Max(1, _keyframeIndex.Keyframes.Count / Math.Max(1, (int)(width / 5)));
        for (var index = 0; index < _keyframeIndex.Keyframes.Count; index += stride)
        {
            var marker = new Rectangle
            {
                Width = 1,
                Height = 6,
                Fill = new SolidColorBrush(Microsoft.UI.Colors.Orange),
                Opacity = 0.85,
                IsHitTestVisible = false,
            };
            Canvas.SetLeft(marker, width * _keyframeIndex.Keyframes[index].TotalSeconds / _duration.TotalSeconds);
            Canvas.SetTop(marker, 2);
            _keyframeMarkers.Add(marker);
            RangeTrackCanvas.Children.Add(marker);
        }
    }

    private void OnRangeTrackSizeChanged(object sender, SizeChangedEventArgs e) => UpdateRangeTrack();

    private void UpdateKeyframeStatus()
    {
        if (!_mediaReady)
        {
            return;
        }

        if (_keyframeIndex is null)
        {
            KeyframeStatusText.Text = _metadata is null ? string.Empty : Text("KeyframeScanning");
            return;
        }

        var range = CurrentRange();
        var candidate = _keyframeIndex.FastCandidate(range);
        KeyframeStatusText.Text = candidate is null
            ? string.Empty
            : string.Format(Text("FastCandidateFormat"), FormatTime(candidate.Start.ToTimeSpan()), FormatTime(candidate.End.ToTimeSpan()));
    }

    private void PopulateAudioStreams(MediaMetadata metadata)
    {
        AudioStreamPicker.Items.Clear();
        foreach (var audio in metadata.AudioStreams)
        {
            var language = string.Equals(audio.Language, "und", StringComparison.OrdinalIgnoreCase)
                || string.IsNullOrWhiteSpace(audio.Language)
                ? null
                : audio.Language;
            AudioStreamPicker.Items.Add(new ComboBoxItem
            {
                Content = language is null
                    ? string.Format(Text("AudioStreamFormat"), audio.AudioIndex + 1, audio.Codec.ToUpperInvariant(), audio.Channels)
                    : string.Format(Text("AudioStreamWithLanguageFormat"), audio.AudioIndex + 1, audio.Codec.ToUpperInvariant(), audio.Channels, language),
                Tag = audio.AudioIndex,
            });
        }

        if (AudioStreamPicker.Items.Count > 0)
        {
            var defaultIndex = metadata.AudioStreams.ToList().FindIndex(audio => audio.IsDefault);
            AudioStreamPicker.SelectedIndex = defaultIndex >= 0 ? defaultIndex : 0;
            AudioStreamPicker.IsEnabled = true;
        }
        else
        {
            AudioStreamPicker.Items.Add(new ComboBoxItem { Content = Text("NoAudioStream"), Tag = -1 });
            AudioStreamPicker.SelectedIndex = 0;
            AudioStreamPicker.IsEnabled = false;
        }
    }

    private string FormatMediaDetails(MediaMetadata metadata)
    {
        var video = metadata.Video;
        var interlace = video.IsInterlaced ? string.Format(Text("InterlacedFormat"), video.FieldOrder) : Text("ProgressiveLabel");
        return string.Format(
            Text("MediaDetailsFormat"),
            video.Codec.ToUpperInvariant(),
            video.Width,
            video.Height,
            video.AverageFrameRate?.ToString() ?? Text("FrameRateUnknown"),
            interlace);
    }

    private int SelectedAudioIndex() =>
        AudioStreamPicker.SelectedItem is ComboBoxItem { Tag: int audioIndex } ? audioIndex : -1;

    private ExportMode CurrentExportMode() =>
        AccurateModeButton.IsChecked == true ? ExportMode.Accurate : ExportMode.Fast;

    private TrimRange CurrentRange() => new(
        MediaTimestamp.FromTimeSpan(_inPoint),
        MediaTimestamp.FromTimeSpan(_outPoint));

    private void UpdateExportAvailability()
    {
        var enabled = _mediaReady && _metadata is not null && _exportService is not null && _outPoint > _inPoint && !_isExporting;
        ExportButton.IsEnabled = enabled;
        PreviewRangeButton.IsEnabled = _mediaReady && _outPoint > _inPoint && !_isExporting;
    }

    private void SetMediaControlsEnabled(bool enabled)
    {
        var interactive = enabled && !_isExporting;
        TimelineSlider.IsEnabled = interactive;
        PlayPauseButton.IsEnabled = interactive;
        BackFiveButton.IsEnabled = interactive;
        BackTenFrameButton.IsEnabled = interactive;
        BackFrameButton.IsEnabled = interactive;
        ForwardFrameButton.IsEnabled = interactive;
        ForwardTenFrameButton.IsEnabled = interactive;
        ForwardFiveButton.IsEnabled = interactive;
        MarkInButton.IsEnabled = interactive;
        MarkOutButton.IsEnabled = interactive;
        GoToInButton.IsEnabled = interactive;
        GoToOutButton.IsEnabled = interactive;
        AudioStreamPicker.IsEnabled = interactive && _metadata?.AudioStreams.Count > 0;
        UpdateExportAvailability();
    }

    private void ResetPlayer()
    {
        _inspectionCancellation?.Cancel();
        _inspectionCancellation?.Dispose();
        _inspectionCancellation = null;
        _mediaReady = false;
        _metadata = null;
        _keyframeIndex = null;
        _previewingRange = false;
        _mediaPlayer.Pause();
        _mediaPlayer.Source = null;
        _mediaSource?.Dispose();
        _mediaSource = null;
        _duration = TimeSpan.Zero;
        _inPoint = TimeSpan.Zero;
        _outPoint = TimeSpan.Zero;
        _hasUserInPoint = false;
        _hasUserOutPoint = false;
        _frameStep = FallbackFrameStep;
        EmptyPlayerPanel.Visibility = Visibility.Visible;
        SetMediaControlsEnabled(false);
        CurrentTimeText.Text = FormatTime(TimeSpan.Zero);
        DurationText.Text = FormatTime(TimeSpan.Zero);
        InTimeText.Text = FormatTime(TimeSpan.Zero);
        OutTimeText.Text = FormatTime(TimeSpan.Zero);
        RangeDurationText.Text = Text("RangeNotReadyText");
        MediaDetailsText.Text = string.Empty;
        AudioStreamPicker.Items.Clear();
        KeyframeStatusText.Text = string.Empty;
        ExportProgressPanel.Visibility = Visibility.Collapsed;
        _lastExport = null;
        UpdateRangeTrack();
    }

    private void ShowStatus(InfoBarSeverity severity, string title, string message)
    {
        StatusBar.Severity = severity;
        StatusBar.Title = title;
        StatusBar.Message = message;
        StatusBar.IsOpen = true;
    }

    private void ClearRoutineStatus()
    {
        if (_toolchain is null)
        {
            ShowStatus(InfoBarSeverity.Warning, Text("ToolchainMissingTitle"), Text("ToolchainMissingMessage"));
            return;
        }

        StatusBar.IsOpen = false;
    }

    private void OnPageUnloaded(object sender, RoutedEventArgs e)
    {
        _positionTimer.Stop();
        _inspectionCancellation?.Cancel();
        _exportCancellation?.Cancel();
        _mediaPlayer.Dispose();
        _mediaSource?.Dispose();
    }

    private void InitializePicker(object picker)
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, windowHandle);
    }

    private string FormatTime(TimeSpan value)
    {
        if (value < TimeSpan.Zero)
        {
            value = TimeSpan.Zero;
        }

        if (_metadata?.Video.AverageFrameRate is { } frameRate)
        {
            var wholeSeconds = Math.Floor(value.TotalSeconds);
            var frameBase = Math.Max(1, (int)Math.Round(frameRate.FramesPerSecond));
            var frame = Math.Clamp((int)Math.Floor((value.TotalSeconds - wholeSeconds) * frameRate.FramesPerSecond), 0, frameBase - 1);
            var hours = (int)(wholeSeconds / 3600);
            var minutes = (int)(wholeSeconds / 60) % 60;
            var seconds = (int)wholeSeconds % 60;
            return $"{hours:00}:{minutes:00}:{seconds:00}:{frame:00}";
        }

        return $"{(int)value.TotalHours:00}:{value.Minutes:00}:{value.Seconds:00}.{value.Milliseconds:000}";
    }

}
