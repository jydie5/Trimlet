using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
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
    private static readonly double[] ShuttleRates = [1, 2, 4, 8];

    private readonly MediaPlayer _mediaPlayer = new();
    private readonly DispatcherTimer _positionTimer = new() { Interval = TimeSpan.FromMilliseconds(100) };
    private readonly DispatcherTimer _reverseShuttleTimer = new() { Interval = TimeSpan.FromMilliseconds(33) };
    private readonly ResourceLoader _resources = new();
    private readonly FFmpegToolchain? _toolchain;
    private readonly MediaInspector? _inspector;
    private readonly ExportService? _exportService;
    private readonly ThumbnailService? _thumbnailService;
    private readonly PreviewProxyService? _proxyService;
    private readonly ObservableCollection<ClipCardItem> _clipItems = [];
    private readonly Dictionary<Guid, ImageSource> _thumbnailImages = [];
    private readonly List<FrameworkElement> _retainedRangeMarkers = [];
    private readonly List<FrameworkElement> _fastCandidateMarkers = [];
    private readonly List<Rectangle> _keyframeMarkers = [];
    private readonly Stack<EditList> _undoStack = [];
    private readonly Stack<EditList> _redoStack = [];

    private MediaSource? _mediaSource;
    private MediaMetadata? _metadata;
    private KeyframeIndex? _keyframeIndex;
    private FrameTimestampIndex? _frameTimestampIndex;
    private CancellationTokenSource? _inspectionCancellation;
    private CancellationTokenSource? _thumbnailCancellation;
    private CancellationTokenSource? _exportCancellation;
    private CancellationTokenSource? _proxyCancellation;
    private ExportResult? _lastExport;
    private EditList _editList = new();
    private Guid? _selectedSegmentId;
    private Guid? _trimmingSegmentId;
    private TimeSpan _duration;
    private TimeSpan _inPoint;
    private TimeSpan _outPoint;
    private TimeSpan _previewStopPoint;
    private TimeSpan _frameStep = FallbackFrameStep;
    private DateTimeOffset _lastScrubSeek;
    private DateTimeOffset _reverseShuttleStartedAt;
    private TimeSpan _reverseShuttleStartPosition;
    private string? _sourceFilePath;
    private string? _proxyPath;
    private int _sequencePreviewIndex = -1;
    private int _shuttleLevel;
    private bool _updatingTimeline;
    private bool _mediaReady;
    private bool _previewingRange;
    private bool _isExporting;
    private bool _hasUserInPoint;
    private bool _hasUserOutPoint;
    private bool _isScrubbing;
    private bool _rebuildingClipItems;
    private bool _usesProxy;
    private bool _proxyInProgress;
    private bool _directPlaybackFailed;
    private bool _frameTimingScanning;

    public MainPage()
    {
        InitializeComponent();

        _toolchain = FFmpegToolchain.Discover();
        if (_toolchain is not null)
        {
            _inspector = new MediaInspector(_toolchain);
            _exportService = new ExportService(_toolchain, _inspector);
            _thumbnailService = new ThumbnailService(_toolchain);
            _proxyService = new PreviewProxyService(_toolchain, _inspector);
        }

        ClipListView.ItemsSource = _clipItems;
        _mediaPlayer.CommandManager.IsEnabled = false;
        _mediaPlayer.MediaOpened += OnMediaOpened;
        _mediaPlayer.MediaFailed += OnMediaFailed;
        _mediaPlayer.CurrentStateChanged += OnPlayerStateChanged;
        PlayerElement.SetMediaPlayer(_mediaPlayer);

        _positionTimer.Tick += OnPositionTimerTick;
        _positionTimer.Start();
        _reverseShuttleTimer.Tick += OnReverseShuttleTick;
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
        _sourceFilePath = file.Path;

        try
        {
            FileNameText.Text = file.Name;
            ToolTipService.SetToolTip(FileNameText, file.Path);
            var preferProxy = PreviewProxyService.PreferProxyForPath(file.Path);
            if (!preferProxy)
            {
                SetPlaybackSource(file, usesProxy: false);
            }

            if (_inspector is not null)
            {
                _inspectionCancellation = new CancellationTokenSource();
                await InspectMediaAsync(file.Path, _inspectionCancellation.Token);
                if (preferProxy || _directPlaybackFailed)
                {
                    await StartProxyAsync();
                }
            }
            else
            {
                MediaDetailsText.Text = Text("InspectionUnavailable");
                if (preferProxy)
                {
                    ShowStatus(InfoBarSeverity.Error, Text("ProxyFailedTitle"), Text("ProxyToolchainMissing"));
                }
            }
        }
        catch (OperationCanceledException)
        {
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
        if (_metadata.Duration.TotalSeconds > 0)
        {
            _duration = _metadata.Duration.ToTimeSpan();
            TimelineSlider.Maximum = _duration.TotalSeconds;
        }
        CurrentTimeText.Text = FormatTime(_mediaPlayer.PlaybackSession.Position);
        if (_duration > TimeSpan.Zero)
        {
            DurationText.Text = FormatTime(_duration);
        }

        MediaDetailsText.Text = FormatMediaDetails(_metadata);
        PopulateAudioStreams(_metadata);
        UpdateRangeDisplay();
        UpdateExportAvailability();

        _ = AnalyzeSourceIndexesAsync(_metadata, cancellationToken);
    }

    private async Task AnalyzeSourceIndexesAsync(MediaMetadata metadata, CancellationToken cancellationToken)
    {
        KeyframeStatusText.Text = Text("KeyframeScanning");
        try
        {
            var inspectedKeyframes = await _inspector!.InspectKeyframesAsync(metadata, cancellationToken);
            if (!ReferenceEquals(_metadata, metadata))
            {
                return;
            }

            _keyframeIndex = inspectedKeyframes;
            UpdateKeyframeStatus();
            UpdateRangeTrack();
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (MediaOperationException exception)
        {
            if (!ReferenceEquals(_metadata, metadata))
            {
                return;
            }

            _keyframeIndex = null;
            KeyframeStatusText.Text = $"{Text("KeyframeUnavailable")} [{exception.ErrorCode}]";
            UpdateExportAvailability();
        }

        if (!ReferenceEquals(_metadata, metadata))
        {
            return;
        }

        _frameTimingScanning = true;
        UpdateKeyframeStatus();
        try
        {
            var inspectedFrames = await _inspector!.InspectFrameTimestampsAsync(metadata, cancellationToken);
            if (!ReferenceEquals(_metadata, metadata))
            {
                return;
            }

            _frameTimestampIndex = inspectedFrames;
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (MediaOperationException)
        {
            _frameTimestampIndex = null;
        }
        finally
        {
            if (ReferenceEquals(_metadata, metadata))
            {
                _frameTimingScanning = false;
                UpdateKeyframeStatus();
            }
        }
    }

    private void SetPlaybackSource(StorageFile file, bool usesProxy)
    {
        _mediaPlayer.Source = null;
        _mediaSource?.Dispose();
        _mediaSource = MediaSource.CreateFromStorageFile(file);
        _usesProxy = usesProxy;
        _mediaPlayer.Source = _mediaSource;
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
            if (_metadata is not null && _metadata.Duration.TotalSeconds > 0)
            {
                _duration = _metadata.Duration.ToTimeSpan();
            }

            if (_duration <= TimeSpan.Zero)
            {
                ShowStatus(InfoBarSeverity.Error, Text("OpenFailedTitle"), Text("DurationUnavailable"));
                return;
            }

            _mediaReady = true;
            ClearDraft();
            TimelineSlider.Maximum = _duration.TotalSeconds;
            TimelineSlider.Value = 0;
            DurationText.Text = FormatTime(_duration);
            EmptyPlayerPanel.Visibility = Visibility.Collapsed;
            SetMediaControlsEnabled(true);
            UpdateRangeDisplay();
            UpdateRangeTrack();
            if (_usesProxy && _proxyPath is not null && _metadata is not null)
            {
                ProxyProgressPanel.Visibility = Visibility.Collapsed;
                MediaDetailsText.Text = $"{FormatMediaDetails(_metadata)}・{Text("ProxyPreviewSuffix")}";
                ShowStatus(
                    InfoBarSeverity.Informational,
                    Text("ProxyReadyTitle"),
                    Text("ProxyActiveMessage"));
            }
            else
            {
                ClearRoutineStatus();
            }
            Focus(FocusState.Programmatic);
        });
    }

    private void OnMediaFailed(MediaPlayer sender, MediaPlayerFailedEventArgs args)
    {
        DispatcherQueue.TryEnqueue(async () =>
        {
            SetMediaControlsEnabled(false);
            if (!_usesProxy && _proxyService is not null && _sourceFilePath is not null)
            {
                _directPlaybackFailed = true;
                if (_metadata is not null)
                {
                    await StartProxyAsync();
                }
                else
                {
                    ShowStatus(InfoBarSeverity.Informational, Text("ProxyPreparingTitle"), Text("ProxyFallbackMessage"));
                }

                return;
            }

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

    private async Task StartProxyAsync()
    {
        if (_proxyInProgress || _proxyService is null || _metadata is null || _sourceFilePath is null)
        {
            return;
        }

        var metadata = _metadata;
        var sourcePath = _sourceFilePath;

        _proxyInProgress = true;
        _mediaReady = false;
        SetMediaControlsEnabled(false);
        _mediaPlayer.Pause();
        _mediaPlayer.Source = null;
        _mediaSource?.Dispose();
        _mediaSource = null;
        _proxyCancellation?.Cancel();
        _proxyCancellation?.Dispose();
        _proxyCancellation = new CancellationTokenSource();
        ProxyProgressPanel.Visibility = Visibility.Visible;
        ProxyProgressBar.Value = 0;
        ProxyProgressText.Text = Text("ProxyStarting");
        CancelProxyButton.IsEnabled = true;
        ShowStatus(InfoBarSeverity.Informational, Text("ProxyPreparingTitle"), Text("ProxyReadOnlyMessage"));

        var progress = new Progress<PreviewProxyProgress>(value =>
        {
            if (!ReferenceEquals(_metadata, metadata) || _sourceFilePath != sourcePath)
            {
                return;
            }

            ProxyProgressBar.Value = value.Fraction;
            ProxyProgressText.Text = string.Format(
                Text("ProxyProgressFormat"),
                Math.Round(value.Fraction * 100),
                FormatTime(value.Elapsed));
        });

        try
        {
            var result = await _proxyService.GetOrCreateAsync(
                metadata,
                progress,
                _proxyCancellation.Token);
            if (!ReferenceEquals(_metadata, metadata) || _sourceFilePath != sourcePath)
            {
                return;
            }

            _proxyPath = result.Path;
            var proxyFile = await StorageFile.GetFileFromPathAsync(result.Path);
            SetPlaybackSource(proxyFile, usesProxy: true);
            ProxyProgressBar.Value = 1;
            ProxyProgressText.Text = result.ReusedCache
                ? Text("ProxyReused")
                : Text("ProxyCompleted");
            CancelProxyButton.IsEnabled = false;
            ShowStatus(
                InfoBarSeverity.Success,
                Text("ProxyReadyTitle"),
                string.Format(Text("ProxyReadyMessage"), FormatByteSize(result.SizeBytes)));
        }
        catch (OperationCanceledException)
        {
            if (!ReferenceEquals(_metadata, metadata) || _sourceFilePath != sourcePath)
            {
                return;
            }

            ProxyProgressBar.Value = 0;
            ProxyProgressText.Text = Text("ProxyCancelled");
            CancelProxyButton.IsEnabled = false;
            ShowStatus(InfoBarSeverity.Warning, Text("ProxyCancelledTitle"), Text("ProxyCancelledMessage"));
        }
        catch (MediaOperationException exception)
        {
            if (!ReferenceEquals(_metadata, metadata) || _sourceFilePath != sourcePath)
            {
                return;
            }

            ProxyProgressBar.Value = 0;
            ProxyProgressText.Text = $"[{exception.ErrorCode}] {exception.Message}";
            CancelProxyButton.IsEnabled = false;
            ShowStatus(InfoBarSeverity.Error, Text("ProxyFailedTitle"), exception.Message);
        }
        catch (Exception exception)
        {
            if (!ReferenceEquals(_metadata, metadata) || _sourceFilePath != sourcePath)
            {
                return;
            }

            ProxyProgressBar.Value = 0;
            ProxyProgressText.Text = exception.Message;
            CancelProxyButton.IsEnabled = false;
            ShowStatus(InfoBarSeverity.Error, Text("ProxyFailedTitle"), exception.Message);
        }
        finally
        {
            if (ReferenceEquals(_metadata, metadata) && _sourceFilePath == sourcePath)
            {
                _proxyInProgress = false;
            }
        }
    }

    private void OnCancelProxyClicked(object sender, RoutedEventArgs e)
    {
        CancelProxyButton.IsEnabled = false;
        ProxyProgressText.Text = Text("ProxyCancelling");
        _proxyCancellation?.Cancel();
    }

    private void OnPositionTimerTick(object? sender, object e)
    {
        if (!_mediaReady)
        {
            return;
        }

        var position = _mediaPlayer.PlaybackSession.Position;
        if (_shuttleLevel > 0 && position >= _duration - TimeSpan.FromMilliseconds(50))
        {
            StopShuttle(pause: true);
            position = _duration;
        }

        if (_previewingRange && position >= _previewStopPoint)
        {
            if (_sequencePreviewIndex >= 0 && _sequencePreviewIndex + 1 < _editList.Segments.Count)
            {
                _sequencePreviewIndex++;
                var next = _editList.Segments[_sequencePreviewIndex].Range;
                _previewStopPoint = next.Out.ToTimeSpan();
                _mediaPlayer.PlaybackSession.Position = next.In.ToTimeSpan();
                _mediaPlayer.Play();
                position = next.In.ToTimeSpan();
            }
            else
            {
                _previewingRange = false;
                _sequencePreviewIndex = -1;
                _mediaPlayer.Pause();
                position = _previewStopPoint;
                _mediaPlayer.PlaybackSession.Position = position;
            }
        }

        if (!_isScrubbing)
        {
            _updatingTimeline = true;
            TimelineSlider.Value = Math.Clamp(position.TotalSeconds, 0, TimelineSlider.Maximum);
            _updatingTimeline = false;
            CurrentTimeText.Text = FormatTime(position);
        }

        UpdatePlayhead(position);
    }

    private void OnTimelinePointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (!_mediaReady)
        {
            return;
        }

        StopShuttle(pause: true);
        CancelPreview();
        _isScrubbing = true;
        _lastScrubSeek = DateTimeOffset.MinValue;
    }

    private void OnTimelinePointerReleased(object sender, PointerRoutedEventArgs e)
    {
        if (!_mediaReady)
        {
            return;
        }

        _isScrubbing = false;
        SeekToSlider(exact: true);
    }

    private void OnTimelineValueChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (!_mediaReady || _updatingTimeline)
        {
            return;
        }

        if (_isScrubbing && DateTimeOffset.UtcNow - _lastScrubSeek < TimeSpan.FromMilliseconds(33))
        {
            CurrentTimeText.Text = FormatTime(TimeSpan.FromSeconds(e.NewValue));
            return;
        }

        SeekToSlider(exact: !_isScrubbing);
        _lastScrubSeek = DateTimeOffset.UtcNow;
    }

    private void SeekToSlider(bool exact)
    {
        var position = TimeSpan.FromSeconds(Math.Clamp(TimelineSlider.Value, 0, _duration.TotalSeconds));
        _mediaPlayer.PlaybackSession.Position = position;
        CurrentTimeText.Text = FormatTime(position);
        UpdatePlayhead(position);
        _ = exact;
    }

    private void OnPlayPauseClicked(object sender, RoutedEventArgs e) => TogglePlayback();

    private void TogglePlayback()
    {
        if (!_mediaReady)
        {
            return;
        }

        CancelPreview();
        StopShuttle(pause: false);
        if (_mediaPlayer.PlaybackSession.PlaybackState == MediaPlaybackState.Playing)
        {
            _mediaPlayer.Pause();
        }
        else
        {
            _mediaPlayer.PlaybackSession.PlaybackRate = 1;
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
        StopShuttle(pause: true);
        CancelPreview();
        if (_frameTimestampIndex is not null)
        {
            var current = MediaTimestamp.FromTimeSpan(ClampToSource(_mediaPlayer.PlaybackSession.Position));
            _mediaPlayer.PlaybackSession.Position = _frameTimestampIndex.Step(current, frames).ToTimeSpan();
            return;
        }

        SeekBy(TimeSpan.FromTicks(_frameStep.Ticks * frames));
    }

    private void SeekBy(TimeSpan delta)
    {
        if (!_mediaReady)
        {
            return;
        }

        CancelPreview();
        var seconds = Math.Clamp(
            _mediaPlayer.PlaybackSession.Position.TotalSeconds + delta.TotalSeconds,
            0,
            _duration.TotalSeconds);
        _mediaPlayer.PlaybackSession.Position = TimeSpan.FromSeconds(seconds);
    }

    private void OnReverseShuttleClicked(object sender, RoutedEventArgs e) => AdjustShuttle(-1);
    private void OnStopShuttleClicked(object sender, RoutedEventArgs e) => StopShuttle(pause: true);
    private void OnForwardShuttleClicked(object sender, RoutedEventArgs e) => AdjustShuttle(1);

    private void AdjustShuttle(int delta)
    {
        if (!_mediaReady)
        {
            return;
        }

        CancelPreview();
        var next = Math.Clamp(_shuttleLevel + delta, -ShuttleRates.Length, ShuttleRates.Length);
        if (next == 0)
        {
            StopShuttle(pause: true);
            return;
        }

        _shuttleLevel = next;
        var rate = ShuttleRates[Math.Abs(next) - 1];
        if (next > 0)
        {
            _reverseShuttleTimer.Stop();
            _mediaPlayer.PlaybackSession.PlaybackRate = rate;
            _mediaPlayer.Play();
        }
        else
        {
            _mediaPlayer.Pause();
            _reverseShuttleStartPosition = _mediaPlayer.PlaybackSession.Position;
            _reverseShuttleStartedAt = DateTimeOffset.UtcNow;
            _reverseShuttleTimer.Start();
        }

        ShuttleStatusText.Text = string.Format(
            Text(next < 0 ? "ShuttleReverseFormat" : "ShuttleForwardFormat"),
            rate);
    }

    private void OnReverseShuttleTick(object? sender, object e)
    {
        if (_shuttleLevel >= 0 || !_mediaReady)
        {
            return;
        }

        var rate = ShuttleRates[Math.Abs(_shuttleLevel) - 1];
        var elapsed = DateTimeOffset.UtcNow - _reverseShuttleStartedAt;
        var next = _reverseShuttleStartPosition.TotalSeconds - rate * elapsed.TotalSeconds;
        if (next <= 0)
        {
            _mediaPlayer.PlaybackSession.Position = TimeSpan.Zero;
            StopShuttle(pause: true);
            return;
        }

        _mediaPlayer.PlaybackSession.Position = TimeSpan.FromSeconds(next);
    }

    private void StopShuttle(bool pause)
    {
        _shuttleLevel = 0;
        _reverseShuttleTimer.Stop();
        _mediaPlayer.PlaybackSession.PlaybackRate = 1;
        if (pause)
        {
            _mediaPlayer.Pause();
        }

        if (ShuttleStatusText is not null)
        {
            ShuttleStatusText.Text = Text("ShuttleStoppedText");
        }
    }

    private void OnMarkInClicked(object sender, RoutedEventArgs e) => SetInPoint();
    private void OnMarkOutClicked(object sender, RoutedEventArgs e) => SetOutPoint();

    private void SetInPoint()
    {
        var candidate = ClampToSource(_mediaPlayer.PlaybackSession.Position);
        if (_hasUserOutPoint && candidate >= _outPoint)
        {
            ShowStatus(InfoBarSeverity.Error, Text("InvalidRangeTitle"), Text("InvalidInMessage"));
            return;
        }

        _inPoint = candidate;
        _hasUserInPoint = true;
        if (_trimmingSegmentId is null)
        {
            _hasUserOutPoint = false;
        }

        UpdateRangeDisplay();
        ClearRoutineStatus();
    }

    private void SetOutPoint()
    {
        if (!_hasUserInPoint)
        {
            return;
        }

        var candidate = ClampToSource(_mediaPlayer.PlaybackSession.Position);
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

    private void OnGoToInClicked(object sender, RoutedEventArgs e)
    {
        if (_hasUserInPoint)
        {
            SeekTo(_inPoint);
        }
    }

    private void OnGoToOutClicked(object sender, RoutedEventArgs e)
    {
        if (_hasUserOutPoint)
        {
            SeekTo(_outPoint);
        }
    }

    private void SeekTo(TimeSpan position)
    {
        if (!_mediaReady)
        {
            return;
        }

        StopShuttle(pause: true);
        CancelPreview();
        _mediaPlayer.PlaybackSession.Position = position;
    }

    private void OnPreviewRangeClicked(object sender, RoutedEventArgs e)
    {
        if (!HasValidDraft())
        {
            return;
        }

        PreviewRange(CurrentRange());
    }

    private void PreviewRange(TrimRange range, int sequenceIndex = -1)
    {
        StopShuttle(pause: true);
        _sequencePreviewIndex = sequenceIndex;
        _previewStopPoint = range.Out.ToTimeSpan();
        _mediaPlayer.PlaybackSession.Position = range.In.ToTimeSpan();
        _previewingRange = true;
        _mediaPlayer.Play();
    }

    private void OnCommitRangeClicked(object sender, RoutedEventArgs e)
    {
        if (_metadata is null || !HasValidDraft())
        {
            return;
        }

        try
        {
            var range = CurrentRange();
            EditList updated;
            Guid thumbnailId;
            if (_trimmingSegmentId is { } trimmingId && _editList.Segment(trimmingId) is { } existing)
            {
                updated = _editList.Update(existing.WithRange(range), _metadata.Duration);
                thumbnailId = trimmingId;
                _thumbnailImages.Remove(trimmingId);
            }
            else
            {
                var segment = new EditSegment(Guid.NewGuid(), DefaultClipName(range), range);
                updated = _editList.Add(segment, _metadata.Duration);
                thumbnailId = segment.Id;
            }

            ApplyMutation(updated);
            ClearDraft();
            RebuildClipItems(thumbnailId);
        }
        catch (InvalidDataException exception)
        {
            var message = exception.Message.Contains("overlap", StringComparison.OrdinalIgnoreCase)
                ? Text("OverlapMessage")
                : exception.Message;
            ShowStatus(InfoBarSeverity.Error, Text("InvalidRangeTitle"), message);
        }
    }

    private void OnCancelTrimClicked(object sender, RoutedEventArgs e)
    {
        ClearDraft();
        UpdateRangeDisplay();
    }

    private void OnClipSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_rebuildingClipItems)
        {
            return;
        }

        _selectedSegmentId = ClipListView.SelectedItem is ClipCardItem item ? item.Id : null;
        UpdateRangeTrack();
    }

    private void OnPreviewClipClicked(object sender, RoutedEventArgs e)
    {
        if (TryGetButtonSegment(sender, out var segment))
        {
            _selectedSegmentId = segment.Id;
            SelectClipItem(segment.Id);
            PreviewRange(segment.Range);
        }
    }

    private void OnTrimClipClicked(object sender, RoutedEventArgs e)
    {
        if (!TryGetButtonSegment(sender, out var segment))
        {
            return;
        }

        CancelPreview();
        _trimmingSegmentId = segment.Id;
        _selectedSegmentId = segment.Id;
        _inPoint = segment.Range.In.ToTimeSpan();
        _outPoint = segment.Range.Out.ToTimeSpan();
        _hasUserInPoint = true;
        _hasUserOutPoint = true;
        SelectClipItem(segment.Id);
        UpdateRangeDisplay();
    }

    private void OnDeleteClipClicked(object sender, RoutedEventArgs e)
    {
        if (!TryGetButtonSegment(sender, out var segment))
        {
            return;
        }

        ApplyMutation(_editList.Remove(segment.Id));
        _thumbnailImages.Remove(segment.Id);
        ClearDraft();
        RebuildClipItems();
    }

    private void OnMoveEarlierClicked(object sender, RoutedEventArgs e) => MoveClip(sender, -1);
    private void OnMoveLaterClicked(object sender, RoutedEventArgs e) => MoveClip(sender, 1);

    private void MoveClip(object sender, int offset)
    {
        if (!TryGetButtonSegment(sender, out var segment))
        {
            return;
        }

        var index = _editList.Segments.ToList().FindIndex(item => item.Id == segment.Id);
        var destination = Math.Clamp(index + offset, 0, _editList.Segments.Count - 1);
        if (destination == index)
        {
            return;
        }

        ApplyMutation(_editList.Move(segment.Id, destination));
        _selectedSegmentId = segment.Id;
        RebuildClipItems();
    }

    private void OnClipDragItemsCompleted(ListViewBase sender, DragItemsCompletedEventArgs args)
    {
        if (_rebuildingClipItems || _clipItems.Count != _editList.Segments.Count)
        {
            return;
        }

        var ordered = _clipItems
            .Select(item => _editList.Segment(item.Id))
            .OfType<EditSegment>()
            .ToArray();
        var updated = new EditList(ordered);
        if (!updated.Equals(_editList))
        {
            ApplyMutation(updated, rebuild: false);
            UpdateSequenceSummary();
            UpdateRangeTrack();
        }
    }

    private void OnClipNameLostFocus(object sender, RoutedEventArgs e)
    {
        if (sender is not TextBox { Tag: Guid id } textBox || _editList.Segment(id) is not { } segment)
        {
            return;
        }

        var name = textBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            textBox.Text = segment.Name;
            return;
        }

        if (!string.Equals(name, segment.Name, StringComparison.Ordinal))
        {
            ApplyMutation(_editList.Update(segment.WithName(name), _metadata?.Duration));
            RebuildClipItems();
        }
    }

    private void OnUndoClicked(object sender, RoutedEventArgs e)
    {
        if (_undoStack.Count == 0)
        {
            return;
        }

        _redoStack.Push(_editList);
        _editList = _undoStack.Pop();
        ClearDraft();
        RebuildClipItems();
    }

    private void OnRedoClicked(object sender, RoutedEventArgs e)
    {
        if (_redoStack.Count == 0)
        {
            return;
        }

        _undoStack.Push(_editList);
        _editList = _redoStack.Pop();
        ClearDraft();
        RebuildClipItems();
    }

    private void OnPreviewSequenceClicked(object sender, RoutedEventArgs e)
    {
        if (_editList.IsEmpty)
        {
            return;
        }

        PreviewRange(_editList.Segments[0].Range, sequenceIndex: 0);
    }

    private void ApplyMutation(EditList updated, bool rebuild = true)
    {
        CancelPreview();
        _undoStack.Push(_editList);
        _redoStack.Clear();
        _editList = updated;
        if (rebuild)
        {
            RebuildClipItems();
        }
    }

    private async void RebuildClipItems(Guid? forceThumbnailId = null)
    {
        _rebuildingClipItems = true;
        _clipItems.Clear();
        foreach (var segment in _editList.Segments)
        {
            _thumbnailImages.TryGetValue(segment.Id, out var thumbnail);
            _clipItems.Add(new ClipCardItem(
                segment.Id,
                segment.Name,
                $"{FormatTime(segment.Range.In.ToTimeSpan())}–{FormatTime(segment.Range.Out.ToTimeSpan())}",
                string.Format(Text("ClipDurationFormat"), FormatTime(segment.Range.Duration.ToTimeSpan())),
                thumbnail));
        }

        _rebuildingClipItems = false;
        SelectClipItem(_selectedSegmentId);
        UpdateSequenceSummary();
        UpdateRangeTrack();
        UpdateExportAvailability();

        if (_metadata is null || _thumbnailService is null)
        {
            return;
        }

        _thumbnailCancellation ??= new CancellationTokenSource();
        var missing = _editList.Segments.Where(segment =>
            !_thumbnailImages.ContainsKey(segment.Id) || segment.Id == forceThumbnailId).ToArray();
        foreach (var segment in missing)
        {
            try
            {
                var path = await _thumbnailService.GenerateAsync(_metadata.SourcePath, segment, _thumbnailCancellation.Token);
                if (path is null)
                {
                    continue;
                }

                var file = await StorageFile.GetFileFromPathAsync(path);
                await using var stream = await file.OpenStreamForReadAsync();
                var image = new BitmapImage();
                await image.SetSourceAsync(stream.AsRandomAccessStream());
                _thumbnailImages[segment.Id] = image;
                var item = _clipItems.FirstOrDefault(candidate => candidate.Id == segment.Id);
                if (item is not null)
                {
                    item.Thumbnail = image;
                }
            }
            catch (OperationCanceledException)
            {
                return;
            }
            catch
            {
                // A placeholder remains visible when thumbnail generation fails.
            }
        }
    }

    private void SelectClipItem(Guid? id)
    {
        ClipListView.SelectedItem = id is null ? null : _clipItems.FirstOrDefault(item => item.Id == id);
    }

    private bool TryGetButtonSegment(object sender, out EditSegment segment)
    {
        if (sender is Button { Tag: Guid id } && _editList.Segment(id) is { } found)
        {
            segment = found;
            return true;
        }

        segment = null!;
        return false;
    }

    private async void OnExportClicked(object sender, RoutedEventArgs e)
    {
        if (_metadata is null || _exportService is null || _isExporting || _editList.IsEmpty)
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

        StopShuttle(pause: true);
        CancelPreview();
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
            _lastExport = await _exportService.ExportEditListAsync(
                _metadata,
                _editList,
                CurrentExportMode(),
                folder.Path,
                SelectedAudioIndex(),
                _keyframeIndex,
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

    private void OnExportModeChanged(object sender, RoutedEventArgs e)
    {
        if (ExportButton is not null)
        {
            UpdateExportAvailability();
            UpdateRangeTrack();
        }
    }

    private bool KeyboardCommandAllowed() =>
        _mediaReady && !_isExporting && FocusManager.GetFocusedElement(XamlRoot) is not TextBox and not ComboBox;

    private void OnSetInAccelerator(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        if (!KeyboardCommandAllowed()) return;
        SetInPoint();
        args.Handled = true;
    }

    private void OnSetOutAccelerator(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        if (!KeyboardCommandAllowed()) return;
        SetOutPoint();
        args.Handled = true;
    }

    private void OnReverseAccelerator(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        if (!KeyboardCommandAllowed()) return;
        AdjustShuttle(-1);
        args.Handled = true;
    }

    private void OnStopAccelerator(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        if (!KeyboardCommandAllowed()) return;
        StopShuttle(pause: true);
        args.Handled = true;
    }

    private void OnForwardAccelerator(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        if (!KeyboardCommandAllowed()) return;
        AdjustShuttle(1);
        args.Handled = true;
    }

    private void OnPageKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (!_mediaReady || _isExporting || e.OriginalSource is TextBox or ComboBox)
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
            case VirtualKey.J:
                AdjustShuttle(-1);
                e.Handled = true;
                break;
            case VirtualKey.K:
                StopShuttle(pause: true);
                e.Handled = true;
                break;
            case VirtualKey.L:
                AdjustShuttle(1);
                e.Handled = true;
                break;
        }
    }

    private void UpdateRangeDisplay()
    {
        InTimeText.Text = _hasUserInPoint ? FormatTime(_inPoint) : "—";
        OutTimeText.Text = _hasUserOutPoint ? FormatTime(_outPoint) : "—";
        RangeDurationText.Text = HasValidDraft()
            ? string.Format(Text("RangeDurationFormat"), FormatTime(_outPoint - _inPoint))
            : Text("RangeNotReadyText");
        RangeHeadingText.Text = _trimmingSegmentId is null ? Text("RangeHeadingText") : Text("TrimModeHeadingText");
        CommitRangeButton.Content = _trimmingSegmentId is null ? Text("AddToSequenceButtonText") : Text("ApplyTrimButtonText");
        CancelTrimButton.Visibility = _trimmingSegmentId is null ? Visibility.Collapsed : Visibility.Visible;
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
        MarkOutButton.IsEnabled = _mediaReady && _hasUserInPoint && !_isExporting;
        CommitRangeButton.IsEnabled = HasValidDraft() && !_isExporting;
        GoToInButton.IsEnabled = _mediaReady && _hasUserInPoint && !_isExporting;
        GoToOutButton.IsEnabled = _mediaReady && _hasUserOutPoint && !_isExporting;
        PreviewRangeButton.IsEnabled = HasValidDraft() && !_isExporting;
    }

    private void UpdateRangeTrack()
    {
        RemoveTrackElements(_retainedRangeMarkers);
        RemoveTrackElements(_fastCandidateMarkers);
        RemoveTrackElements(_keyframeMarkers);

        if (!_mediaReady || _duration <= TimeSpan.Zero || RangeTrackCanvas.ActualWidth <= 0)
        {
            DraftRangeHighlight.Visibility = Visibility.Collapsed;
            return;
        }

        var width = RangeTrackCanvas.ActualWidth;
        foreach (var segment in _editList.Segments)
        {
            var marker = new Border
            {
                Height = 18,
                Background = new SolidColorBrush(segment.Id == _selectedSegmentId
                    ? Microsoft.UI.ColorHelper.FromArgb(220, 30, 64, 175)
                    : Microsoft.UI.ColorHelper.FromArgb(175, 37, 99, 235)),
                CornerRadius = new CornerRadius(3),
                IsHitTestVisible = false,
            };
            PlaceRange(marker, segment.Range, width, 0);
            Canvas.SetZIndex(marker, 1);
            _retainedRangeMarkers.Add(marker);
            RangeTrackCanvas.Children.Add(marker);

            if (_keyframeIndex?.FastCandidate(segment.Range) is { } candidate)
            {
                var fastMarker = new Border
                {
                    Height = 14,
                    BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.Orange),
                    BorderThickness = new Thickness(1),
                    CornerRadius = new CornerRadius(3),
                    IsHitTestVisible = false,
                };
                PlaceRange(fastMarker, new TrimRange(candidate.Start, candidate.End), width, 2);
                Canvas.SetZIndex(fastMarker, 2);
                _fastCandidateMarkers.Add(fastMarker);
                RangeTrackCanvas.Children.Add(fastMarker);
            }
        }

        if (HasValidDraft())
        {
            DraftRangeHighlight.Visibility = Visibility.Visible;
            PlaceRange(DraftRangeHighlight, CurrentRange(), width, 0);
            Canvas.SetZIndex(DraftRangeHighlight, 3);
        }
        else
        {
            DraftRangeHighlight.Visibility = Visibility.Collapsed;
        }

        PlacePointMarker(InMarker, _inPoint, _hasUserInPoint, width, 4);
        PlacePointMarker(OutMarker, _outPoint, _hasUserOutPoint, width, 4);
        UpdatePlayhead(_mediaPlayer.PlaybackSession.Position);

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
            Canvas.SetTop(marker, 6);
            Canvas.SetZIndex(marker, 5);
            _keyframeMarkers.Add(marker);
            RangeTrackCanvas.Children.Add(marker);
        }
    }

    private void PlaceRange(FrameworkElement element, TrimRange range, double width, double top)
    {
        var start = Math.Clamp(range.In.TotalSeconds / _duration.TotalSeconds, 0, 1);
        var end = Math.Clamp(range.Out.TotalSeconds / _duration.TotalSeconds, 0, 1);
        Canvas.SetLeft(element, width * start);
        Canvas.SetTop(element, top);
        element.Width = width * Math.Max(0, end - start);
    }

    private void PlacePointMarker(FrameworkElement marker, TimeSpan time, bool visible, double width, int zIndex)
    {
        marker.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
        if (!visible)
        {
            return;
        }

        Canvas.SetLeft(marker, width * Math.Clamp(time.TotalSeconds / _duration.TotalSeconds, 0, 1));
        Canvas.SetZIndex(marker, zIndex);
    }

    private void UpdatePlayhead(TimeSpan position)
    {
        if (!_mediaReady || _duration <= TimeSpan.Zero || RangeTrackCanvas.ActualWidth <= 0)
        {
            return;
        }

        Canvas.SetLeft(PlayheadMarker, RangeTrackCanvas.ActualWidth * Math.Clamp(position.TotalSeconds / _duration.TotalSeconds, 0, 1));
        Canvas.SetZIndex(PlayheadMarker, 6);
    }

    private void RemoveTrackElements<T>(List<T> elements) where T : FrameworkElement
    {
        foreach (var element in elements)
        {
            RangeTrackCanvas.Children.Remove(element);
        }

        elements.Clear();
    }

    private void OnRangeTrackSizeChanged(object sender, SizeChangedEventArgs e) => UpdateRangeTrack();

    private void UpdateKeyframeStatus()
    {
        if (!_mediaReady)
        {
            return;
        }

        var frameTimingSuffix = _frameTimingScanning
            ? Text("FrameTimingScanningSuffix")
            : _frameTimestampIndex is not null
                ? string.Format(Text("FrameTimingReadySuffix"), _frameTimestampIndex.Timestamps.Count)
                : string.Empty;

        if (_keyframeIndex is null)
        {
            KeyframeStatusText.Text = _metadata is null
                ? string.Empty
                : Text("KeyframeScanning") + frameTimingSuffix;
            return;
        }

        if (HasValidDraft() && _keyframeIndex.FastCandidate(CurrentRange()) is { } candidate)
        {
            KeyframeStatusText.Text = string.Format(
                Text("FastCandidateFormat"),
                FormatTime(candidate.Start.ToTimeSpan()),
                FormatTime(candidate.End.ToTimeSpan())) + frameTimingSuffix;
        }
        else
        {
            KeyframeStatusText.Text = string.Format(Text("KeyframeReadyFormat"), _keyframeIndex.Keyframes.Count) + frameTimingSuffix;
        }
    }

    private void UpdateSequenceSummary()
    {
        SequenceSummaryText.Text = _editList.IsEmpty
            ? Text("SequenceEmptyText")
            : string.Format(Text("SequenceSummaryFormat"), _editList.Segments.Count, FormatTime(TimeSpan.FromSeconds(_editList.TotalDurationSeconds)));
        UndoButton.IsEnabled = _undoStack.Count > 0 && !_isExporting;
        RedoButton.IsEnabled = _redoStack.Count > 0 && !_isExporting;
        PreviewSequenceButton.IsEnabled = !_editList.IsEmpty && !_isExporting;
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
        }

        AudioStreamPanel.Visibility = metadata.AudioStreams.Count > 1 ? Visibility.Visible : Visibility.Collapsed;
        AudioStreamPicker.IsEnabled = metadata.AudioStreams.Count > 1;
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

    private bool HasValidDraft() => _hasUserInPoint && _hasUserOutPoint && _outPoint > _inPoint;

    private TimeSpan ClampToSource(TimeSpan value) =>
        TimeSpan.FromSeconds(Math.Clamp(value.TotalSeconds, 0, _duration.TotalSeconds));

    private TrimRange CurrentRange() => new(
        MediaTimestamp.FromTimeSpan(_inPoint),
        MediaTimestamp.FromTimeSpan(_outPoint));

    private string DefaultClipName(TrimRange range)
    {
        var source = Path.GetFileNameWithoutExtension(_metadata?.SourcePath ?? "Clip");
        return $"{source} {FormatTime(range.In.ToTimeSpan())}";
    }

    private void UpdateExportAvailability()
    {
        if (ExportButton is null)
        {
            return;
        }

        var fastReady = CurrentExportMode() != ExportMode.Fast
            || (_keyframeIndex is not null && _editList.Segments.All(segment => _keyframeIndex.FastCandidate(segment.Range) is not null));
        ExportButton.IsEnabled = _mediaReady
            && _metadata is not null
            && _exportService is not null
            && !_editList.IsEmpty
            && fastReady
            && !_isExporting;
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
        ReverseShuttleButton.IsEnabled = interactive;
        StopShuttleButton.IsEnabled = interactive;
        ForwardShuttleButton.IsEnabled = interactive;
        MarkInButton.IsEnabled = interactive;
        MarkOutButton.IsEnabled = interactive && _hasUserInPoint;
        AudioStreamPicker.IsEnabled = interactive && (_metadata?.AudioStreams.Count ?? 0) > 1;
        ClipListView.IsEnabled = interactive;
        UpdateRangeWorkflow();
        UpdateSequenceSummary();
        UpdateExportAvailability();
    }

    private void ClearDraft()
    {
        _trimmingSegmentId = null;
        _inPoint = TimeSpan.Zero;
        _outPoint = TimeSpan.Zero;
        _hasUserInPoint = false;
        _hasUserOutPoint = false;
        UpdateRangeDisplay();
    }

    private void CancelPreview()
    {
        _previewingRange = false;
        _sequencePreviewIndex = -1;
    }

    private void ResetPlayer()
    {
        _inspectionCancellation?.Cancel();
        _inspectionCancellation?.Dispose();
        _inspectionCancellation = null;
        _thumbnailCancellation?.Cancel();
        _thumbnailCancellation?.Dispose();
        _thumbnailCancellation = new CancellationTokenSource();
        _proxyCancellation?.Cancel();
        _proxyCancellation?.Dispose();
        _proxyCancellation = null;
        _mediaReady = false;
        _metadata = null;
        _keyframeIndex = null;
        _frameTimestampIndex = null;
        CancelPreview();
        StopShuttle(pause: true);
        _mediaPlayer.Source = null;
        _mediaSource?.Dispose();
        _mediaSource = null;
        _duration = TimeSpan.Zero;
        _frameStep = FallbackFrameStep;
        _sourceFilePath = null;
        _proxyPath = null;
        _usesProxy = false;
        _proxyInProgress = false;
        _directPlaybackFailed = false;
        _frameTimingScanning = false;
        _editList = new EditList();
        _selectedSegmentId = null;
        _undoStack.Clear();
        _redoStack.Clear();
        _thumbnailImages.Clear();
        _clipItems.Clear();
        _hasUserInPoint = false;
        _hasUserOutPoint = false;
        _trimmingSegmentId = null;
        EmptyPlayerPanel.Visibility = Visibility.Visible;
        SetMediaControlsEnabled(false);
        CurrentTimeText.Text = FormatTime(TimeSpan.Zero);
        DurationText.Text = FormatTime(TimeSpan.Zero);
        InTimeText.Text = "—";
        OutTimeText.Text = "—";
        RangeDurationText.Text = Text("RangeNotReadyText");
        MediaDetailsText.Text = string.Empty;
        AudioStreamPicker.Items.Clear();
        AudioStreamPanel.Visibility = Visibility.Collapsed;
        KeyframeStatusText.Text = string.Empty;
        ExportProgressPanel.Visibility = Visibility.Collapsed;
        ProxyProgressPanel.Visibility = Visibility.Collapsed;
        _lastExport = null;
        UpdateSequenceSummary();
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
        _reverseShuttleTimer.Stop();
        _inspectionCancellation?.Cancel();
        _thumbnailCancellation?.Cancel();
        _exportCancellation?.Cancel();
        _proxyCancellation?.Cancel();
        _thumbnailService?.Dispose();
        _mediaPlayer.Dispose();
        _mediaSource?.Dispose();
    }

    private static string FormatByteSize(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        var value = Math.Max(0, (double)bytes);
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }

        return $"{value:0.#} {units[unit]}";
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

public sealed class ClipCardItem : INotifyPropertyChanged
{
    private ImageSource? _thumbnail;

    public ClipCardItem(Guid id, string name, string rangeText, string durationText, ImageSource? thumbnail)
    {
        Id = id;
        Name = name;
        RangeText = rangeText;
        DurationText = durationText;
        _thumbnail = thumbnail;
    }

    public Guid Id { get; }
    public string Name { get; set; }
    public string RangeText { get; }
    public string DurationText { get; }

    public ImageSource? Thumbnail
    {
        get => _thumbnail;
        set
        {
            if (ReferenceEquals(_thumbnail, value))
            {
                return;
            }

            _thumbnail = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Thumbnail)));
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
