namespace Trimlet.Media;

public enum TimelineTarget { Seek, In, Out }

/// <summary>Pure logical-pixel mapping; gutters do not alter source coordinates.</summary>
public readonly record struct TimelineGeometry(double Width, double Duration, double Start = 0, double Span = 0)
{
    private double SafeDuration => double.IsFinite(Duration) ? Math.Max(0, Duration) : 0;
    public double VisibleSpan => Span > 0 && double.IsFinite(Span) ? Math.Min(Span, SafeDuration) : SafeDuration;
    private double SafeStart => double.IsFinite(Start) ? Math.Clamp(Start, 0, SafeDuration - VisibleSpan) : 0;
    public double ContentWidth => double.IsFinite(Width) ? Math.Max(1, Width - 48) : 1;
    public double X(double seconds) => VisibleSpan > 0 && double.IsFinite(seconds)
        ? 24 + (seconds - SafeStart) / VisibleSpan * ContentWidth : 24;
    public double Time(double x) => double.IsFinite(x)
        ? Math.Clamp(SafeStart + (x - 24) / ContentWidth * VisibleSpan, 0, SafeDuration) : SafeStart;
    public bool Visible(double seconds) => double.IsFinite(seconds) && seconds >= SafeStart && seconds <= SafeStart + VisibleSpan;
    public TimelineTarget Hit(double x, double y, double? inPoint, double? outPoint)
    {
        if (SafeDuration <= 0 || !double.IsFinite(Width) || Width <= 48 || !double.IsFinite(x) || !double.IsFinite(y) || y < 40 || y >= 72) return TimelineTarget.Seek;
        if (inPoint is { } i && Visible(i) && x >= X(i) - 24 && x < X(i)) return TimelineTarget.In;
        if (outPoint is { } o && Visible(o) && x >= X(o) && x < X(o) + 24) return TimelineTarget.Out;
        return TimelineTarget.Seek;
    }
    public double Translate(double initialBoundary, double delta) =>
        double.IsFinite(initialBoundary)
            ? Math.Clamp(initialBoundary + (double.IsFinite(delta) ? delta / ContentWidth * VisibleSpan : 0), 0, SafeDuration) : 0;
}
