#!/usr/bin/env bash
# ACE-Step 1.5 — Zenei generátor wrapper (WSL / Git Bash / Linux / macOS)
#
# Használat:
#   ./ace-generate.sh [opciók] [request.json]
#
# Opciók:
#   -p, --profile <recommended|minimal>   Modell profil (alapért.: recommended)
#   -l, --lm-batch <n>                    LM variációk száma (alapért.: 1)
#   -d, --dit-batch <n>                   DiT variációk száma (alapért.: 1)
#   -t, --threads <n>                     CPU szálak (alapért.: auto)
#   -o, --output-dir <dir>                Kimeneti könyvtár (alapért.: ./output)
#       --dry-run                         Csak kiírja a parancsokat
#   -h, --help                            Súgó
#
# Példák:
#   ./ace-generate.sh
#   ./ace-generate.sh requests/mysong.json
#   ./ace-generate.sh --profile minimal requests/quick.json
#   ./ace-generate.sh --lm-batch 4 --dit-batch 2 requests/mysong.json

set -euo pipefail

# --- Alapértelmezett értékek ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/acestep.cpp"
MODELS_DIR="$REPO_DIR/models"
OUTPUT_DIR="$SCRIPT_DIR/output"
REQUEST_DIR="$SCRIPT_DIR/requests"

PROFILE="recommended"
LM_BATCH=1
DIT_BATCH=1
THREADS=0
DRY_RUN=false
REQUEST_FILE=""

# --- Színek ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m'

step()  { echo -e "\n${CYAN}==> $1${NC}"; }
ok()    { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[!!]${NC} $1"; }
err()   { echo -e "  ${RED}[HIBA]${NC} $1" >&2; }

# --- Argumentum feldolgozás ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--profile)     PROFILE="$2";    shift 2 ;;
        -l|--lm-batch)    LM_BATCH="$2";   shift 2 ;;
        -d|--dit-batch)   DIT_BATCH="$2";  shift 2 ;;
        -t|--threads)     THREADS="$2";    shift 2 ;;
        -o|--output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
        --dry-run)        DRY_RUN=true;    shift ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,2\}//'
            exit 0
            ;;
        -*)
            err "Ismeretlen opció: $1"
            exit 1
            ;;
        *)
            REQUEST_FILE="$1"
            shift
            ;;
    esac
done

# --- Auto CPU szálak ---
if [[ "$THREADS" -eq 0 ]]; then
    if command -v nproc &>/dev/null; then
        THREADS=$(nproc)
    elif [[ -f /proc/cpuinfo ]]; then
        THREADS=$(grep -c ^processor /proc/cpuinfo)
    else
        THREADS=4
    fi
fi

# --- Modell útvonalak ---
if [[ "$PROFILE" == "minimal" ]]; then
    LM_MODEL="$MODELS_DIR/acestep-5Hz-lm-0.6B-Q8_0.gguf"
    DIT_MODEL="$MODELS_DIR/acestep-v15-turbo-Q4_K_M.gguf"
else
    LM_MODEL="$MODELS_DIR/acestep-5Hz-lm-4B-Q8_0.gguf"
    DIT_MODEL="$MODELS_DIR/acestep-v15-turbo-Q8_0.gguf"
fi
TEXT_ENCODER="$MODELS_DIR/Qwen3-Embedding-0.6B-Q8_0.gguf"
VAE_MODEL="$MODELS_DIR/vae-BF16.gguf"

# --- Bináris keresés ---
find_binary() {
    local name="$1"
    local candidates=(
        "$REPO_DIR/build/Release/${name}.exe"
        "$REPO_DIR/build/${name}.exe"
        "$REPO_DIR/build/Release/$name"
        "$REPO_DIR/build/$name"
    )
    for c in "${candidates[@]}"; do
        if [[ -x "$c" ]]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

ACE_QWEN3=$(find_binary ace-qwen3 2>/dev/null || true)
DIT_VAE=$(find_binary dit-vae 2>/dev/null || true)

# --- Ellenőrzések ---
assert_ready() {
    local ok=true
    if [[ -z "$ACE_QWEN3" ]]; then
        err "ace-qwen3 bináris nem található"; ok=false
    fi
    if [[ -z "$DIT_VAE" ]]; then
        err "dit-vae bináris nem található"; ok=false
    fi
    for model in "$LM_MODEL" "$TEXT_ENCODER" "$DIT_MODEL" "$VAE_MODEL"; do
        if [[ ! -f "$model" ]]; then
            err "Modell nem található: $model"; ok=false
        fi
    done
    if [[ "$ok" == false ]]; then
        echo -e "  Futtasd: ${YELLOW}./setup.ps1${NC} (Windows) vagy ${YELLOW}./setup.sh${NC} (Linux/WSL)"
        exit 1
    fi
}

# --- Interaktív request generálás ---
new_request_interactive() {
    echo ""
    echo -e "  ${CYAN}ACE-Step 1.5 — Interaktív dalszöveg generálás${NC}"
    echo -e "  ${CYAN}================================================${NC}"
    echo ""

    read -rp "  Stílus/genre leírás (angolul): " CAPTION
    if [[ -z "${CAPTION// /}" ]]; then
        err "A caption nem lehet üres!"; exit 1
    fi

    echo ""
    echo -e "  ${YELLOW}Dalszöveg (struktúra: [verse], [chorus], [bridge], [outro])${NC}"
    echo -e "  ${YELLOW}Befejezés: egyedüli 'END' sor${NC}"
    echo ""

    LYRICS=""
    while IFS= read -rp "  " line; do
        [[ "$line" == "END" ]] && break
        LYRICS+="$line"$'\n'
    done

    if [[ -z "${LYRICS// /}" ]]; then
        err "A lyrics nem lehet üres!"; exit 1
    fi
    LYRICS="${LYRICS%$'\n'}"   # trailing newline eltávolítása

    read -rp "  Vokál nyelv (en/zh/ja/ko/fr/de/es/pt/ru/it) [Enter=en]: " LANG_INPUT
    LANG="${LANG_INPUT:-en}"

    read -rp "  Inference lépések (turbo=8, sft=32-50) [Enter=8]: " STEPS_INPUT
    STEPS="${STEPS_INPUT:-8}"

    mkdir -p "$REQUEST_DIR"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    REQUEST_FILE="$REQUEST_DIR/song_$ts.json"

    # JSON escape (egyszerű: \n → \\n, " → \")
    local escaped_lyrics
    escaped_lyrics=$(printf '%s' "$LYRICS" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
        || printf '%s' "$LYRICS" | sed 's/\\/\\\\/g; s/"/\\"/g; :a;N;$!ba;s/\n/\\n/g')
    local escaped_caption
    escaped_caption=$(printf '%s' "$CAPTION" | sed 's/"/\\"/g')

    cat > "$REQUEST_FILE" << EOF
{
    "caption": "$escaped_caption",
    "lyrics": $escaped_lyrics,
    "inference_steps": $STEPS,
    "shift": 3.0,
    "vocal_language": "$LANG"
}
EOF
    ok "Request JSON mentve: $REQUEST_FILE"
}

# --- Fő futtatás ---

echo ""
echo -e "  ${MAGENTA}ACE-Step 1.5 Zenei Generátor${NC}"
echo -e "  ${GRAY}Profil: $PROFILE  |  LM batch: $LM_BATCH  |  DiT batch: $DIT_BATCH  |  Szálak: $THREADS${NC}"
echo ""

if [[ "$DRY_RUN" == false ]]; then
    assert_ready
fi

if [[ -z "$REQUEST_FILE" ]]; then
    new_request_interactive
elif [[ ! -f "$REQUEST_FILE" ]]; then
    err "Request fájl nem található: $REQUEST_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REQUEST_BASE=$(basename "${REQUEST_FILE%.json}")
REQUEST_DIR_ABS=$(dirname "$(realpath "$REQUEST_FILE")")

# --- 1. LÉPÉS: ace-qwen3 ---

step "1. lépés: Audio kód generálás (ace-qwen3)"

LM_ARGS=(
    --request "$REQUEST_FILE"
    --model   "$LM_MODEL"
    --threads "$THREADS"
)
[[ "$LM_BATCH" -gt 1 ]] && LM_ARGS+=(--batch "$LM_BATCH")

echo -e "  ${GRAY}CMD: $ACE_QWEN3 ${LM_ARGS[*]}${NC}"

if [[ "$DRY_RUN" == true ]]; then
    warn "[DryRun] ace-qwen3 nem futott le"
else
    START=$(date +%s)
    "$ACE_QWEN3" "${LM_ARGS[@]}"
    ELAPSED=$(( $(date +%s) - START ))
    ok "ace-qwen3 kész  (${ELAPSED} mp)"
fi

# --- 2. LÉPÉS: dit-vae ---

step "2. lépés: Audio szintézis (dit-vae)"

for (( i=0; i<LM_BATCH; i++ )); do
    GEN_REQ="$REQUEST_DIR_ABS/${REQUEST_BASE}${i}.json"

    if [[ "$DRY_RUN" == false && ! -f "$GEN_REQ" ]]; then
        if [[ "$i" -eq 0 ]]; then
            err "Nem található ace-qwen3 kimenet: $GEN_REQ"
            exit 1
        else
            warn "Nem találatló variáció, kihagyva: $GEN_REQ"
            continue
        fi
    fi

    echo -e "  ${GRAY}Variáció: $i — $(basename "$GEN_REQ")${NC}"

    DIT_ARGS=(
        --request      "$GEN_REQ"
        --text-encoder "$TEXT_ENCODER"
        --dit          "$DIT_MODEL"
        --vae          "$VAE_MODEL"
        --threads      "$THREADS"
    )
    [[ "$DIT_BATCH" -gt 1 ]] && DIT_ARGS+=(--batch "$DIT_BATCH")

    echo -e "  ${GRAY}CMD: $DIT_VAE ${DIT_ARGS[*]}${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        warn "[DryRun] dit-vae nem futott le"
    else
        START=$(date +%s)
        (cd "$OUTPUT_DIR" && "$DIT_VAE" "${DIT_ARGS[@]}")
        ELAPSED=$(( $(date +%s) - START ))
        ok "dit-vae kész  (${ELAPSED} mp)"
    fi
done

# --- Összefoglaló ---

if [[ "$DRY_RUN" == false ]]; then
    step "WAV fájlok"
    shopt -s nullglob
    wavs=("$OUTPUT_DIR"/*.wav)
    if [[ "${#wavs[@]}" -eq 0 ]]; then
        warn "Nem találhatók WAV fájlok: $OUTPUT_DIR"
    else
        for wav in "${wavs[@]}"; do
            ok "$(basename "$wav")  →  $OUTPUT_DIR"
        done
    fi
fi

echo ""
echo -e "  ${CYAN}============================================${NC}"
echo -e "  ${GREEN}Generálás kész!${NC}"
echo -e "  ${YELLOW}Kimenet: $OUTPUT_DIR${NC}"
echo -e "  ${CYAN}============================================${NC}"
echo ""
