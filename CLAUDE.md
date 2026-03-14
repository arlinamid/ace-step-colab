# ACE-Step 1.5 — Claude Code Workflow

## Projekt leírása

ACE-Step 1.5 helyi zenei generátor (Suno.ai-szerű), GGUF formátumban, CPU-n is fut.
**Claude Code feladata**: dalszöveg írás, caption összeállítás, request JSON generálás, pipeline futtatás.

## Könyvtárstruktúra

```
d:\tool\ace-step\
├── acestep.cpp\          ← klónozott repo (git clone ide)
│   ├── build\
│   │   ├── ace-qwen3.exe
│   │   └── dit-vae.exe
│   └── models\
│       ├── acestep-5Hz-lm-*.gguf
│       ├── Qwen3-Embedding-0.6B-Q8_0.gguf
│       ├── acestep-v15-turbo-*.gguf
│       └── vae-BF16.gguf
├── output\               ← generált WAV fájlok kerülnek ide
├── requests\             ← request JSON fájlok
├── CLAUDE.md             ← ez a fájl
├── setup.ps1             ← telepítő script
├── ace-generate.ps1      ← fő wrapper script
└── examples\             ← minta request fájlok
```

## Modell konfiguráció

### Telepített (Q5 konfig) — ~5.3 GB RAM ✅
| Szerepkör | Fájl | Méret |
|-----------|------|-------|
| LM | `acestep-5Hz-lm-4B-Q5_K_M.gguf` | 2.9 GB |
| Text encoder | `Qwen3-Embedding-0.6B-Q8_0.gguf` | 748 MB |
| DiT | `acestep-v15-turbo-Q4_K_M.gguf` | 1.4 GB |
| VAE | `vae-BF16.gguf` | 322 MB |

### Ajánlott (jobb minőség) — ~7.7 GB RAM (nem telepített)
| Szerepkör | Fájl | Méret |
|-----------|------|-------|
| LM | `acestep-5Hz-lm-4B-Q8_0.gguf` | 4.2 GB |
| Text encoder | `Qwen3-Embedding-0.6B-Q8_0.gguf` | 748 MB |
| DiT | `acestep-v15-turbo-Q8_0.gguf` | 2.4 GB |
| VAE | `vae-BF16.gguf` | 322 MB |

### Minimal (gyors) — ~3.1 GB RAM (nem telepített)
| Szerepkör | Fájl | Méret |
|-----------|------|-------|
| LM | `acestep-5Hz-lm-0.6B-Q8_0.gguf` | 677 MB |
| Text encoder | `Qwen3-Embedding-0.6B-Q8_0.gguf` | 748 MB |
| DiT | `acestep-v15-turbo-Q4_K_M.gguf` | 1.4 GB |
| VAE | `vae-BF16.gguf` | 322 MB |

**FIGYELEM:** 4B LM-nél Q4_K_M TILOS — audio kódot elront! Minimum Q5_K_M kell.

## Pipeline lépések

### 1. lépés: Audio kód generálás (`ace-qwen3`)
```powershell
.\acestep.cpp\build\Release\ace-qwen3.exe `
    --request requests\request.json `
    --model   acestep.cpp\models\acestep-5Hz-lm-4B-Q8_0.gguf
# Kimenet: requests\request0.json (audio kódokkal kiegészített)
```

### 2. lépés: Audio szintézis → WAV (`dit-vae`)
```powershell
.\acestep.cpp\build\Release\dit-vae.exe `
    --request      requests\request0.json `
    --text-encoder acestep.cpp\models\Qwen3-Embedding-0.6B-Q8_0.gguf `
    --dit          acestep.cpp\models\acestep-v15-turbo-Q8_0.gguf `
    --vae          acestep.cpp\models\vae-BF16.gguf
# Kimenet: output.wav (sztereó 48kHz)
```

## Claude feladatai dalszöveg generáláskor

### 1. Caption (stílus leírás) összeállítása

A caption **angolul** írandó, tartalmazza:
- Műfaj/stílus (pl. `folk rock`, `synthwave`, `metalcore`)
- Hangszerek (pl. `violin, acoustic guitar`, `heavy guitars, double bass drums`)
- Vokál típus (pl. `male vocals`, `ethereal female vocals`, `harsh vocals`)
- Hangulat (pl. `energetic`, `dreamy`, `aggressive`)

Példák:
```
"Energetic Hungarian folk rock with violin and acoustic guitar, male vocals, driving rhythm"
"Dreamy synthwave with ethereal female vocals, atmospheric pads, retro arpeggios"
"Aggressive metalcore with harsh vocals, heavy breakdowns, double bass drums"
"Melancholic piano ballad with strings, soft female voice, emotional crescendo"
```

### 2. Lyrics (dalszöveg) struktúra

Kötelező struktúra-tagek:
- `[verse]` — versszak
- `[chorus]` — refrén
- `[bridge]` — híd (opcionális)
- `[outro]` — befejezés (opcionális)
- `[intro]` — bevezető (opcionális)

**Tipikus dal struktúra:**
```
[verse]
<első versszak szövege>

[chorus]
<refrén szövege>

[verse]
<második versszak szövege>

[chorus]
<refrén szövege>

[bridge]
<híd szövege>

[chorus]
<refrén szövege>

[outro]
<befejezés szövege>
```

### 3. Nyelv kiválasztása (vocal_language)

Támogatott értékek: `en`, `zh`, `ja`, `ko`, `fr`, `de`, `es`, `pt`, `ru`, `it`

**Magyar szöveg esetén:** Magyar nincs a listában!
- Lehetőség 1: Angol szöveg `en` nyelven (biztos megoldás)
- Lehetőség 2: Magyar szöveg `en` beállítással (kísérletezni kell, lehet hogy működik)

### 4. Request JSON összeállítása

```json
{
    "caption": "<stílus leírás angolul>",
    "lyrics": "[verse]\n<versszak>\n\n[chorus]\n<refrén>",
    "inference_steps": 8,
    "shift": 3.0,
    "vocal_language": "en"
}
```

Mezők:
- `inference_steps`: turbo DiT esetén `8`, sft/base esetén `32-50`
- `shift`: általában `3.0` (turbo-val jól működik)
- `vocal_language`: a fenti lista szerint

## Teljes workflow (gyors útmutató)

1. Felhasználó megad egy témát/stílust
2. Claude megírja a caption-t (angolul) és a lyrics-et
3. Claude generálja a request JSON-t → `requests\song_YYYYMMDD_HHMMSS.json`
4. Pipeline futtatása: `.\ace-generate.ps1 -RequestFile requests\song_*.json`
5. WAV fájl: `output\song_YYYYMMDD_HHMMSS.wav`

## Paraméter referencia

### ace-qwen3 kapcsolók
| Kapcsoló | Leírás |
|----------|--------|
| `--request <file>` | Input request JSON fájl |
| `--model <file>` | LM GGUF modell |
| `--batch <n>` | Hány variáció generálódjon (alapértelmezett: 1) |
| `--threads <n>` | CPU szálak száma |

### dit-vae kapcsolók
| Kapcsoló | Leírás |
|----------|--------|
| `--request <file>` | Input request JSON (audio kódokkal) |
| `--text-encoder <file>` | Qwen3-Embedding GGUF |
| `--dit <file>` | DiT GGUF modell |
| `--vae <file>` | VAE GGUF modell |
| `--batch <n>` | Variációk száma (különböző zaj, finom különbségek) |
| `--threads <n>` | CPU szálak száma |

## Hasznos parancsok

```powershell
# Egyszerű generálás (interaktív) — q5 profil az alapértelmezett
.\ace-generate.ps1

# Közvetlen futtatás megadott request JSON-nal
.\ace-generate.ps1 -RequestFile requests\mysong.json

# Batch: 4 variáció az LM lépésben, majd 3 renderelés az elsőből
.\ace-generate.ps1 -RequestFile requests\mysong.json -LmBatch 4 -DitBatch 3

# Profilok
.\ace-generate.ps1 -Profile q5            # telepített, ~5.3 GB (ALAPÉRTELMEZETT)
.\ace-generate.ps1 -Profile recommended   # legjobb minőség, ~7.7 GB (külön letöltés kell)
.\ace-generate.ps1 -Profile minimal       # leggyorsabb, ~3.1 GB (külön letöltés kell)
```

## Hibakeresés

| Hiba | Megoldás |
|------|----------|
| `ace-qwen3.exe not found` | Futtasd a `setup.ps1`-t a build lépéssel |
| Rossz minőségű audio kód | LM kvantálás túl alacsony — használj legalább Q5_K_M-et 4B-nél |
| OOM / crash | Váltás `minimal` profilra, vagy növeld a virtuális memóriát |
| Üres WAV | Ellenőrizd a request JSON-t: caption és lyrics nem lehet üres |
| Magyar szöveg nem szól jól | Próbáld `en` vocal_language-dzsel, vagy írj angol szöveget |

## Források

- **acestep.cpp repo**: https://github.com/ServeurpersoCom/acestep.cpp
- **GGUF modellek**: https://huggingface.co/Serveurperso/ACE-Step-1.5-GGUF
- **Eredeti ACE-Step 1.5**: https://github.com/ace-step/ACE-Step-1.5
