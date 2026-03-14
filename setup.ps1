#Requires -Version 5.1
<#
.SYNOPSIS
    ACE-Step 1.5 — Telepítő script (Windows)
.DESCRIPTION
    Klónozza az acestep.cpp repót, letölti a modelleket, és buildeli a binárisokat.
.PARAMETER Profile
    Modell profil: 'recommended' (7.7 GB) vagy 'minimal' (3.1 GB). Alapértelmezett: recommended
.PARAMETER SkipClone
    Kihagyja a git clone lépést (ha már klónozva van)
.PARAMETER SkipModels
    Kihagyja a modell letöltést
.PARAMETER SkipBuild
    Kihagyja a build lépést
.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -Profile minimal
    .\setup.ps1 -SkipClone -SkipModels   # csak build
#>

param(
    [ValidateSet('recommended', 'minimal')]
    [string]$Profile = 'recommended',

    [switch]$SkipClone,
    [switch]$SkipModels,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ScriptDir  = $PSScriptRoot
$RepoDir    = Join-Path $ScriptDir 'acestep.cpp'
$ModelsDir  = Join-Path $RepoDir   'models'
$OutputDir  = Join-Path $ScriptDir 'output'
$RequestDir = Join-Path $ScriptDir 'requests'

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

function Assert-Command([string]$cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "  [HIBA] '$cmd' nem található a PATH-ban." -ForegroundColor Red
        Write-Host "         Telepítsd, majd futtasd újra ezt a scriptet." -ForegroundColor Red
        exit 1
    }
}

# --- Előfeltételek ellenőrzése ---

Write-Step "Előfeltételek ellenőrzése"

Assert-Command 'git'
Write-OK "git megtalálva: $(git --version)"

# CMake keresés — lehet hogy nincs PATH-ban, de telepítve van
$cmakeExe = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmakeExe) {
    $cmakeBin = "C:\Program Files\CMake\bin"
    if (Test-Path "$cmakeBin\cmake.exe") {
        $env:PATH += ";$cmakeBin"
        $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$cmakeBin*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$cmakeBin", "User")
            Write-OK "CMake hozzáadva PATH-hoz: $cmakeBin"
        }
    } else {
        Write-Host "  [HIBA] cmake nem található. Telepítsd: https://cmake.org/download/" -ForegroundColor Red
        exit 1
    }
}
Write-OK "cmake: $(cmake --version | Select-Object -First 1)"

# Python/pip csak modell letöltéshez kell
if (-not $SkipModels) {
    Assert-Command 'python'
    Write-OK "python megtalálva"
}

# --- Könyvtárak létrehozása ---

foreach ($dir in @($OutputDir, $RequestDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-OK "Létrehozva: $dir"
    }
}

# --- Git clone ---

if (-not $SkipClone) {
    Write-Step "Repo klónozása"

    if (Test-Path $RepoDir) {
        Write-Warn "A '$RepoDir' már létezik — clone kihagyva."
        Write-Warn "Ha frissíteni szeretnéd: cd acestep.cpp && git pull"
    } else {
        Write-Host "  Klónozás: https://github.com/ServeurpersoCom/acestep.cpp"
        git clone --recurse-submodules https://github.com/ServeurpersoCom/acestep.cpp $RepoDir
        Write-OK "Klónozás kész"
    }
} else {
    Write-Warn "Clone lépés kihagyva (-SkipClone)"
}

# --- Modellek letöltése ---

if (-not $SkipModels) {
    Write-Step "Modellek letöltése (profil: $Profile)"

    if (-not (Test-Path $ModelsDir)) {
        New-Item -ItemType Directory -Path $ModelsDir | Out-Null
    }

    # huggingface_hub telepítése
    Write-Host "  pip install huggingface_hub..."
    python -m pip install -q huggingface_hub

    $hfRepo = 'Serveurperso/ACE-Step-1.5-GGUF'

    # Közös modellek (mindkét profilban)
    $commonModels = @(
        'Qwen3-Embedding-0.6B-Q8_0.gguf',
        'vae-BF16.gguf'
    )

    # Profil-specifikus modellek
    $profileModels = if ($Profile -eq 'minimal') {
        @(
            'acestep-5Hz-lm-0.6B-Q8_0.gguf',
            'acestep-v15-turbo-Q4_K_M.gguf'
        )
    } else {
        @(
            'acestep-5Hz-lm-4B-Q8_0.gguf',
            'acestep-v15-turbo-Q8_0.gguf'
        )
    }

    $allModels = $commonModels + $profileModels

    foreach ($model in $allModels) {
        $dest = Join-Path $ModelsDir $model
        if (Test-Path $dest) {
            Write-Warn "Már létezik, kihagyva: $model"
        } else {
            Write-Host "  Letöltés: $model"
            python -c "
from huggingface_hub import hf_hub_download
import shutil, os
path = hf_hub_download(repo_id='$hfRepo', filename='$model', local_dir='$ModelsDir')
print(f'  Letöltve: {path}')
"
            Write-OK "Letöltve: $model"
        }
    }
} else {
    Write-Warn "Modell letöltés kihagyva (-SkipModels)"
}

# --- Build ---

if (-not $SkipBuild) {
    Write-Step "Build (CMake Release)"

    if (-not (Test-Path $RepoDir)) {
        Write-Host "  [HIBA] A repo nem található: $RepoDir" -ForegroundColor Red
        Write-Host "         Futtasd előbb a clone lépést." -ForegroundColor Red
        exit 1
    }

    # GCC 15 WinLibs elérési út hozzáadása ha szükséges
    $winlibsBin = "D:\tools\winlibs\mingw64\bin"
    if ((Test-Path "$winlibsBin\gcc.exe") -and ($env:PATH -notlike "*$winlibsBin*")) {
        $env:PATH += ";$winlibsBin"
        Write-OK "GCC (WinLibs) hozzáadva az aktuális session PATH-hoz: $winlibsBin"
    }

    $buildDir = Join-Path $RepoDir 'build'
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir | Out-Null
    }

    Push-Location $ScriptDir
    try {
        Write-Host "  cmake configure (MinGW Makefiles, Release)..."
        cmake -S $RepoDir -B $buildDir -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
        Write-Host "  cmake build..."
        $threads = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
        cmake --build $buildDir --config Release -j $threads
        Write-OK "Build kész"
    } finally {
        Pop-Location
    }
} else {
    Write-Warn "Build lépés kihagyva (-SkipBuild)"
}

# --- Binárisok ellenőrzése ---

Write-Step "Binárisok ellenőrzése"

$binaries = @(
    (Join-Path $RepoDir 'build\Release\ace-qwen3.exe'),
    (Join-Path $RepoDir 'build\Release\dit-vae.exe')
)

# Linux-stílusú build output is lehet
$binariesLinux = @(
    (Join-Path $RepoDir 'build\ace-qwen3'),
    (Join-Path $RepoDir 'build\dit-vae')
)

$found = $false
foreach ($bin in ($binaries + $binariesLinux)) {
    if (Test-Path $bin) {
        Write-OK "Megtalálva: $bin"
        $found = $true
    }
}

if (-not $found -and -not $SkipBuild) {
    Write-Warn "Binárisok nem találhatók — ellenőrizd a build kimenetet!"
}

# --- Modellek ellenőrzése ---

Write-Step "Modellek ellenőrzése"

if (Test-Path $ModelsDir) {
    $ggufFiles = Get-ChildItem $ModelsDir -Filter '*.gguf'
    if ($ggufFiles.Count -gt 0) {
        foreach ($f in $ggufFiles) {
            $sizeMB = [math]::Round($f.Length / 1MB, 0)
            Write-OK "$($f.Name)  ($sizeMB MB)"
        }
    } else {
        Write-Warn "Nincsenek .gguf fájlok a models/ könyvtárban"
    }
} else {
    Write-Warn "models/ könyvtár nem található"
}

# --- Összefoglaló ---

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ACE-Step 1.5 telepítés kész!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Generálás indítása:"
Write-Host "    .\ace-generate.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Vagy közvetlen request JSON-nal:"
Write-Host "    .\ace-generate.ps1 -RequestFile requests\mysong.json" -ForegroundColor Yellow
Write-Host ""
