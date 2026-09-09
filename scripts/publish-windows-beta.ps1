[CmdletBinding()]
param(
    [string]$Dotnet = 'dotnet',
    [string]$Version = '0.4.0-beta.1'
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+-beta\.\d+$') { throw 'Expected a beta version.' }
$root = Split-Path $PSScriptRoot -Parent
$name = "Trimlet-$Version-win-x64"
$output = Join-Path $root "dist/$name"
$archive = "$output.zip"
if (Test-Path $output) { throw "Output already exists: $output. Use a fresh output directory." }
$parts = $Version.Split('-', 2)
$project = Join-Path $root 'apps/windows/src/Trimlet.Windows/Trimlet.Windows.csproj'
& $Dotnet publish $project -c Release -r win-x64 --self-contained true -p:WindowsAppSDKSelfContained=true -p:PublishTrimmed=false "-p:VersionPrefix=$($parts[0])" "-p:VersionSuffix=$($parts[1])" -o $output
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
foreach ($required in @('Trimlet.Windows.exe', 'coreclr.dll', 'hostfxr.dll', 'Microsoft.UI.Xaml.dll', 'Trimlet.Windows.pri')) {
    if (-not (Test-Path (Join-Path $output $required))) { throw "Missing runtime asset: $required" }
}
if (Get-ChildItem $output -Recurse -File | Where-Object Name -Match '^(ffmpeg|ffprobe)\.exe$') { throw 'External FFmpeg must not be bundled.' }
Copy-Item (Join-Path $root 'LICENSE') $output
Copy-Item (Join-Path $root 'THIRD_PARTY_NOTICES.md') $output
Copy-Item (Join-Path $root 'apps/windows/BETA_DOWNLOAD.md') (Join-Path $output 'README.md')
$licenseDir = New-Item -ItemType Directory (Join-Path $output 'licenses')
$assets = Get-Content (Join-Path (Split-Path $project) 'obj/project.assets.json') -Raw | ConvertFrom-Json
$packages = @($assets.packageFolders.PSObject.Properties.Name)
$inventory = foreach ($library in $assets.libraries.PSObject.Properties) {
    if ($library.Value.type -ne 'package') { continue }
    $packagePath = $null
    foreach ($cache in $packages) {
        $candidate = Join-Path $cache $library.Value.path
        if (Test-Path $candidate) { $packagePath = $candidate; break }
    }
    if (-not $packagePath) { throw "Missing package: $($library.Name)" }
    $identity = $library.Name.Split('/')
    $destination = New-Item -ItemType Directory (Join-Path $licenseDir.FullName ($identity -join '-'))
    Get-ChildItem $packagePath -File | Where-Object { $_.Name -match 'license|notice|copying|\.nuspec$' } | Copy-Item -Destination $destination
    [ordered]@{ id=$identity[0]; version=$identity[1]; nugetSha512=$library.Value.sha512; source="https://www.nuget.org/packages/$($identity[0])/$($identity[1])" }
}
$deps = Get-Content (Join-Path $output 'Trimlet.Windows.deps.json') -Raw | ConvertFrom-Json
foreach ($runtime in $deps.libraries.PSObject.Properties | Where-Object Name -Like 'runtimepack.*') {
    $identity = $runtime.Name.Substring('runtimepack.'.Length).Split('/')
    if ($inventory | Where-Object { $_.id -eq $identity[0] -and $_.version -eq $identity[1] }) { continue }
    $packagePath = $null
    foreach ($cache in $packages) {
        $candidate = Join-Path $cache (($identity -join '/').ToLowerInvariant())
        if (Test-Path $candidate) { $packagePath = $candidate; break }
    }
    if (-not $packagePath) { throw "Missing runtime package: $($runtime.Name)" }
    $destination = New-Item -ItemType Directory (Join-Path $licenseDir.FullName ($identity -join '-'))
    Get-ChildItem $packagePath -File | Where-Object { $_.Name -match 'license|notice|copying|\.nuspec$' } | Copy-Item -Destination $destination
    $shaFile = Get-ChildItem $packagePath -Filter '*.nupkg.sha512' | Select-Object -First 1
    $inventory += [ordered]@{ id=$identity[0]; version=$identity[1]; nugetSha512=(Get-Content $shaFile.FullName -Raw).Trim(); source="https://www.nuget.org/packages/$($identity[0])/$($identity[1])" }
}
$inventory | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'dependency-inventory.json') -Encoding utf8
# Inventory covers resolved build and runtime packages, including the bundled .NET runtime.
Get-ChildItem $output -File -Recurse | ForEach-Object {
    [ordered]@{ path=[IO.Path]::GetRelativePath($output, $_.FullName); sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
} | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $output 'file-manifest.json') -Encoding utf8
Compress-Archive -LiteralPath $output -DestinationPath $archive
$hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $name.zip" | Set-Content (Join-Path $root 'dist/SHA256SUMS.txt') -Encoding ascii
Write-Output $archive
