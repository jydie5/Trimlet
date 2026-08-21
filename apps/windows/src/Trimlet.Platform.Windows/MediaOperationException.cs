namespace Trimlet.Platform.Windows;

public sealed class MediaOperationException : Exception
{
    public MediaOperationException(string errorCode, string message, string? diagnostics = null, Exception? innerException = null)
        : base(message, innerException)
    {
        ErrorCode = errorCode;
        Diagnostics = diagnostics;
    }

    public string ErrorCode { get; }
    public string? Diagnostics { get; }
}
