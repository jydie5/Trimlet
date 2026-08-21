[CmdletBinding()]
param(
    [string]$MediaPath
)

$ErrorActionPreference = 'Stop'
$windowsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Resolve-Path (Join-Path $windowsRoot '..\..')
$localSdk = Join-Path $env:USERPROFILE '.dotnet-sdk-10\dotnet.exe'

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $dotnet -or -not ((& $dotnet --list-sdks) -match '^10\.0\.400')) {
    if (-not (Test-Path -LiteralPath $localSdk)) {
        throw '.NET SDK 10.0.400 is required. Install it, then run this script again.'
    }

    $dotnet = $localSdk
}

Push-Location $repositoryRoot
try {
    & '.\scripts\validate-contracts.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'Shared contract validation failed.' }

    & $dotnet restore '.\apps\windows\Trimlet.sln' --configfile '.\apps\windows\NuGet.Config'
    if ($LASTEXITCODE -ne 0) { throw 'Windows solution restore failed.' }

    & $dotnet restore '.\apps\windows\src\Trimlet.Windows\Trimlet.Windows.csproj' --runtime win-x64 --configfile '.\apps\windows\NuGet.Config'
    if ($LASTEXITCODE -ne 0) { throw 'Windows app restore failed.' }

    & $dotnet restore '.\apps\windows\checks\Trimlet.IntegrationChecks\Trimlet.IntegrationChecks.csproj' --configfile '.\apps\windows\NuGet.Config'
    if ($LASTEXITCODE -ne 0) { throw 'Windows integration-check restore failed.' }

    & $dotnet test '.\apps\windows\Trimlet.sln' --configuration Debug --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Windows tests failed.' }

    & $dotnet run --project '.\apps\windows\checks\Trimlet.IntegrationChecks\Trimlet.IntegrationChecks.csproj' --configuration Debug --no-restore -- --require-tools
    if ($LASTEXITCODE -ne 0) { throw 'Windows FFmpeg integration checks failed.' }

    $appArguments = @()
    if ($MediaPath) {
        $resolvedMediaPath = (Resolve-Path -LiteralPath $MediaPath).Path
        $appArguments = @('--', $resolvedMediaPath)
    }

    & $dotnet run --project '.\apps\windows\src\Trimlet.Windows\Trimlet.Windows.csproj' --configuration Debug --runtime win-x64 --no-restore @appArguments
    if ($LASTEXITCODE -ne 0) { throw 'Trimlet did not exit cleanly.' }
}
finally {
    Pop-Location
}
