<div align="center">

# 🎙 MindScript

### Free, local, instant voice-to-text for your Mac.
### No cloud. No subscription. No one listening.

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![On-device](https://img.shields.io/badge/AI-100%25%20On--device-blue?style=flat-square)](https://github.com/argmaxinc/WhisperKit)
[![No cloud](https://img.shields.io/badge/cloud-none-green?style=flat-square)]()

</div>

Press a hotkey. Speak. Text appears at your cursor — live, as you talk — in any app on your machine. Runs entirely on the Apple Neural Engine using open-source Whisper. Zero cost per transcription, forever.

---

## Why I built this

I type fast. I think faster. I constantly lose thoughts mid-sentence because my hands can't keep up with my brain. Every voice-to-text tool I tried either:
- Sent my audio to a cloud server I don't control
- Charged per minute or per character
- Only worked inside one specific app
- Required me to stop what I was doing and switch contexts

macOS has built-in Dictation — but it phones home to Apple servers, can't be customized, and doesn't stream text live as you speak.

So I built MindScript. One hotkey. Fully local Whisper inference on the Apple Neural Engine. Live text streaming directly at your cursor, in any app, in any language. After the first model download (~75MB, one-time), it costs absolutely nothing to run.

I open-sourced it because this should exist for everyone, for free, without a per-minute tax to a cloud provider.

---

## Demo

```
You're in VS Code writing a comment.
Press Ctrl+0.
Start talking.
Text appears at your cursor, word by word, as you speak.
Press Escape when done.
```

Works in: VS Code, terminal, browser, Slack, Notes, email, anywhere.

---

## Run it locally in 3 steps

**Prerequisites:** macOS 13+, Apple Silicon, Xcode Command Line Tools

```bash
xcode-select --install   # skip if already installed
```

```bash
git clone https://github.com/qasimtalkin/mindscript
cd mindscript
bash scripts/build.sh
open dist/MindScript.app
```

**One-time permission:** Click the mic icon in your menubar → click the orange banner → System Settings → toggle MindScript **ON** under Accessibility.

That's it. You're done. Press **Ctrl+0** to start recording anywhere.

---

## How to use

| Action | Key |
|---|---|
| Start recording | **Ctrl+0** |
| Stop + inject text at cursor | **Escape** |
| Change language | Menubar → ⚙ Settings → Language |

[language-selection.png]( language-selection.png)
   

---

## Language support

Supports 17 languages out of the box. Default is **Auto-detect** — Whisper figures out the language from your speech.

`Auto` · `English` · `Spanish` · `French` · `German` · `Italian` · `Portuguese` · `Russian` · `Chinese` · `Japanese` · `Korean` · `Arabic` · `Hindi` · `Urdu` · `Turkish` · `Dutch` · `Polish`

Pin a specific language in Settings for faster, more accurate results.

---

## What gets downloaded

| | |
|---|---|
| Whisper tiny model | ~75 MB, first launch only |
| Everything else | Nothing — zero telemetry, zero analytics |
| Where it's stored | `~/Library/Caches/huggingface/` |

Your audio never leaves your machine.

---

## Tech stack

| | |
|---|---|
| Runtime | Swift + SwiftUI, macOS 13+ |
| Speech-to-text | [WhisperKit](https://github.com/argmaxinc/WhisperKit) — CoreML + Apple Neural Engine |
| Global hotkey | [HotKey](https://github.com/soffes/HotKey) |
| Audio capture | AVFoundation, 16 kHz mono |
| Text injection | CGEvent Cmd+V + AppleScript fallback |
| Build | Swift Package Manager — no Xcode project needed |

---

## Requirements

- macOS 13.0+
- Apple Silicon (Intel works but runs slower — Neural Engine is ARM-only)
- Microphone access
- Accessibility access (for text injection — one-time grant, survives rebuilds)

---

## Project structure

```
MindScript/Sources/MindScript/
├── App/
│   ├── Pipeline.swift             # Hotkey → record → transcribe → inject
│   ├── AppState.swift             # @Observable global state
│   └── AppDelegate.swift          # NSStatusItem, menubar setup
├── HotKey/HotKeyManager.swift     # Ctrl+0 start, Escape stop
├── Audio/
│   ├── RecordingManager.swift     # AVAudioEngine mic tap
│   └── AudioBuffer.swift          # Resample to 16 kHz WAV
├── Transcription/
│   └── TranscriptionService.swift # WhisperKit wrapper, language passthrough
├── Injection/
│   └── TextInjector.swift         # CGEvent → AppleScript fallback
└── UI/
    ├── MenuBarView.swift
    ├── SettingsView.swift
    └── TranscriptionOverlay.swift
```

---

## Troubleshooting

**Text isn't appearing at my cursor**
Open the menubar popover. If there's an orange banner, click it → System Settings → Accessibility → toggle MindScript ON.

**App stuck on "Loading Whisper model"**
First launch downloads ~75 MB. Check your internet connection. To force a re-download, delete `~/Library/Caches/huggingface/`.

**Accessibility permission keeps disappearing after rebuild**
This is fixed in the current build — a stable self-signed cert keeps TCC permission alive across rebuilds. If it breaks, run `bash scripts/build.sh` again and re-grant once.

**App doesn't show in menubar**
Run `open dist/MindScript.app` from the project root. Check Console.app filtered to "MindScript" for crash logs.---

## Contributing

PRs welcome. The codebase is intentionally small and focused.

If you find a bug, open an issue with:
1. macOS version
2. Mac model (M1/M2/M3 etc.)
3. The app you were transcribing into
4. What happened vs. what you expected

If you want to add a feature, open an issue first so we can discuss it before you write the code.

---
---

## License

MIT — Use it, fork it, ship it, sell it. Credit appreciated but not required.

---

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax — the CoreML/ANE wrapper that makes on-device Whisper fast on Apple Silicon
- [OpenAI Whisper](https://github.com/openai/whisper) — the underlying model weights
- [HotKey](https://github.com/soffes/HotKey) by Sam Soffes — the cleanest global hotkey library for macOS
- [Supabase](https://supabase.com) — open source Firebase alternative for auth + database
- [Sparkle](https://sparkle-project.org) — the standard for macOS auto-updates

---
