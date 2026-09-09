using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Trimlet.Media;

namespace Trimlet_Windows;

public sealed partial class MainPage
{
    private double _viewportStart, _viewportSpan;
    private uint? _timelinePointer;
    private TimelineTarget _dragTarget;
    private double _dragX, _dragBoundary;
    private TimeSpan _dragIn, _dragOut;
    private TimelineGeometry _dragGeometry;
    private readonly List<FrameworkElement> _rulerLabels = [];
    private TimelineGeometry Geometry => new(RangeTrackCanvas.ActualWidth, _duration.TotalSeconds, _viewportStart, _viewportSpan);

    private bool CanReplaceTrimDraft()
    {
        if (_trimmingSegmentId is null) return true;
        ShowStatus(InfoBarSeverity.Informational, Text("TrimModeHeadingText"), Text("TrimDraftTitle"));
        return false;
    }

    private void DrawRuler()
    {
        for (var i = 0; i <= 4; i++)
        {
            var time = _viewportStart + Geometry.VisibleSpan * i / 4;
            var label = new TextBlock
            {
                Text = FormatTime(TimeSpan.FromSeconds(time)), FontSize = 10,
                Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(255, 174, 186, 203)),
                IsHitTestVisible = false,
            };
            Canvas.SetLeft(label, Math.Clamp(Geometry.X(time) - 28, 24, Math.Max(24, RangeTrackCanvas.ActualWidth - 92)));
            Canvas.SetTop(label, 20);
            _rulerLabels.Add(label);
            RangeTrackCanvas.Children.Add(label);
        }
    }

    private void OnSourcePointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (!_mediaReady || _isExporting || _timelinePointer is not null) return;
        var point = e.GetCurrentPoint(RangeTrackCanvas);
        if (!point.Properties.IsLeftButtonPressed) return;
        _dragGeometry = Geometry;
        _dragTarget = Geometry.Hit(point.Position.X, point.Position.Y,
            _hasUserInPoint ? _inPoint.TotalSeconds : null, _hasUserOutPoint ? _outPoint.TotalSeconds : null);
        if (!RangeTrackCanvas.CapturePointer(e.Pointer)) return;
        _timelinePointer = point.PointerId;
        _dragX = point.Position.X;
        _dragIn = _inPoint;
        _dragOut = _outPoint;
        _dragBoundary = _dragTarget == TimelineTarget.In ? _inPoint.TotalSeconds : _outPoint.TotalSeconds;
        _isScrubbing = true;
        StopShuttle(pause: true);
        CancelPreview();
        UpdateSourceGesture(point.Position.X);
        e.Handled = true;
    }

    private void OnSourcePointerMoved(object sender, PointerRoutedEventArgs e)
    {
        var point = e.GetCurrentPoint(RangeTrackCanvas);
        if (_timelinePointer == point.PointerId) UpdateSourceGesture(point.Position.X);
        else if (_timelinePointer is null && _mediaReady)
        {
            var target = Geometry.Hit(point.Position.X, point.Position.Y,
                _hasUserInPoint ? _inPoint.TotalSeconds : null, _hasUserOutPoint ? _outPoint.TotalSeconds : null);
            var time = target == TimelineTarget.In ? _inPoint.TotalSeconds
                : target == TimelineTarget.Out ? _outPoint.TotalSeconds : Geometry.Time(point.Position.X);
            ShowTimelineFeedback(target, time);
        }
    }

    private double SnapBoundary(double seconds)
    {
        if (_frameTimestampIndex is { Timestamps.Count: > 0 } index)
        {
            var time = MediaTimestamp.FromSeconds(seconds);
            var before = index.Step(time, -1);
            var after = index.Step(before, 1);
            return Math.Abs(seconds - before.TotalSeconds) < Math.Abs(after.TotalSeconds - seconds)
                ? before.TotalSeconds : after.TotalSeconds;
        }
        return Math.Clamp(Math.Round(seconds / _frameStep.TotalSeconds) * _frameStep.TotalSeconds, 0, _duration.TotalSeconds);
    }

    private void UpdateSourceGesture(double x)
    {
        double seconds;
        if (_dragTarget == TimelineTarget.Seek) seconds = _dragGeometry.Time(x);
        else
        {
            seconds = _dragGeometry.Translate(_dragBoundary, x - _dragX);
            // A padded click is a preview, never a quantization operation.
            if (Math.Abs(x - _dragX) > 0.01)
            {
                seconds = SnapBoundary(seconds);
                if (_dragTarget == TimelineTarget.In)
                {
                    var maximum = _hasUserOutPoint
                        ? (_frameTimestampIndex?.Step(MediaTimestamp.FromTimeSpan(_outPoint), -1).TotalSeconds
                            ?? Math.Max(0, _outPoint.TotalSeconds - _frameStep.TotalSeconds)) : _duration.TotalSeconds;
                    seconds = Math.Clamp(seconds, 0, maximum);
                    _inPoint = TimeSpan.FromSeconds(seconds);
                }
                else
                {
                    var minimum = _frameTimestampIndex?.Step(MediaTimestamp.FromTimeSpan(_inPoint), 1).TotalSeconds
                        ?? Math.Min(_duration.TotalSeconds, _inPoint.TotalSeconds + _frameStep.TotalSeconds);
                    seconds = Math.Clamp(seconds, minimum, _duration.TotalSeconds);
                    _outPoint = TimeSpan.FromSeconds(seconds);
                }
                UpdateRangeDisplay();
            }
        }
        SeekTo(TimeSpan.FromSeconds(seconds));
        CurrentTimeText.Text = FormatTime(TimeSpan.FromSeconds(seconds));
        UpdatePlayhead(TimeSpan.FromSeconds(seconds));
        ShowTimelineFeedback(_dragTarget, seconds);
    }

    private void OnSourcePointerReleased(object sender, PointerRoutedEventArgs e)
    {
        if (_timelinePointer != e.Pointer.PointerId) return;
        UpdateSourceGesture(e.GetCurrentPoint(RangeTrackCanvas).Position.X);
        _timelinePointer = null;
        _isScrubbing = false;
        RangeTrackCanvas.ReleasePointerCapture(e.Pointer);
        e.Handled = true;
    }

    private void OnSourcePointerCanceled(object sender, PointerRoutedEventArgs e)
    {
        if (_timelinePointer != e.Pointer.PointerId) return;
        _timelinePointer = null;
        _isScrubbing = false;
        _inPoint = _dragIn;
        _outPoint = _dragOut;
        RangeTrackCanvas.ReleasePointerCaptures();
        UpdateRangeDisplay();
    }

    private void OnSourceWheelChanged(object sender, PointerRoutedEventArgs e)
    {
        if (!_mediaReady || _isExporting || _timelinePointer is not null) return;
        var delta = e.GetCurrentPoint(RangeTrackCanvas).Properties.MouseWheelDelta;
        SeekTo(ClampToSource(_mediaPlayer.PlaybackSession.Position + TimeSpan.FromSeconds(delta / 120.0)));
        e.Handled = true;
    }

    private void ShowTimelineFeedback(TimelineTarget target, double seconds) => TimelineFeedbackText.Text =
        Text(target == TimelineTarget.In ? "TimelineAdjustIn" : target == TimelineTarget.Out ? "TimelineAdjustOut" : "TimelineSeek")
        + "  " + FormatTime(TimeSpan.FromSeconds(seconds));

    private void Zoom(double factor)
    {
        if (!_mediaReady || _timelinePointer is not null) return;
        _viewportSpan = Math.Clamp(Geometry.VisibleSpan * factor, Math.Min(_duration.TotalSeconds, _frameStep.TotalSeconds * 4), _duration.TotalSeconds);
        _viewportStart = Math.Clamp(_mediaPlayer.PlaybackSession.Position.TotalSeconds - _viewportSpan / 2, 0, _duration.TotalSeconds - _viewportSpan);
        UpdateRangeTrack();
    }
    private void OnZoomInClicked(object sender, RoutedEventArgs e) => Zoom(0.5);
    private void OnZoomOutClicked(object sender, RoutedEventArgs e) => Zoom(2);
    private void OnFitTimelineClicked(object sender, RoutedEventArgs e)
    {
        if (_timelinePointer is not null) return;
        _viewportStart = _viewportSpan = 0;
        UpdateRangeTrack();
    }
    private void OnFitRangeClicked(object sender, RoutedEventArgs e)
    {
        if (!_mediaReady || _timelinePointer is not null) return;
        TrimRange? candidate = HasValidDraft() ? CurrentRange()
            : _selectedSegmentId is { } id ? _editList.Segment(id)?.Range : null;
        if (candidate is not { } range) return;
        _viewportSpan = Math.Min(_duration.TotalSeconds, Math.Max(_frameStep.TotalSeconds * 4, range.DurationSeconds * 1.5));
        _viewportStart = Math.Clamp((range.In.TotalSeconds + range.Out.TotalSeconds - _viewportSpan) / 2, 0, _duration.TotalSeconds - _viewportSpan);
        UpdateRangeTrack();
    }
    private void Pan(double direction)
    {
        if (!_mediaReady || _timelinePointer is not null) return;
        _viewportStart = Math.Clamp(_viewportStart + Geometry.VisibleSpan * direction / 2, 0, _duration.TotalSeconds - Geometry.VisibleSpan);
        UpdateRangeTrack();
    }
    private void OnPanLeftClicked(object sender, RoutedEventArgs e) => Pan(-1);
    private void OnPanRightClicked(object sender, RoutedEventArgs e) => Pan(1);

    private void UpdateSequenceClock(TimeSpan position)
    {
        if (_sequencePreviewIndex < 0) { PlaybackClockText.Text = Text("SourceClock"); return; }
        var elapsed = _editList.Segments.Take(_sequencePreviewIndex).Sum(s => s.DurationSeconds)
            + Math.Max(0, position.TotalSeconds - _editList.Segments[_sequencePreviewIndex].Range.In.TotalSeconds);
        PlaybackClockText.Text = Text("SequenceClock") + " " + FormatTime(TimeSpan.FromSeconds(elapsed))
            + " / " + FormatTime(TimeSpan.FromSeconds(_editList.TotalDurationSeconds));
    }
}
