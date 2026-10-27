param(
    [Parameter(Mandatory=$true)]
    [string]$SourceHtml,

    [string]$Description = "External shared note"
)

$ErrorActionPreference = "Stop"

$repo = "C:\Users\ThinkPad\Documents\line-public-share"
$expectedRemote = "https://github.com/pattawutb/line-public-share.git"
$baseUrl = "https://pattawutb.github.io/line-public-share"

function Invoke-Git {
    param([string[]]$Arguments)

    & git @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: $($Arguments -join ' ')"
    }
}

Set-Location $repo

if ((git remote get-url origin) -ne $expectedRemote) {
    throw "Unexpected remote."
}

if ((git branch --show-current) -ne "main") {
    throw "Unexpected branch."
}

if (@(git status --porcelain).Count -ne 0) {
    throw "Working tree is not clean."
}

Invoke-Git @("fetch", "origin", "main")

if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) {
    throw "Local and remote branches differ. Stop."
}

$source = (Resolve-Path -LiteralPath $SourceHtml).Path

if ([IO.Path]::GetExtension($source).ToLowerInvariant() -ne ".html") {
    throw "Source must be an HTML file."
}

$content = [IO.File]::ReadAllText($source)

if ($content -notmatch '(?i)<!doctype html|<html') {
    throw "Source does not appear to contain an HTML document."
}

$id = [guid]::NewGuid().ToString("N").Substring(0,16)
$folder = Join-Path $repo "shared"
$target = Join-Path $folder "$id.html"

New-Item -ItemType Directory -Force -Path $folder | Out-Null

Copy-Item -LiteralPath $source -Destination $target -ErrorAction Stop

$relative = "shared/$id.html"
$url = "$baseUrl/$relative"

Invoke-Git @("add", "--", $relative)
Invoke-Git @("commit", "-m", "Publish external HTML: $Description")
Invoke-Git @("push", "origin", "main")

Write-Host ""
Write-Host "PUBLISHED URL:"
Write-Host $url

$verified = $false

for ($i = 1; $i -le 20; $i++) {
    try {
        $response = Invoke-WebRequest `
            -Uri $url `
            -TimeoutSec 20 `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $verified = $true
            break
        }
    }
    catch {
        Write-Host "Waiting for deployment: $i / 20"
    }

    if ($i -lt 20) {
        Start-Sleep -Seconds 15
    }
}

if ($verified) {
    Write-Host "DEPLOYMENT VERIFIED: PASS" -ForegroundColor Green
} else {
    Write-Host "DEPLOYMENT NOT YET VERIFIED" -ForegroundColor Yellow
}

Write-Host "LINE URL: $url"
