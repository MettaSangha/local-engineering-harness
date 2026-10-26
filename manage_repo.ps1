
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Audit', 'Verify', 'Backup', 'RestoreTest', 'CleanPreview', 'Clean')]
    [string]$Action = 'Audit'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# 1. CONFIGURATION
# ============================================================

$Repo = 'C:\Users\metta\Desktop\local-engineering-harness'
$BackupRoot = 'C:\Users\metta\Desktop\local-engineering-harness-backups'
$Python = 'python'

$GitOptions = @(
    '-c',
    'safe.directory=C:/Users/metta/Desktop/local-engineering-harness'
)

$RequiredFiles = @(
    '.gitignore',
    'README.md',
    'pyproject.toml',
    'docs\ACCEPTANCE.md',
    'docs\DECISIONS.md',
    'src\harness.py',
    'tests\test_main.py'
)

# Only these generated artifacts may be quarantined.
# No recovery files, source files, tests, docs, or Git metadata.
$CleanAllowlist = @(
    '.pytest_cache',
    'src\__pycache__',
    'tests\__pycache__',
    'src\local_engineering_harness.egg-info'
)

$ProtectedPatterns = @(
    'repair_harness.py',
    '*.backup-*',
    '*.bak',
    '*.pre-recovery-*',
    '*.pre-repair-*',
    '*.pre-restore-*'
)

# ============================================================
# 2. COMMON HELPERS
# ============================================================

function Stop-Run {
    param([Parameter(Mandatory)][string]$Message)
    throw "STOP: $Message"
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$FullPath)

    return $FullPath.Substring($Repo.Length).TrimStart('\', '/')
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$Program,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $oldPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Program @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        Stop-Run "Unable to run '$Program': $($_.Exception.Message)"
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = [object[]]$output
    }
}

function Invoke-GitRaw {
    param([Parameter(Mandatory)][string[]]$Arguments)

    Invoke-Native -Program 'git' -Arguments (@($GitOptions) + $Arguments)
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $result = Invoke-GitRaw -Arguments $Arguments

    if ($result.ExitCode -ne 0) {
        $details = ($result.Output | ForEach-Object { "$_" }) -join "`n"
        Stop-Run "Git failed ($($result.ExitCode)): git $($Arguments -join ' ')`n$details"
    }

    @($result.Output | ForEach-Object { "$_" })
}

function Invoke-CheckedProgram {
    param(
        [Parameter(Mandatory)][string]$Program,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    Write-Host "`n> $Program $($Arguments -join ' ')" -ForegroundColor DarkGray
    $result = Invoke-Native -Program $Program -Arguments $Arguments

    foreach ($line in $result.Output) {
        Write-Host "$line"
    }

    if ($result.ExitCode -ne 0) {
        Stop-Run "'$Program' failed with exit code $($result.ExitCode)."
    }

    Write-Host 'PASS' -ForegroundColor Green
}

function Assert-BackupRoot {
    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        Stop-Run "Backup directory does not exist: $BackupRoot. Create and inspect it first."
    }
}

function Assert-Repository {
    if (-not (Test-Path -LiteralPath $Repo -PathType Container)) {
        Stop-Run "Repository not found: $Repo"
    }

    Set-Location -LiteralPath $Repo

    if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) {
        Stop-Run 'Git metadata was not found.'
    }

    $root = @(Invoke-Git -Arguments @('rev-parse', '--show-toplevel'))
    if ($root.Count -eq 0) {
        Stop-Run 'Git did not return a repository root.'
    }

    $expected = [IO.Path]::GetFullPath($Repo).TrimEnd('\', '/')
    $actual = [IO.Path]::GetFullPath($root[0].Trim()).TrimEnd('\', '/')

    if (-not [string]::Equals(
        $expected,
        $actual,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Run "Repository mismatch. Expected '$expected'; got '$actual'."
    }

    foreach ($file in $RequiredFiles) {
        $path = Join-Path $Repo $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Stop-Run "Required file is missing: $file"
        }
    }
}

function Get-ProtectedFiles {
    @(
        Get-ChildItem -LiteralPath $Repo -File -Force -Recurse |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                (
                    $_.Name -eq 'repair_harness.py' -or
                    $_.Name -like '*.backup-*' -or
                    $_.Name -like '*.bak' -or
                    $_.Name -like '*.pre-recovery-*' -or
                    $_.Name -like '*.pre-repair-*' -or
                    $_.Name -like '*.pre-restore-*'
                )
            }
    )
}

function Get-GeneratedCandidates {
    foreach ($relative in $CleanAllowlist) {
        $path = Join-Path $Repo $relative
        if (Test-Path -LiteralPath $path) {
            Get-Item -LiteralPath $path -Force
        }
    }
}

function Get-TrackedChanges {
    $result = Invoke-GitRaw -Arguments @('diff', '--quiet', 'HEAD', '--')

    if ($result.ExitCode -eq 0) {
        return $false
    }

    if ($result.ExitCode -eq 1) {
        return $true
    }

    $details = ($result.Output | ForEach-Object { "$_" }) -join "`n"
    Stop-Run "Could not determine tracked-change status. $details"
}

# ============================================================
# 3. AUDIT - READ ONLY
# ============================================================

function Invoke-Audit {
    Write-Section 'Repository'
    Write-Host $Repo

    Write-Section 'HEAD'
    Invoke-Git -Arguments @('log', '-1', '--format=%H%n%s') |
        ForEach-Object { Write-Host $_ }

    Write-Section 'Branch'
    Invoke-Git -Arguments @('branch', '--show-current') |
        ForEach-Object { Write-Host $_ }

    Write-Section 'Status'
    $status = @(Invoke-Git -Arguments @(
        'status', '--short', '--branch', '--untracked-files=all'
    ))
    if ($status.Count -eq 0) {
        Write-Host '(no status output)'
    } else {
        $status | ForEach-Object { Write-Host $_ }
    }

    Write-Section 'Tracked diff'
    $diff = @(Invoke-Git -Arguments @('diff', '--stat', 'HEAD', '--'))
    if ($diff.Count -eq 0) {
        Write-Host '(none)'
    } else {
        $diff | ForEach-Object { Write-Host $_ }
    }

    Write-Section 'Staged diff'
    $staged = @(Invoke-Git -Arguments @('diff', '--cached', '--stat'))
    if ($staged.Count -eq 0) {
        Write-Host '(none)'
    } else {
        $staged | ForEach-Object { Write-Host $_ }
    }

    Write-Section 'Required files'
    foreach ($file in $RequiredFiles) {
        Write-Host "PRESENT  $file" -ForegroundColor Green
    }

    Write-Section 'Protected recovery files'
    $protected = @(Get-ProtectedFiles)
    if ($protected.Count -eq 0) {
        Write-Host 'No matching protected files found.'
    } else {
        foreach ($item in $protected) {
            Write-Host "PRESERVED  $(Get-RelativePath $item.FullName)" -ForegroundColor Yellow
        }
    }

    Write-Section 'Generated artifacts'
    $generated = @(Get-GeneratedCandidates)
    if ($generated.Count -eq 0) {
        Write-Host 'No allowlisted generated artifacts present.'
    } else {
        foreach ($item in $generated) {
            Write-Host "PRESENT  $(Get-RelativePath $item.FullName)"
        }
    }

    Write-Section 'Repository-local configuration'
    foreach ($file in @('.gitignore', 'pyproject.toml', 'manage_repo.ps1')) {
        $path = Join-Path $Repo $file
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            Write-Host "$file  SHA256=$hash"
        } else {
            Write-Host "ABSENT  $file"
        }
    }

    Write-Host "`nAUDIT COMPLETE. No repository files were changed." -ForegroundColor Green
}

# ============================================================
# 4. VERIFY - TESTS AND WORKING-TREE EVIDENCE
# ============================================================

function Invoke-ProjectChecks {
    Write-Section 'Python syntax'

    $syntax = "import ast; from pathlib import Path; p=Path('src/harness.py'); ast.parse(p.read_text(encoding='utf-8'), filename=str(p)); print('PASS: src/harness.py syntax')"
    Invoke-CheckedProgram -Program $Python -Arguments @('-c', $syntax)

    Write-Section 'Automated test suite'

    $previous = $env:PYTHONDONTWRITEBYTECODE
    try {
        $env:PYTHONDONTWRITEBYTECODE = '1'
        Invoke-CheckedProgram -Program $Python -Arguments @(
            '-m', 'pytest', '-q', '-p', 'no:cacheprovider'
        )
    }
    finally {
        if ($null -eq $previous) {
            Remove-Item Env:PYTHONDONTWRITEBYTECODE -ErrorAction SilentlyContinue
        } else {
            $env:PYTHONDONTWRITEBYTECODE = $previous
        }
    }
}

function Invoke-Verify {
    Write-Section 'Commit'
    $head = @(Invoke-Git -Arguments @('rev-parse', '--verify', 'HEAD'))
    if ($head.Count -eq 0 -or [string]::IsNullOrWhiteSpace($head[0])) {
        Stop-Run 'HEAD could not be verified.'
    }
    Write-Host $head[0]

    Write-Section 'Tracked and staged changes'
    if (Get-TrackedChanges) {
        Invoke-Git -Arguments @('status', '--short', '--untracked-files=all') |
            ForEach-Object { Write-Host $_ }
        Stop-Run 'Tracked files or the index differ from HEAD.'
    }

    Write-Host 'PASS: tracked files and index match HEAD.' -ForegroundColor Green

    $staged = @(Invoke-Git -Arguments @('diff', '--cached', '--name-only'))
    if ($staged.Count -gt 0) {
        Stop-Run 'Unexpected staged files remain.'
    }

    Write-Section 'Whitespace check'
    $check = Invoke-GitRaw -Arguments @('diff', '--check', 'HEAD', '--')
    if ($check.ExitCode -ne 0) {
        $details = ($check.Output | ForEach-Object { "$_" }) -join "`n"
        Stop-Run "Whitespace check failed. $details"
    }
    Write-Host 'PASS: whitespace check.' -ForegroundColor Green

    Invoke-ProjectChecks

    Write-Section 'Verification result'
    Write-Host 'PASS: committed code, whitespace, syntax, and tests verified.' -ForegroundColor Green
    Write-Host 'Untracked files are reported by Audit and are not deleted or staged.'
}

# ============================================================
# 5. BACKUP
# ============================================================

function Invoke-Backup {
    Assert-BackupRoot

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bundle = Join-Path $BackupRoot "history-$stamp.bundle"
    $zip = Join-Path $BackupRoot "working-copy-$stamp.zip"
    $manifest = Join-Path $BackupRoot "manifest-$stamp.txt"
    $stage = Join-Path $env:TEMP "repo-backup-stage-$stamp"

    foreach ($path in @($bundle, $zip, $manifest, $stage)) {
        if (Test-Path -LiteralPath $path) {
            Stop-Run "Backup output already exists: $path"
        }
    }

    $files = @(
        Get-ChildItem -LiteralPath $Repo -File -Force -Recurse |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                $_.FullName -notmatch '[\\/](\.pytest_cache|__pycache__)[\\/]' -and
                $_.FullName -notmatch '[\\/]\.mypy_cache[\\/]' -and
                $_.FullName -notmatch '[\\/]\.ruff_cache[\\/]'
            }
    )

    if ($files.Count -eq 0) {
        Stop-Run 'No working-copy files found to back up.'
    }

    Write-Section 'Create staging copy'
    $null = New-Item -ItemType Directory -Path $stage

    $manifestLines = New-Object 'System.Collections.Generic.List[string]'
    $manifestLines.Add("Repository: $Repo")
    $manifestLines.Add("Created: $(Get-Date -Format o)")
    $manifestLines.Add("HEAD: $((Invoke-Git -Arguments @('rev-parse', 'HEAD'))[0])")
    $manifestLines.Add('ZIP excludes .git and known generated caches.')
    $manifestLines.Add('Recovery artifacts are included when present.')

    foreach ($file in $files) {
        $relative = Get-RelativePath $file.FullName
        $destination = Join-Path $stage $relative
        $parent = Split-Path -Parent $destination

        if (-not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }

        Copy-Item -LiteralPath $file.FullName -Destination $destination
        $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $copyHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash

        if ($sourceHash -ne $copyHash) {
            Stop-Run "Staging hash mismatch: $relative"
        }

        $manifestLines.Add("$sourceHash  $relative")
    }

    Write-Section 'Create Git bundle'
    Invoke-CheckedProgram -Program 'git' -Arguments (
        @($GitOptions) + @('bundle', 'create', $bundle, '--all')
    )

    $bundleVerify = Invoke-Native -Program 'git' -Arguments (
        @($GitOptions) + @('bundle', 'verify', $bundle)
    )
    foreach ($line in $bundleVerify.Output) { Write-Host "$line" }
    if ($bundleVerify.ExitCode -ne 0) {
        Stop-Run 'Git bundle verification failed.'
    }

    Write-Section 'Create working-copy ZIP'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal

    if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) {
        Stop-Run 'ZIP file was not created.'
    }

    Write-Section 'Verify ZIP entries'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)

    try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('/', '\') })
    }
    finally {
        $archive.Dispose()
    }

    foreach ($required in $RequiredFiles) {
        if ($required -notin $entries) {
            Stop-Run "ZIP is missing required file: $required"
        }
    }

    $manifestLines.Add("ZIP: $zip")
    $manifestLines.Add("Bundle: $bundle")
    $manifestLines.Add("ZIP entries: $($entries.Count)")
    $manifestLines | Set-Content -LiteralPath $manifest -Encoding UTF8

    Remove-Item -LiteralPath $stage -Recurse -Force

    Write-Section 'Backup result'
    Write-Host "BUNDLE  $bundle"
    Write-Host "ZIP     $zip"
    Write-Host "MANIFEST $manifest"
    Write-Host "PASS: required files present in ZIP ($($entries.Count) entries)." -ForegroundColor Green
    Write-Host 'Note: a successful backup is not a substitute for RestoreTest.'
}

# ============================================================
# 6. RESTORE TEST - ISOLATED EXTRACTION AND HASH CHECKS
# ============================================================

function Invoke-RestoreTest {
    Assert-BackupRoot

    $zips = @(
        Get-ChildItem -LiteralPath $BackupRoot -Filter 'working-copy-*.zip' -File |
            Sort-Object LastWriteTime -Descending
    )

    if ($zips.Count -eq 0) {
        Stop-Run "No working-copy ZIP found in $BackupRoot"
    }

    # Use the newest archive by default; never extract into the repository.
    $zip = $zips[0].FullName
    $testRoot = Join-Path $env:TEMP ('leh-restore-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

    if (Test-Path -LiteralPath $testRoot) {
        Stop-Run "Restore-test directory already exists: $testRoot"
    }

    Write-Section 'Archive'
    Write-Host $zip

    $null = New-Item -ItemType Directory -Path $testRoot
    Expand-Archive -LiteralPath $zip -DestinationPath $testRoot

    $checkFiles = @(
        $RequiredFiles +
        @(
            'manage_repo.ps1',
            'repair_harness.py',
            'src\harness.py.bak',
            'src\harness.py.pre-recovery-20261025-203338',
            'src\harness.py.pre-repair-20261023-184647',
            'src\harness.py.pre-restore-20261025-203426',
            'tests\test_main.py.pre-recovery-20261025-203338'
        ) | Sort-Object -Unique
    )

    $failed = $false

    Write-Section 'Required files and recovery samples'
    foreach ($relative in $checkFiles) {
        $original = Join-Path $Repo $relative
        $restored = Join-Path $testRoot $relative

        if (-not (Test-Path -LiteralPath $original -PathType Leaf)) {
            # A recovery sample might have been intentionally relocated.
            # Only compare files that currently exist in the live repository.
            continue
        }

        if (-not (Test-Path -LiteralPath $restored -PathType Leaf)) {
            Write-Host "FAIL  missing from archive: $relative" -ForegroundColor Red
            $failed = $true
            continue
        }

        $sourceHash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
        $restoredHash = (Get-FileHash -LiteralPath $restored -Algorithm SHA256).Hash

        if ($sourceHash -eq $restoredHash) {
            Write-Host "PASS  $relative" -ForegroundColor Green
        } else {
            Write-Host "FAIL  hash mismatch: $relative" -ForegroundColor Red
            $failed = $true
        }
    }

    if ($failed) {
        Stop-Run "Restore test failed. Preserve extracted files for investigation: $testRoot"
    }

    Write-Section 'Restore-test result'
    Write-Host "PASS: selected file hashes match. Extracted copy: $testRoot" -ForegroundColor Green
    Write-Host 'The extracted test copy has been retained for inspection.'
}

# ============================================================
# 7. CLEAN PREVIEW / CLEAN
# ============================================================

function Invoke-CleanPreview {
    Write-Section 'Explicit cleanup allowlist'

    $candidates = @(Get-GeneratedCandidates)

    if ($candidates.Count -eq 0) {
        Write-Host 'Nothing qualifies for cleanup.'
        return
    }

    foreach ($item in $candidates) {
        $relative = Get-RelativePath $item.FullName
        if ($item.PSIsContainer) {
            Write-Host "CANDIDATE  $relative  [directory]"
        } else {
            Write-Host "CANDIDATE  $relative  [file]"
        }
    }

    Write-Host "`nPreview only. Nothing has been moved or deleted." -ForegroundColor Yellow
    Write-Host 'Protected recovery artifacts are never eligible.'
}

function Invoke-Clean {
    Assert-BackupRoot

    $candidates = @(Get-GeneratedCandidates)

    if ($candidates.Count -eq 0) {
        Write-Host 'Nothing qualifies for cleanup.'
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $quarantine = Join-Path $BackupRoot "janitor-quarantine-$stamp"

    if (Test-Path -LiteralPath $quarantine) {
        Stop-Run "Quarantine already exists: $quarantine"
    }

    Write-Section 'Eligible generated artifacts'
    foreach ($item in $candidates) {
        Write-Host "  $(Get-RelativePath $item.FullName)"
    }

    Write-Host "`nThese items will be moved, not permanently deleted."
    if (-not $PSCmdlet.ShouldProcess($quarantine, 'Quarantine allowlisted generated artifacts')) {
        Write-Host 'Cancelled; no artifacts moved.'
        return
    }

    $null = New-Item -ItemType Directory -Path $quarantine
    $manifest = New-Object 'System.Collections.Generic.List[string]'
    $manifest.Add("Repository: $Repo")
    $manifest.Add("Created: $(Get-Date -Format o)")
    $manifest.Add('Operation: quarantine only; no permanent deletion.')

    foreach ($item in $candidates) {
        # Revalidate the candidate against the exact allowlist.
        $relative = Get-RelativePath $item.FullName
        if ($relative -notin $CleanAllowlist) {
            Stop-Run "Unexpected cleanup candidate: $relative"
        }

        $destination = Join-Path $quarantine $relative
        $parent = Split-Path -Parent $destination

        if (-not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }

        Move-Item -LiteralPath $item.FullName -Destination $destination
        $manifest.Add("MOVED: $relative")
        Write-Host "QUARANTINED  $relative" -ForegroundColor Green
    }

    $manifest | Set-Content -LiteralPath (Join-Path $quarantine 'JANITOR-MANIFEST.txt') -Encoding UTF8

    Write-Section 'Cleanup result'
    Write-Host "Quarantine: $quarantine" -ForegroundColor Green
    Write-Host 'No recovery files were eligible. Nothing was permanently deleted.'
}

# ============================================================
# 8. DISPATCH
# ============================================================

try {
    Assert-Repository

    Write-Host 'LOCAL ENGINEERING HARNESS - REPOSITORY JANITOR' -ForegroundColor Cyan
    Write-Host "Action: $Action"
    Write-Host "Path:   $Repo"

    switch ($Action) {
        'Audit'       { Invoke-Audit }
        'Verify'      { Invoke-Verify }
        'Backup'      { Invoke-Backup }
        'RestoreTest' { Invoke-RestoreTest }
        'CleanPreview'{ Invoke-CleanPreview }
        'Clean'       { Invoke-Clean }
    }

    Write-Host "`nRESULT: SUCCESS" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`nRESULT: FAILURE" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
