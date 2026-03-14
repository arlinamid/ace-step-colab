# Példa request fájlok

Ezek a JSON fájlok rögtön használható példák az ACE-Step 1.5 generátorhoz.

## Futtatás

```powershell
# Bármelyik példa futtatása (Windows PowerShell):
.\ace-generate.ps1 -RequestFile examples\folk-rock-hungarian-en.json
```

```bash
# Bash (WSL / Git Bash):
./ace-generate.sh examples/folk-rock-hungarian-en.json
```

## Elérhető példák

| Fájl | Stílus | Hangulat |
|------|--------|----------|
| `folk-rock-hungarian-en.json` | Magyar folk rock hegedűvel | Energikus, büszke |
| `synthwave-dreamy-en.json` | 80-as évek synthwave | Álmodozó, nosztalgikus |
| `metalcore-aggressive-en.json` | Metalcore breakdownokkal | Agresszív, feszült |
| `piano-ballad-emotional-en.json` | Zongorás ballada vonósokkal | Érzelmes, filmzenei |

## Saját request JSON készítése

Másold valamelyik fájlt, és módosítsd:

```json
{
    "caption": "Stílus leírás ANGOLUL — műfaj, hangszerek, vokál, hangulat",
    "lyrics": "[verse]\nElső versszak...\n\n[chorus]\nRefrén...",
    "inference_steps": 8,
    "shift": 3.0,
    "vocal_language": "en"
}
```

### Caption tippek
- Mindig angolul írj
- Legyél részletes: műfaj + hangszerek + vokál + hangulat
- Példa: `"Upbeat pop rock with driving electric guitars, catchy hooks, powerful female vocals, stadium energy"`

### Lyrics struktúra
- `[verse]` — versszak
- `[chorus]` — refrén  
- `[bridge]` — híd
- `[outro]` — befejezés
- `[intro]` — bevezető

### vocal_language értékek
`en`, `zh`, `ja`, `ko`, `fr`, `de`, `es`, `pt`, `ru`, `it`

> **Megjegyzés**: Magyar (`hu`) nem támogatott. Angol szöveggel vagy `en` beállítással kísérletezz.
