<p align="center">
  <img src="assets/banner.png" alt="ACE-Step Colab — Music Generation with AI" width="100%">
</p>

# ACE-Step 1.5 — Local & Colab Music Generator

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/arlinamid/ace-step-colab/blob/main/ACE-Step-Colab.ipynb)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Colab-blue)](https://github.com/arlinamid/ace-step-colab)
[![Model](https://img.shields.io/badge/🤗%20Models-Serveurperso%2FACE--Step--1.5--GGUF-orange)](https://huggingface.co/Serveurperso/ACE-Step-1.5-GGUF)
[![Backend](https://img.shields.io/badge/backend-GGML%20%7C%20CUDA%20%7C%20CPU-green)](https://github.com/ServeurpersoCom/acestep.cpp)
[![Python](https://img.shields.io/badge/python-3.8%2B-blue)](https://www.python.org/)

> **Lyrics-to-song AI** powered by [ACE-Step 1.5](https://github.com/ServeurpersoCom/acestep.cpp) (GGUF/GGML) — runs locally on CPU/GPU or on Google Colab with T4 GPU acceleration. Includes a one-click Colab notebook, Windows PowerShell wrappers, and Claude Code integration.

---

## ✨ Features

| Feature | Detail |
|---|---|
| 🚀 **One-click Colab** | T4 GPU, Drive-cached models & build — 2 min startup after first run |
| 🖥️ **Windows support** | PowerShell wrappers, WinLibs GCC, automatic PATH setup |
| 🐧 **Linux / macOS / WSL** | Bash wrappers, identical workflow |
| 🎼 **Turbo mode** | `steps=8` → ~3 min/song on T4, ~8 min on CPU |
| 🌍 **Multilingual** | EN, ZH, JA, KO, FR, DE, ES, PT, RU, IT vocal language |
| 🤖 **Claude Code ready** | `CLAUDE.md` with caption/lyrics/JSON generation instructions |
| 📦 **GGUF quantized** | Q4–Q8 profiles, 4–8 GB VRAM/RAM |

---

## 🚀 Quick Start

### Option A — Google Colab (recommended, no local install)

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/arlinamid/ace-step-colab/blob/main/ACE-Step-Colab.ipynb)

1. Open the notebook → **Runtime → Change runtime type → T4 GPU**
2. Run all cells top-to-bottom
3. Edit **Cell 6** with your caption and lyrics
4. Generated MP3 is saved to `My Drive/ACE-Step-output/`

> First run builds from source (~5 min) and downloads models (~5 GB). Both are cached to Drive — subsequent sessions start in ~2 minutes.

---

### Option B — Windows (local)

**Prerequisites:** Git, CMake ≥ 3.20, GCC ≥ 11 ([WinLibs](https://winlibs.com/)), Python 3.8+

```powershell
git clone https://github.com/arlinamid/ace-step-colab.git
cd ace-step-colab
.\setup.ps1          # clones acestep.cpp, downloads q5 models, builds binaries
```

Generate a song:

```powershell
.\ace-generate.ps1 -Request examples\synthwave-dreamy-en.json
```

Interactive mode:

```powershell
.\ace-generate.ps1 -Interactive
```

---

### Option C — Linux / macOS / WSL

```bash
git clone https://github.com/arlinamid/ace-step-colab.git
cd ace-step-colab
chmod +x ace-generate.sh setup.ps1
# Build manually (see acestep.cpp README for cmake commands)
./ace-generate.sh --request examples/synthwave-dreamy-en.json
```

---

## 📋 Model Profiles

| Profile | LM | DiT | Total | Quality | Speed |
|---|---|---|---|---|---|
| `q5` *(default)* | 4B Q5\_K\_M | turbo Q4\_K\_M | ~5.2 GB | ⭐⭐⭐⭐ | ~3 min/song |
| `q8` | 4B Q8\_0 | turbo Q8\_0 | ~7.7 GB | ⭐⭐⭐⭐⭐ | ~5 min/song |
| `minimal` | 4B Q4\_K\_M | turbo Q4\_K\_M | ~4.5 GB | ⭐⭐⭐ | ~2.5 min/song |

Switch profiles in Colab: change `PROFILE = 'q5'` in Cell 4.

---

## 🎼 Request JSON Format

```json
{
  "caption": "Energetic synthwave with arpeggiated synths, heavy bass, driving 120 BPM",
  "lyrics": "[verse]\nNeon lights in the rain...\n\n[chorus]\nRunning through the night...",
  "inference_steps": 8,
  "shift": 3.0,
  "vocal_language": "en"
}
```

| Field | Values | Default |
|---|---|---|
| `inference_steps` | 8 (turbo) / 32–50 (sft quality) | 8 |
| `shift` | 3.0–7.0 (higher = more creative) | 3.0 |
| `vocal_language` | `en` `zh` `ja` `ko` `fr` `de` `es` `pt` `ru` `it` | `en` |

Supported lyric section tags: `[verse]` `[chorus]` `[bridge]` `[intro]` `[outro]` `[pre-chorus]` `[instrumental]`

See [`examples/`](examples/) for ready-to-run requests.

---

## 🤖 Claude Code Integration

This project ships with [`CLAUDE.md`](CLAUDE.md) — instructions for Claude Code / Claude AI agents.

Claude can:
- Write captions from a style description
- Generate structured lyrics with section tags
- Produce ready-to-run request JSON files
- Batch-generate multiple songs

```bash
# In Claude Code, just describe what you want:
"Write a melancholic lo-fi hip-hop song about late-night coding, English vocals"
```

---

## 📁 Project Structure

```
ace-step-colab/
├── ACE-Step-Colab.ipynb   # Google Colab notebook (main entry point)
├── ace-generate.ps1        # Windows PowerShell wrapper
├── ace-generate.sh         # Linux / macOS / WSL Bash wrapper
├── setup.ps1               # First-time Windows setup (clone, download, build)
├── CLAUDE.md               # Claude Code / AI agent instructions
├── examples/               # Sample request JSON files
│   ├── synthwave-dreamy-en.json
│   ├── folk-rock-hungarian-en.json
│   ├── metalcore-aggressive-en.json
│   └── piano-ballad-emotional-en.json
└── acestep.cpp/            # C++ engine (cloned by setup.ps1)
```

---

## 🔧 Architecture

```
Request JSON
     │
     ▼
 ace-qwen3          ← Qwen3-4B LM  +  Qwen3-Embedding-0.6B
 (audio codes)      generates BPM, key, FSQ audio tokens
     │
     ▼
 dit-vae            ← ACE-Step DiT (flow matching) + AutoencoderOobleck VAE
 (audio synthesis)  renders tokens to 44.1 kHz MP3
     │
     ▼
  output/*.mp3
```

---

## 🛠️ Build Options

| Backend | Flag | Requirement |
|---|---|---|
| CPU (default) | — | GCC ≥ 11, CMake ≥ 3.20 |
| CUDA (NVIDIA) | `-DGGML_CUDA=ON` | CUDA Toolkit ≥ 11.8 |
| Vulkan | `-DGGML_VULKAN=ON` | Vulkan SDK |
| Metal (Apple) | `-DGGML_METAL=ON` | macOS ≥ 12 |

For Colab T4, the notebook uses `-DCMAKE_CUDA_ARCHITECTURES=75 -DGGML_CUDA_FA_ALL_QUANTS=OFF` for a fast (~5 min) CUDA build.

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE).

Built on top of:
- [acestep.cpp](https://github.com/ServeurpersoCom/acestep.cpp) — MIT License
- [ggml](https://github.com/ggerganov/ggml) — MIT License
- [ACE-Step](https://github.com/ace-step/ACE-Step) — Apache 2.0 License
- [Qwen3](https://huggingface.co/Qwen) — Apache 2.0 License
