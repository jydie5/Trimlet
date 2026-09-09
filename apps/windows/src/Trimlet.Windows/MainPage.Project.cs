using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Trimlet.Media;
using Trimlet.Platform.Windows;
using Windows.Storage;
using Windows.Storage.Pickers;

namespace Trimlet_Windows;

public sealed partial class MainPage
{
    private string? _projectPath;
    private TrimletProject? _loadedProject;
    private EditList _savedEdits = new();
    private ExportMode _savedMode;
    private int _savedAudio = -1;
    private bool _sourceChanged;
    private bool _projectBusy;
    private bool _confirmingClose;

    private bool ProjectDirty => _sourceChanged || !_editList.Equals(_savedEdits)
        || (_mediaReady && (CurrentExportMode() != _savedMode || SelectedAudioIndex() != _savedAudio));

    private void AcceptProjectState()
    {
        _savedEdits = _editList;
        _savedMode = CurrentExportMode();
        _savedAudio = SelectedAudioIndex();
        _sourceChanged = false;
        UpdateProjectDisplay();
    }

    private void UpdateProjectDisplay()
    {
        if (ProjectTitleText is null) return;
        EditingWorkspace.IsEnabled = SequencePanel.IsEnabled = ExportPanel.IsEnabled = !_projectBusy;
        ProjectTitleText.Text = (_projectPath is null ? Text("ProjectUntitled") : Path.GetFileName(_projectPath))
            + (ProjectDirty ? " •" : "");
        SaveProjectButton.IsEnabled = SaveAsProjectItem.IsEnabled = _mediaReady && _metadata is not null
            && !_isExporting && !_projectBusy && !_proxyInProgress;
        OpenButton.IsEnabled = OpenProjectItem.IsEnabled = !_isExporting && !_projectBusy && !_proxyInProgress;
    }

    private async Task<ContentDialogResult> ProjectDialog(string title, string message, string primary, string? secondary = null)
    {
        StopShuttle(pause: true);
        return await new ContentDialog
        {
            XamlRoot = XamlRoot, Title = title, Content = message,
            PrimaryButtonText = Text(primary), SecondaryButtonText = secondary is null ? "" : Text(secondary),
            CloseButtonText = Text("ProjectCancel"), DefaultButton = ContentDialogButton.Close,
        }.ShowAsync();
    }

    public async Task<bool> ConfirmCloseAsync()
    {
        if (_confirmingClose || _projectBusy || _isExporting || _proxyInProgress) return false;
        _confirmingClose = true;
        try
        {
            if (!ProjectDirty) return true;
            var answer = await ProjectDialog(Text("ProjectUnsavedTitle"), Text("ProjectUnsavedMessage"), "ProjectSave", "ProjectDiscard");
            return answer == ContentDialogResult.Secondary
                || (answer == ContentDialogResult.Primary && await SaveProjectAsync(false));
        }
        finally { _confirmingClose = false; }
    }

    private async void OnOpenProjectClicked(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(".trimlet");
        InitializePicker(picker);
        var file = await picker.PickSingleFileAsync();
        if (file is not null) await OpenProjectAsync(file.Path);
    }

    private async void OnSaveProjectClicked(object sender, RoutedEventArgs e) => await SaveProjectAsync(false);
    private async void OnSaveAsProjectClicked(object sender, RoutedEventArgs e) => await SaveProjectAsync(true);
    private async void OnSaveProjectAccelerator(KeyboardAccelerator sender, KeyboardAcceleratorInvokedEventArgs args)
    {
        args.Handled = true;
        await SaveProjectAsync(false);
    }

    private TrimletProject CaptureProject(string path)
    {
        var segments = _editList.Segments.Select((s, i) =>
        {
            var original = _loadedProject?.EditList.Segments.FirstOrDefault(p => p.Id == s.Id);
            var originalDisplay = string.IsNullOrWhiteSpace(original?.Name)
                ? $"Clip {Array.FindIndex(_loadedProject?.EditList.Segments ?? [], p => p.Id == s.Id) + 1}" : original.Name;
            return new ProjectSegment(s.Id, ProjectTime.From(s.Range.In), ProjectTime.From(s.Range.Out),
                original is not null && s.Name == originalDisplay ? original.Name : s.Name);
        }).ToArray();
        var audio = _metadata?.AudioStreams.FirstOrDefault(a => a.AudioIndex == SelectedAudioIndex());
        var selected = audio is null ? null : new ProjectAudio(audio.StreamIndex, audio.Codec, audio.Language);
        if (_loadedProject?.Settings.Audio?.StreamIndex == selected?.StreamIndex)
            selected = _loadedProject?.Settings.Audio;
        return new(1, ProjectStore.Capture(_sourceFilePath!, path), new(segments),
            new(CurrentExportMode() == ExportMode.Fast ? "fast" : "accurate", selected));
    }

    private async Task<bool> SaveProjectAsync(bool saveAs)
    {
        if (!_mediaReady || _metadata is null || _isExporting || _projectBusy || _proxyInProgress) return false;
        _projectBusy = true;
        UpdateProjectDisplay();
        try
        {
            var path = _projectPath;
            if (saveAs || path is null)
            {
                var picker = new FileSavePicker { SuggestedFileName = Path.GetFileNameWithoutExtension(path ?? _sourceFilePath) };
                picker.FileTypeChoices.Add("Trimlet", new List<string> { ".trimlet" });
                InitializePicker(picker);
                var file = await picker.PickSaveFileAsync();
                if (file is null) return false;
                path = file.Path;
            }
            var project = CaptureProject(path);
            var savedEdits = _editList;
            var savedMode = CurrentExportMode();
            var savedAudio = SelectedAudioIndex();
            await ProjectStore.SaveAsync(path, project);
            _projectPath = path;
            _loadedProject = project;
            _savedEdits = savedEdits;
            _savedMode = savedMode;
            _savedAudio = savedAudio;
            _sourceChanged = false;
            return true;
        }
        catch (Exception)
        {
            ShowStatus(InfoBarSeverity.Error, Text("ProjectErrorTitle"), Text("ProjectSaveError"));
            return false;
        }
        finally { _projectBusy = false; UpdateProjectDisplay(); }
    }

    private async Task OpenProjectAsync(string path)
    {
        if (!await ConfirmCloseAsync()) return;
        _projectBusy = true;
        UpdateProjectDisplay();
        try
        {
            var project = await ProjectStore.ReadAsync(path);
            var sourcePath = ProjectStore.Resolve(project.Source, path);
            var relink = !File.Exists(sourcePath);
            var changed = relink;
            if (!relink && !ProjectStore.Matches(project.Source, sourcePath))
            {
                var answer = await ProjectDialog(Text("ProjectSourceTitle"), Text("ProjectSourceChanged"), "ProjectUseSource", "ProjectRelink");
                if (answer == ContentDialogResult.None) return;
                relink = answer == ContentDialogResult.Secondary;
                changed = true;
            }
            if (relink)
            {
                if (await ProjectDialog(Text("ProjectSourceTitle"), project.Source.FileName, "ProjectRelink") != ContentDialogResult.Primary) return;
                var picker = new FileOpenPicker();
                foreach (var extension in SupportedMedia.FileExtensions) picker.FileTypeFilter.Add(extension);
                InitializePicker(picker);
                var replacement = await picker.PickSingleFileAsync();
                if (replacement is null) return;
                sourcePath = replacement.Path;
                if (!ProjectStore.Matches(project.Source, sourcePath)
                    && await ProjectDialog(Text("ProjectSourceTitle"), Text("ProjectSourceChanged"), "ProjectUseSource") != ContentDialogResult.Primary) return;
            }
            // Probe and validate before replacing the user's current edit list.
            if (_inspector is null) throw new InvalidDataException();
            var metadata = await _inspector.InspectAsync(sourcePath, CancellationToken.None);
            project.Validate(metadata.Duration);
            await LoadMediaAsync(await StorageFile.GetFileFromPathAsync(sourcePath));
            for (var attempt = 0; !_mediaReady && attempt < 300; attempt++) await Task.Delay(100);
            if (!_mediaReady || _metadata is null) throw new InvalidDataException();
            project.Validate(_metadata.Duration);
            _editList = project.ToEditList();
            _loadedProject = project;
            _projectPath = path;
            AccurateModeButton.IsChecked = project.Settings.ExportMode == "accurate";
            FastModeButton.IsChecked = project.Settings.ExportMode == "fast";
            if (project.Settings.Audio is { } audio)
            {
                var match = _metadata.AudioStreams.ToList().FindIndex(a => a.StreamIndex == audio.StreamIndex);
                if (match >= 0) AudioStreamPicker.SelectedIndex = match;
                else
                {
                    changed = true;
                    ShowStatus(InfoBarSeverity.Warning, Text("ProjectSourceTitle"), Text("ProjectAudioFallback"));
                }
            }
            AcceptProjectState();
            _sourceChanged = changed;
            RebuildClipItems();
            UpdateRangeDisplay();
        }
        catch (Exception)
        {
            ShowStatus(InfoBarSeverity.Error, Text("ProjectErrorTitle"), Text("ProjectOpenError"));
        }
        finally { _projectBusy = false; UpdateProjectDisplay(); }
    }
}
