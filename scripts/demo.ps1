# Live demo of the deployed storage platform: hierarchy, versioning, recovery, backup, security.
# Run from the project folder AFTER `terraform apply`:
#     powershell -ExecutionPolicy Bypass -File scripts\demo.ps1
# Requires: gcloud (logged in) and terraform on PATH. Takes about 2 minutes. Add -Pause 6 to slow it down.

param([int]$Pause = 4)

$ErrorActionPreference = "Stop"

function Step($title) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Start-Sleep -Seconds 2
}

function Run($cmd) {
    Write-Host "PS> $cmd" -ForegroundColor Yellow
    Invoke-Expression $cmd
    Start-Sleep -Seconds $Pause
}

$out    = terraform output -json | ConvertFrom-Json
$data   = $out.data_bucket_url.value
$backup = $out.backup_bucket_url.value
$job    = $out.backup_job_name.value
$object = "$data/documents/demo-note.txt"
$tmp    = Join-Path $env:TEMP "demo-note.txt"

Step "1. Well-organized: buckets and folder hierarchy"
Run "gcloud storage buckets list --filter='name~cloudstore' --format='table(name,location,storage_class)'"
Run "gcloud storage ls -r $data"

Step "2. Secure: encryption, public access and access model"
Run "gcloud storage buckets describe $data --format='yaml(name,location,storage_class,default_kms_key,public_access_prevention,uniform_bucket_level_access,versioning_enabled,soft_delete_policy)'"

Step "3. Reliable: versioning keeps every change"
Set-Content -Path $tmp -Value "Quarterly note - version 1"
Run "gcloud storage cp $tmp $object"
Set-Content -Path $tmp -Value "Quarterly note - version 2 (edited)"
Run "gcloud storage cp $tmp $object"
Run "gcloud storage ls -a $object"

Step "4. Disaster recovery: accidental delete, then restore"
Run "gcloud storage rm $object"
Write-Host "The live object is gone:" -ForegroundColor Green
Run "gcloud storage ls $data/documents/"
Write-Host "...but every version is still stored:" -ForegroundColor Green
Run "gcloud storage ls -a $object"

$versions = gcloud storage ls -a $object | Where-Object { $_ -match '#(\d+)$' } |
    ForEach-Object { [pscustomobject]@{ Url = $_.Trim(); Gen = [int64]($_ -replace '^.*#', '') } } |
    Sort-Object Gen -Descending
$latest = $versions[0].Url

Run "gcloud storage cp '$latest' $object"
Write-Host "Restored. Content now reads:" -ForegroundColor Green
Run "gcloud storage cat $object"

Step "5. Automated backup to a second region"
Write-Host "Running the scheduled backup job now (it normally runs every $($out.backup_interval_hours.value)h)..." -ForegroundColor Green
Write-Host "PS> gcloud transfer jobs run $job" -ForegroundColor Yellow
gcloud transfer jobs run $job
if ($LASTEXITCODE -eq 0) {
    Write-Host "Backup job started; giving it a moment to finish..." -ForegroundColor Green
    Start-Sleep -Seconds 45
} else {
    Write-Host "Could not start the job from the CLI; doing the same copy with rsync instead." -ForegroundColor DarkYellow
    Run "gcloud storage rsync -r $data $backup"
}
Run "gcloud storage ls -r $backup"

Step "Done"
Write-Host "Hierarchy, encryption, versioning, recovery and cross-region backup demonstrated." -ForegroundColor Green
Remove-Item $tmp -ErrorAction SilentlyContinue
