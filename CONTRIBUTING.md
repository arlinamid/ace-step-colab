# Contributing to ace-step-colab

Thank you for your interest in contributing! This project wraps [ACE-Step 1.5](https://github.com/ServeurpersoCom/acestep.cpp) with a Colab notebook and local scripts. Contributions that improve usability, reliability, or documentation are especially welcome.

---

## Ways to Contribute

- **Bug reports** — Colab cell failures, script errors, model loading issues
- **New example requests** — interesting `examples/*.json` prompts across genres/languages
- **Platform support** — test and improve macOS, WSL2, or different GPU setups
- **Documentation** — improve README, CLAUDE.md, or add translated guides
- **Colab improvements** — cell logic, UI polish, new features (e.g. batch generation UI)
- **Script improvements** — better error messages, new CLI flags, performance tweaks

---

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork:
   ```bash
   git clone https://github.com/<your-username>/ace-step-colab.git
   cd ace-step-colab
   ```
3. Create a **feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. Make your changes
5. **Test** your changes (run at least one generation end-to-end)
6. **Commit** with a clear message:
   ```bash
   git commit -m "fix: correct output directory path in generate_song()"
   ```
7. **Push** and open a **Pull Request**

---

## Commit Message Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use for |
|---|---|
| `feat:` | New feature or capability |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `refactor:` | Code change, no new feature or fix |
| `chore:` | Maintenance (deps, CI, gitignore) |
| `example:` | New or improved example request |

---

## Example JSON Guidelines

When adding files to `examples/`:

- Filename: `<genre>-<mood>-<lang>.json` (e.g. `jazz-smooth-en.json`)
- Always include all four fields: `caption`, `lyrics`, `inference_steps`, `vocal_language`
- Use `inference_steps: 8` (turbo) for quick testability
- Lyrics must use at least `[verse]` and `[chorus]` section tags
- English captions preferred (model performs best with EN captions regardless of vocal language)

---

## Colab Notebook Conventions

- Keep cell numbers in order and preserve the `# ── N. Title ──` header format
- Use `print('✅ ...')` / `print('❌ ...')` for status messages
- Do not hardcode local paths — always use variables (`REPO`, `BUILD`, `MODELS_DIR`, etc.)
- Test on a fresh Colab runtime before submitting (Runtime → Disconnect and delete runtime → re-run)

---

## Reporting Issues

When reporting a bug, please include:

1. Environment: Colab / Windows / Linux + GPU model
2. Cell number and error message (full traceback)
3. Profile used (`q5` / `q8` / `minimal`)
4. Steps to reproduce

---

## Code of Conduct

Be respectful and constructive. This is a small open-source project; maintainers are volunteers. Harassment of any kind will not be tolerated.

---

## Questions?

Open a [GitHub Discussion](https://github.com/arlinamid/ace-step-colab/discussions) or an Issue with the `question` label.
