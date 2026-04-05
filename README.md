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


## Run it locally in 3 steps

**Prerequisites:** macOS 13+, Apple Silicon, Xcode Command Line Tools

```bash
xcode-select --install   # skip if already installed
```

```bash
git clone https://github.com/qasimtalkin/mindscript && cd mindscript
bash scripts/build.sh
open dist/MindScript.app
```


## 🛠 How to switch Whisper models

If you have a high-end Mac (M2/M3 with 16GB+ RAM) and want better accuracy, you can switch from the default **Tiny** model to **Base**, **Small**, or **Large**.

1.  **Open the Config File:**
    Navigate to `MindScript/Sources/MindScript/Utilities/Constants.swift`.
2.  **Change the Model Name:**
    Find the line `static let freeTierModelName` and change the value:
    -   `openai_whisper-tiny` (Default, ~75MB)
    -   `openai_whisper-base` (~145MB)
    -   `openai_whisper-small` (~450MB)
    -   `openai_whisper-large-v3` (~1.5GB)
3.  **Rebuild the App:**
    From the root of the project, run the build script: `bash scripts/build.sh`
4.  **Restart MindScript:**
    Open the newly built app from `dist/MindScript.app`. It will download the new model automatically on the first launch.

---

### 2. Grant Permissions
MindScript needs two one-time permissions to work:
- **Microphone:** To hear you.
- **Accessibility:** To "type" the text into your active apps.

### 3. Start Talking
- **Ctrl + 0**: Start recording.
- **Escape**: Stop and finalize.
- **Menubar**: Change language or settings.

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
