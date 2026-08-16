$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
$Errors = Get-Content (Join-Path $ProjectDir "contracts/error-codes.json") -Raw | ConvertFrom-Json
$Schema = Get-Content (Join-Path $ProjectDir "contracts/export-plan.schema.json") -Raw | ConvertFrom-Json
$Fixtures = Get-Content (Join-Path $ProjectDir "contracts/fixtures/export-plan-cases.json") -Raw | ConvertFrom-Json

if ($Errors.schemaVersion -ne 1 -or $Fixtures.schemaVersion -ne 1) {
    throw "Unsupported shared contract schema version"
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

Write-Host "Shared contracts: $($CaseIds.Count) fixture cases and $($Ids.Count) error codes passed"
