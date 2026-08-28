$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Errors = Get-Content (Join-Path $ProjectDir "contracts/error-codes.json") -Raw | ConvertFrom-Json
$Schema = Get-Content (Join-Path $ProjectDir "contracts/export-plan.schema.json") -Raw | ConvertFrom-Json
$Fixtures = Get-Content (Join-Path $ProjectDir "contracts/fixtures/export-plan-cases.json") -Raw | ConvertFrom-Json
$EditSchema = Get-Content (Join-Path $ProjectDir "contracts/edit-list.schema.json") -Raw | ConvertFrom-Json
$EditFixtures = Get-Content (Join-Path $ProjectDir "contracts/fixtures/edit-list-cases.json") -Raw | ConvertFrom-Json

if ($Errors.schemaVersion -ne 1 -or $Fixtures.schemaVersion -ne 1 -or $EditFixtures.schemaVersion -ne 1 -or $EditSchema.properties.schemaVersion.const -ne 1) {
    throw "Unsupported shared contract schema version"
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

Write-Host "Shared contracts: $($CaseIds.Count) export cases, $($EditCaseIds.Count) edit-list cases, and $($Ids.Count) error codes passed"
