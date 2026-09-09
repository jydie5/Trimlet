$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Errors = Get-Content (Join-Path $ProjectDir "contracts/error-codes.json") -Raw | ConvertFrom-Json
$Schema = Get-Content (Join-Path $ProjectDir "contracts/export-plan.schema.json") -Raw | ConvertFrom-Json
$Fixtures = Get-Content (Join-Path $ProjectDir "contracts/fixtures/export-plan-cases.json") -Raw | ConvertFrom-Json
$EditSchema = Get-Content (Join-Path $ProjectDir "contracts/edit-list.schema.json") -Raw | ConvertFrom-Json
$EditFixtures = Get-Content (Join-Path $ProjectDir "contracts/fixtures/edit-list-cases.json") -Raw | ConvertFrom-Json
$ProjectSchema = Get-Content (Join-Path $ProjectDir "contracts/project.schema.json") -Raw | ConvertFrom-Json
$ProjectFixtures = Get-Content (Join-Path $ProjectDir "contracts/fixtures/project-cases.json") -Raw | ConvertFrom-Json

function Test-OnlyProperties {
    param(
        [object]$Value,
        [string[]]$Allowed
    )

    if ($null -eq $Value) { return $false }
    foreach ($PropertyName in $Value.PSObject.Properties.Name) {
        if ($PropertyName -notin $Allowed) { return $false }
    }
    return $true
}

if ($Errors.schemaVersion -ne 1 -or $Fixtures.schemaVersion -ne 1 -or $EditFixtures.schemaVersion -ne 1 -or $EditSchema.properties.schemaVersion.const -ne 1 -or $ProjectFixtures.schemaVersion -ne 1 -or $ProjectSchema.properties.schemaVersion.const -ne 1) {
    throw "Unsupported shared contract schema version"
}

$ProjectCaseIds = @{}
foreach ($Case in $ProjectFixtures.cases) {
    if ($ProjectCaseIds.ContainsKey($Case.id)) { throw "Duplicate project fixture id: $($Case.id)" }
    $ProjectCaseIds[$Case.id] = $true
    $Document = $Case.input
    $PathHint = [string]$Document.source.pathHint
    $HasDrivePrefix = $PathHint.Length -ge 2 -and $PathHint[1] -eq ':'
    $SizeBytes = $Document.source.sizeBytes
    $Audio = $Document.settings.audio
    $Valid = (
        $Document.schemaVersion -eq 1 -and
        (Test-OnlyProperties $Document @("schemaVersion", "source", "editList", "settings")) -and
        (Test-OnlyProperties $Document.source @("fileName", "pathHint", "sizeBytes", "modifiedAt")) -and
        (Test-OnlyProperties $Document.editList @("segments")) -and
        (Test-OnlyProperties $Document.settings @("exportMode", "audio")) -and
        -not [string]::IsNullOrWhiteSpace($Document.source.fileName) -and
        -not [string]::IsNullOrWhiteSpace($PathHint) -and
        -not $PathHint.StartsWith('/') -and
        -not $HasDrivePrefix -and
        -not $PathHint.Contains('\') -and
        $Document.settings.exportMode -in @("fast", "accurate") -and
        ($null -eq $SizeBytes -or ($SizeBytes -ge 0 -and $SizeBytes -le [long]::MaxValue)) -and
        (
            $null -eq $Audio -or
            (
                (Test-OnlyProperties $Audio @("streamIndex", "codecName", "language", "title")) -and
                $Audio.streamIndex -ge 0 -and
                $Audio.streamIndex -le [int]::MaxValue
            )
        )
    )
    $SegmentIds = @{}
    $Ranges = @()
    foreach ($Segment in $Document.editList.segments) {
        if (-not (Test-OnlyProperties $Segment @("id", "in", "out", "name"))) { $Valid = $false }
        if (-not (Test-OnlyProperties $Segment.in @("value", "timescale"))) { $Valid = $false }
        if (-not (Test-OnlyProperties $Segment.out @("value", "timescale"))) { $Valid = $false }
        if ($SegmentIds.ContainsKey($Segment.id)) { $Valid = $false }
        $SegmentIds[$Segment.id] = $true
        $ParsedGuid = [guid]::Empty
        if (-not [guid]::TryParse([string]$Segment.id, [ref]$ParsedGuid)) { $Valid = $false }
        if (
            $Segment.in.value -lt 0 -or
            $Segment.out.value -lt 0 -or
            $Segment.in.value -gt [long]::MaxValue -or
            $Segment.out.value -gt [long]::MaxValue -or
            $Segment.in.timescale -le 0 -or
            $Segment.out.timescale -le 0 -or
            $Segment.in.timescale -gt [int]::MaxValue -or
            $Segment.out.timescale -gt [int]::MaxValue
        ) {
            $Valid = $false
            continue
        }
        $Left = [decimal]$Segment.in.value * [decimal]$Segment.out.timescale
        $Right = [decimal]$Segment.out.value * [decimal]$Segment.in.timescale
        if ($Left -ge $Right) { $Valid = $false }
        $Ranges += [pscustomobject]@{
            StartValue = [decimal]$Segment.in.value
            StartTimescale = [decimal]$Segment.in.timescale
            EndValue = [decimal]$Segment.out.value
            EndTimescale = [decimal]$Segment.out.timescale
        }
    }
    for ($I = 0; $I -lt $Ranges.Count; $I++) {
        for ($J = $I + 1; $J -lt $Ranges.Count; $J++) {
            $FirstStartsBeforeSecondEnds = (
                $Ranges[$I].StartValue * $Ranges[$J].EndTimescale -lt
                $Ranges[$J].EndValue * $Ranges[$I].StartTimescale
            )
            $SecondStartsBeforeFirstEnds = (
                $Ranges[$J].StartValue * $Ranges[$I].EndTimescale -lt
                $Ranges[$I].EndValue * $Ranges[$J].StartTimescale
            )
            if ($FirstStartsBeforeSecondEnds -and $SecondStartsBeforeFirstEnds) {
                $Valid = $false
            }
        }
    }
    if ([bool]$Case.valid -ne $Valid) {
        throw "Project validity mismatch: $($Case.id)"
    }
}

$EditCaseIds = @{}
foreach ($Case in $EditFixtures.cases) {
    if ($EditCaseIds.ContainsKey($Case.id)) { throw "Duplicate edit-list fixture id: $($Case.id)" }
    $EditCaseIds[$Case.id] = $true
    $SegmentIds = @{}
    $Ranges = @()
    $ValidRanges = $true
    foreach ($Segment in $Case.input.segments) {
        if ($SegmentIds.ContainsKey($Segment.id)) { throw "Duplicate segment id: $($Segment.id)" }
        $SegmentIds[$Segment.id] = $true
        $Start = [double]$Segment.in.value / [double]$Segment.in.timescale
        $End = [double]$Segment.out.value / [double]$Segment.out.timescale
        if ($Start -ge $End) { $ValidRanges = $false }
        $Ranges += ,@($Start, $End)
    }
    $HasOverlap = $false
    for ($I = 0; $I -lt $Ranges.Count; $I++) {
        for ($J = $I + 1; $J -lt $Ranges.Count; $J++) {
            if ($Ranges[$I][0] -lt $Ranges[$J][1] -and $Ranges[$J][0] -lt $Ranges[$I][1]) {
                $HasOverlap = $true
            }
        }
    }
    if ([bool]$Case.valid -ne ($ValidRanges -and -not $HasOverlap)) {
        throw "Edit-list validity mismatch: $($Case.id)"
    }
}

$Ids = @($Errors.errors | ForEach-Object { $_.id })
if (($Ids | Select-Object -Unique).Count -ne $Ids.Count) {
    throw "Duplicate shared error identifier"
}

$CaseIds = @{}
foreach ($Case in $Fixtures.cases) {
    if ($CaseIds.ContainsKey($Case.id)) { throw "Duplicate fixture id: $($Case.id)" }
    $CaseIds[$Case.id] = $true
    $Plan = $Case.input
    if ($Plan.schemaVersion -ne 1) { throw "Unsupported plan schema in $($Case.id)" }
    if ($Plan.mode -notin @("fast", "accurate")) { throw "Invalid mode in $($Case.id)" }
    if ($Plan.output.container -ne "mp4") { throw "Invalid container in $($Case.id)" }
    if ($Plan.range.in.timescale -le 0 -or $Plan.range.out.timescale -le 0) {
        throw "Invalid timescale in $($Case.id)"
    }
    $Left = [decimal]$Plan.range.in.value * [decimal]$Plan.range.out.timescale
    $Right = [decimal]$Plan.range.out.value * [decimal]$Plan.range.in.timescale
    if ($Left -ge $Right) { throw "Invalid range in $($Case.id)" }
}

Write-Host "Shared contracts: $($CaseIds.Count) export cases, $($EditCaseIds.Count) edit-list cases, $($ProjectCaseIds.Count) project cases, and $($Ids.Count) error codes passed"
