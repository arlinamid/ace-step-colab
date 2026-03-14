#Requires -Version 5.1
<#
.SYNOPSIS
    ACE-Step 1.5 — Zenei generátor wrapper (Windows)
.DESCRIPTION
    Futtatja az ace-qwen3 → dit-vae pipeline-t egy request JSON alapján.
    Ha nincs megadva RequestFile, interaktívan kéri be a paramtereket.
.PARAMETER RequestFile
    Meglévő request JSON fájl elérési útja.
    Ha nincs megadva, a script interaktívan generálja.
.PARAMETER Profile
    Modell profil: 'recommended' (7.7 GB, 4B LM) vagy 'minimal' (3.1 GB, 0.6B LM).
    Alapértelmezett: recommended
.PARAMETER LmBatch
    Hány különböző audio kód variációt generáljon az LM lépés. Alapértelmezett: 1
.PARAMETER DitBatch
    Hány renderelési variációt generáljon a DiT lépés (finom különbségek). Alapértelmezett: 1
.PARAMETER Threads
    CPU szálak száma. Alapértelmezett: logikai CPU magok száma
.PARAMETER OutputDir
    Kimeneti könyvtár. Alapértelmezett: .\output
.PARAMETER DryRun
    Csak kiírja a parancsokat, nem futtatja őket.
.EXAMPLE
    .\ace-generate.ps1
    .\ace-generate.ps1 -RequestFile requests\mysong.json
    .\ace-generate.ps1 -RequestFile requests\mysong.json -LmBatch 4 -DitBatch 2
    .\ace-generate.ps1 -Profile minimal -RequestFile requests\quick.json
#>

param(
    [string]$RequestFile,

    [ValidateSet('recommended', 'q5', 'minimal')]
    [string]$Profile = 'q5',

    [int]$LmBatch = 1,
    [int]$DitBatch = 1,

    [int]$Threads = 0,   # 0 = auto

    [string]$OutputDir = '',

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$RepoDir   = Join-Path $ScriptDir 'acestep.cpp'
$ModelsDir = Join-Path $RepoDir   'models'

if (-not $OutputDir) { $OutputDir = Join-Path $ScriptDir 'output' }
$RequestDir = Join-Path $ScriptDir 'requests'

# --- Auto CPU szám ---
if ($Threads -eq 0) {
    $Threads = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
}

# --- Modell útvonalak profil szerint ---
$models = switch ($Profile) {
    'minimal' {
        @{
            lm          = Join-Path $ModelsDir 'acestep-5Hz-lm-0.6B-Q8_0.gguf'
            textEncoder = Join-Path $ModelsDir 'Qwen3-Embedding-0.6B-Q8_0.gguf'
            dit         = Join-Path $ModelsDir 'acestep-v15-turbo-Q4_K_M.gguf'
            vae         = Join-Path $ModelsDir 'vae-BF16.gguf'
        }
    }
    'q5' {
        @{
            lm          = Join-Path $ModelsDir 'acestep-5Hz-lm-4B-Q5_K_M.gguf'
            textEncoder = Join-Path $ModelsDir 'Qwen3-Embedding-0.6B-Q8_0.gguf'
            dit         = Join-Path $ModelsDir 'acestep-v15-turbo-Q4_K_M.gguf'
            vae         = Join-Path $ModelsDir 'vae-BF16.gguf'
        }
    }
    default {
        @{
            lm          = Join-Path $ModelsDir 'acestep-5Hz-lm-4B-Q8_0.gguf'
            textEncoder = Join-Path $ModelsDir 'Qwen3-Embedding-0.6B-Q8_0.gguf'
            dit         = Join-Path $ModelsDir 'acestep-v15-turbo-Q8_0.gguf'
            vae         = Join-Path $ModelsDir 'vae-BF16.gguf'
        }
    }
}

# --- Bináris keresés ---
function Find-Binary([string]$name) {
    $candidates = @(
        (Join-Path $RepoDir "build\Release\$name.exe"),
        (Join-Path $RepoDir "build\$name.exe"),
        (Join-Path $RepoDir "build\Release\$name"),
        (Join-Path $RepoDir "build\$name")
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

$aceQwen3 = Find-Binary 'ace-qwen3'
$ditVae   = Find-Binary 'dit-vae'

# --- Segédfüggvények ---
function Write-Step([string]$msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Write-OK([string]$msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "  [!!] $msg" -ForegroundColor Yellow
}

function Write-Err([string]$msg) {
    Write-Host "  [HIBA] $msg" -ForegroundColor Red
}

# --- Ellenőrzések ---
function Assert-Ready {
    $ok = $true

    if (-not $aceQwen3) {
        Write-Err "ace-qwen3 bináris nem található"
        Write-Host "         Futtasd: .\setup.ps1" -ForegroundColor Red
        $ok = $false
    }
    if (-not $ditVae) {
        Write-Err "dit-vae bináris nem található"
        Write-Host "         Futtasd: .\setup.ps1" -ForegroundColor Red
        $ok = $false
    }

    foreach ($key in $models.Keys) {
        if (-not (Test-Path $models[$key])) {
            Write-Err "Modell nem található: $($models[$key])"
            Write-Host "         Futtasd: .\setup.ps1 -Profile $Profile" -ForegroundColor Red
            $ok = $false
        }
    }

    if (-not $ok) { exit 1 }
}

# --- Interaktív request generálás ---
function New-RequestInteractive {
    Write-Host ""
    Write-Host "  ACE-Step 1.5 — Interaktív dalszöveg generálás" -ForegroundColor Cyan
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""

    $caption = Read-Host "  Stílus/genre leírás (angolul, pl. 'energetic folk rock with violin')"
    if (-not $caption.Trim()) {
        Write-Err "A caption nem lehet üres!"
        exit 1
    }

    Write-Host ""
    Write-Host "  Dalszöveg (struktúra: [verse], [chorus], [bridge], [outro])" -ForegroundColor Yellow
    Write-Host "  Üres sor + Enter után folytatódik, befejezéshez: egyedüli 'END' sor" -ForegroundColor Yellow
    Write-Host ""

    $lyricsLines = [System.Collections.Generic.List[string]]::new()
    while ($true) {
        $line = Read-Host "  "
        if ($line -eq 'END') { break }
        $lyricsLines.Add($line)
    }

    $lyrics = $lyricsLines -join "`n"
    if (-not $lyrics.Trim()) {
        Write-Err "A lyrics nem lehet üres!"
        exit 1
    }

    $langInput = Read-Host "  Vokál nyelv (en/zh/ja/ko/fr/de/es/pt/ru/it) [Enter = en]"
    $lang = if ($langInput.Trim()) { $langInput.Trim() } else { 'en' }

    $stepsInput = Read-Host "  Inference lépések száma (turbo=8, sft=32-50) [Enter = 8]"
    $steps = if ($stepsInput.Trim()) { [int]$stepsInput } else { 8 }

    return @{
        caption         = $caption
        lyrics          = $lyrics
        inference_steps = $steps
        shift           = 3.0
        vocal_language  = $lang
    }
}

# --- Request JSON fájl kezelés ---
function Get-RequestData {
    if ($RequestFile) {
        if (-not (Test-Path $RequestFile)) {
            Write-Err "Request fájl nem található: $RequestFile"
            exit 1
        }
        $data = Get-Content $RequestFile -Raw | ConvertFrom-Json
        return $RequestFile, $data
    }

    # Interaktív
    $data = New-RequestInteractive

    if (-not (Test-Path $RequestDir)) {
        New-Item -ItemType Directory -Path $RequestDir | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $jsonPath  = Join-Path $RequestDir "song_$timestamp.json"

    $data | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8
    Write-OK "Request JSON mentve: $jsonPath"

    return $jsonPath, $data
}

# --- Fő futtatás ---

Write-Host ""
Write-Host "  ACE-Step 1.5 Zenei Generátor" -ForegroundColor Magenta
Write-Host "  Profil: $Profile  |  LM batch: $LmBatch  |  DiT batch: $DitBatch  |  Szálak: $Threads" -ForegroundColor DarkGray
Write-Host ""

if (-not $DryRun) {
    Assert-Ready
}

$resolvedRequestFile, $requestData = Get-RequestData

# Könyvtárak
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$requestBase = [System.IO.Path]::GetFileNameWithoutExtension($resolvedRequestFile)
$requestDir  = [System.IO.Path]::GetDirectoryName((Resolve-Path $resolvedRequestFile))

# --- 1. LÉPÉS: ace-qwen3 ---

Write-Step "1. lépés: Audio kód generálás (ace-qwen3)"
Write-Host "  Caption: $($requestData.caption)" -ForegroundColor DarkGray
Write-Host "  Modell:  $(Split-Path $models.lm -Leaf)" -ForegroundColor DarkGray

$lmArgs = @(
    '--request', $resolvedRequestFile,
    '--model',   $models.lm,
    '--threads', $Threads
)
if ($LmBatch -gt 1) { $lmArgs += '--batch', $LmBatch }

$lmCmd = "`"$aceQwen3`" $($lmArgs -join ' ')"
Write-Host "  CMD: $lmCmd" -ForegroundColor DarkGray

if ($DryRun) {
    Write-Warn "[DryRun] ace-qwen3 nem futott le"
} else {
    $startTime = Get-Date
    & $aceQwen3 @lmArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err "ace-qwen3 hibával leállt (exit code: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    $elapsed = (Get-Date) - $startTime
    Write-OK "ace-qwen3 kész  ($([math]::Round($elapsed.TotalSeconds, 1)) mp)"
}

# --- 2. LÉPÉS: dit-vae (minden generált request0..N.json-ra) ---

Write-Step "2. lépés: Audio szintézis (dit-vae)"
Write-Host "  DiT:  $(Split-Path $models.dit -Leaf)" -ForegroundColor DarkGray
Write-Host "  VAE:  $(Split-Path $models.vae -Leaf)" -ForegroundColor DarkGray

$generatedRequests = @()
for ($i = 0; $i -lt $LmBatch; $i++) {
    $candidate = Join-Path $requestDir "$($requestBase)$i.json"
    if (Test-Path $candidate) {
        $generatedRequests += $candidate
    }
}

# Fallback: ha LmBatch=1 és nincs request0.json, keressük az ace-qwen3 kimenetét
if ($generatedRequests.Count -eq 0 -and -not $DryRun) {
    Write-Err "Nem található az ace-qwen3 által generált request fájl: ${requestBase}0.json"
    Write-Host "  Várt helyen: $requestDir\" -ForegroundColor Red
    exit 1
} elseif ($DryRun -and $generatedRequests.Count -eq 0) {
    $generatedRequests = @("$requestDir\${requestBase}0.json")
}

foreach ($genReq in $generatedRequests) {
    $variantIdx = [System.IO.Path]::GetFileNameWithoutExtension($genReq) -replace '.*?(\d+)$', '$1'
    Write-Host "  Variáció: $variantIdx — $(Split-Path $genReq -Leaf)" -ForegroundColor DarkGray

    $ditArgs = @(
        '--request',      $genReq,
        '--text-encoder', $models.textEncoder,
        '--dit',          $models.dit,
        '--vae',          $models.vae,
        '--threads',      $Threads
    )
    if ($DitBatch -gt 1) { $ditArgs += '--batch', $DitBatch }

    if ($DryRun) {
        Write-Warn "[DryRun] dit-vae nem futott le"
        Write-Host "  CMD: `"$ditVae`" $($ditArgs -join ' ')" -ForegroundColor DarkGray
        continue
    }

    $startTime = Get-Date

    Push-Location $OutputDir
    try {
        & $ditVae @ditArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Err "dit-vae hibával leállt (exit code: $LASTEXITCODE)"
            exit $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }

    $elapsed = (Get-Date) - $startTime
    Write-OK "dit-vae kész  ($([math]::Round($elapsed.TotalSeconds, 1)) mp)"
}

# --- Kimeneti fájlok (MP3/WAV) összegyűjtése és áthelyezése ---
# A dit-vae a request JSON mellé írja a kimenetet: request00.mp3, request01.mp3, ...
# Áthelyezzük az $OutputDir-ba.

if (-not $DryRun) {
    Write-Step "Kimeneti fájlok összegyűjtése"

    $audioExts = @('*.mp3', '*.wav')
    $moved = @()

    foreach ($genReq in $generatedRequests) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($genReq)
        $dir  = [System.IO.Path]::GetDirectoryName((Resolve-Path $genReq))
        foreach ($ext in $audioExts) {
            $pattern = "$dir\${base}*$($ext.TrimStart('*'))"
            foreach ($f in (Get-Item $pattern -ErrorAction SilentlyContinue)) {
                $dest = Join-Path $OutputDir $f.Name
                Move-Item $f.FullName $dest -Force
                $moved += $dest
                Write-OK "$($f.Name)  ($([math]::Round($f.Length/1KB,0)) KB)  →  $OutputDir"
            }
        }
    }

    if ($moved.Count -eq 0) {
        # Fallback: bármi új MP3/WAV az output könyvtárban
        $recent = Get-ChildItem $OutputDir -Include '*.mp3','*.wav' -Recurse |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 5
        if ($recent) {
            foreach ($f in $recent) { Write-OK "$($f.Name)  ($([math]::Round($f.Length/1KB,0)) KB)" }
        } else {
            Write-Warn "Nem találhatók kimeneti audio fájlok"
        }
    }
}

# --- Összefoglaló ---

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  Generálás kész!" -ForegroundColor Green
Write-Host "  Kimenet: $OutputDir" -ForegroundColor Yellow
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
