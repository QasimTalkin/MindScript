<div align="center">

# 🎙 MindScript - Free Multilingual Personal Scribe On Mac

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

So I built MindScript. One hotkey. Fully local Whisper inference on the Apple Neural Engine. Live text streaming directly at your cursor, in any app, in any language. After the first model download (~75MB, one-time), it costs absolutely nothing to run.

I open-sourced it because this should exist for everyone, for free, without a per-minute tax to a cloud provider.

---




## 🚀 Quick Start (Developers)

No Xcode required — just the Xcode Command Line Tools and Swift.

### 1. Clone & enter the package
```bash
git clone https://github.com/qasimtalkin/mindscript && cd mindscript/mindscript
```

### 2. Download the models (one-time)
Models are stored in `mindscript/Models/` — inside the repo, gitignored, never committed.
```bash
swift run --package-path Scripts/DownloadModels
```
This downloads `openai_whisper-tiny` (~75 MB) and `openai_whisper-base` (~145 MB) to `Models/`. Run it once; subsequent launches load from that folder instantly with no network call.

### 3. Build & run
```bash
swift run MindScript
```
A 🎙 icon appears in your menu bar. Click it to see status and settings.

### 4. Grant permissions
MindScript needs two permissions:
- **Microphone** — to record your voice
- **Accessibility** — to type transcriptions into other apps

If the prompt doesn't appear automatically, go to **System Settings → Privacy & Security → Accessibility** and toggle MindScript on.

### 5. Use it
1. Click wherever you want text to appear (Slack, Notion, Chrome, anything).
2. Press **`Ctrl + 0`** to start recording.
3. Speak. Text streams live into the app as you talk.
4. Press **`Escape`** to stop and finalize.

---

## 🧠 Model Variants & Performance

MindScript uses **WhisperKit** to run OpenAI's Whisper models locally. By default, it is optimized for speed and low memory usage.

| Model | Size | Best For | Requirement |
| :--- | :---: | :--- | :--- |
| **Tiny** | ~75MB | Fast dictation, low RAM | 2GB+ RAM (Default) |
| **Base** | ~145MB | General purpose accuracy | 4GB+ RAM |
| **Small** | ~450MB | Professional transcription | 8GB+ RAM |
| **Large-v3**| ~1.5GB | Near-perfect multilingual | 16GB+ RAM (M2+) |

### 🛠 How to switch Whisper models

1. Edit `Sources/MindScript/Utilities/Constants.swift` and change `freeTierModelName` to your preferred variant (`openai_whisper-base`, `openai_whisper-small`, etc.).
2. Add it to the download script — open `Scripts/DownloadModels/main.swift` and add the model name to the `models` array.
3. Run `swift run --package-path Scripts/DownloadModels` to fetch it into `Models/`.
4. Run `swift run MindScript` — it will load the new model from disk immediately.

---

## Language support

Supports 17 languages out of the box. Default is **Auto-detect** — Whisper figures out the language from your speech.

`Auto` · `English` · `Spanish` · `French` · `German` · `Italian` · `Portuguese` · `Russian` · `Chinese` · `Japanese` · `Korean` · `Arabic` · `Hindi` · `Urdu` · `Turkish` · `Dutch` · `Polish`

Pin a specific language in Settings for faster, more accurate results.

---

## What gets downloaded

| | |
|---|---|
| Whisper tiny model | ~75 MB, one-time (`swift run DownloadModels`) |
| Whisper base model | ~145 MB, one-time (also pre-fetched by the script) |
| Everything else | Nothing — zero telemetry, zero analytics |
| Where it's stored | `mindscript/Models/` — repo-local, gitignored |

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

## 🤝 Contributing

Contributions make the open-source community an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

MIT — Use it, fork it, ship it, sell it. Credit appreciated but not required.

---

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax — the CoreML/ANE wrapper that makes on-device Whisper fast on Apple Silicon
- [OpenAI Whisper](https://github.com/openai/whisper) — the underlying model weights
- [HotKey](https://github.com/soffes/HotKey) by Sam Soffes — the cleanest global hotkey library for macOS
- [Sparkle](https://sparkle-project.org) — the standard for macOS auto-updates

---

<div align="center">
Built with ❤️ for the Mac community.
</div>
