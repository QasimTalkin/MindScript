
# 🎙 MindScript - Free Multilingual Personal Scribe On Mac

### Free, local, instant voice-to-text for your Mac.
### No cloud. No subscription. No one listening.

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![GitHub Pages](https://img.shields.io/badge/Demo-Landing%20Page-blue?style=flat-square)](https://qasimtalkin.github.io/MindScript/)
[![Latest Release](https://img.shields.io/github/v/release/qasimtalkin/mindscript?style=flat-square&color=green)](https://github.com/qasimtalkin/mindscript/releases)

---

## 🎬 Demo

![MindScript Transcription Demo](docs/assets/transcription_demo.gif)
*Streaming text live at the cursor using local Whisper.*

---

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

**Open Terminal and run these commands:**

### 1. Clone the repo and navigate to it
```bash
git clone https://github.com/qasimtalkin/mindscript
cd mindscript/MindScript
```
You're now in the `mindscript/MindScript` directory. All remaining commands run from here.

### 2. Build & install to Applications
```bash
bash install.sh
```
This script compiles MindScript, wraps it into a proper `.app` bundle with all required frameworks, signs it, and installs it to `/Applications`. This is necessary for macOS to grant Microphone and Accessibility permissions.

Once installed, launch it:
```bash
open /Applications/MindScript.app
```
A mic icon appears in your **menu bar** (top-right of screen). Click it to open the control panel.

### 3. Download Whisper model (automatic)
On first launch, MindScript automatically downloads the Whisper model (~75 MB) in the background. A progress bar appears in the menu bar popover. No manual step needed — just wait a moment and it's ready.

### 4. Grant system permissions
MindScript needs two one-time permissions:
- **Microphone** — to record your voice
- **Accessibility** — to type transcriptions into other apps

**If permission dialogs don't appear automatically:**
1. Go to **System Settings → Privacy & Security → Accessibility**
2. Find MindScript and toggle it on
3. Restart the app

### 5. Start transcribing
1. Open any app (Slack, Notion, Mail, Google Docs, anything).
2. Click where you want text to appear.
3. Press **`Ctrl + 0`** to start recording (you'll see a red dot in the menu bar).
4. Speak naturally. Text appears live as you talk.
5. Press **`Escape`** when done.

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

Click the mic icon in the menu bar and use the **Model** picker — no rebuild required:
- **Whisper Tiny** (~75 MB) — fastest, lowest RAM, great for dictation
- **Whisper Base** (~145 MB) — better accuracy, still lightweight

The selected model is saved and reloaded automatically on next launch. Switching triggers an automatic re-download if the new model isn't cached yet.

---

## Language support

Supports 17 languages out of the box. Default is **Auto-detect** — Whisper figures out the language from your speech.

`Auto` · `English` · `Spanish` · `French` · `German` · `Italian` · `Portuguese` · `Russian` · `Chinese` · `Japanese` · `Korean` · `Arabic` · `Hindi` · `Urdu` · `Turkish` · `Dutch` · `Polish`

Pin a specific language in Settings for faster, more accurate results.

---

## ✨ AI Summarisation (Local & Cloud)

MindScript can automatically summarise your voice notes into concise bullet points immediately after transcription.

### 🛠 How to enable & configure
1. Click the mic icon in your **menu bar**.
2. Toggle **Auto-summarize** to ON.
3. To change models or providers, go to **Settings** (via the menu bar icon):
   - **Provider**: Choose between **Ollama** (Local), **OpenAI**, or **Anthropic (Claude)**.
   - **Model**: Default is `glm-4.7-flash:latest` for Ollama.
   - **API Key**: Required only for OpenAI and Anthropic.

> [!TIP]
> **Ollama Users**: Make sure you have the model pulled locally before use:
> ```bash
> ollama pull glm-4.7-flash:latest
> ```

---

## What gets downloaded

| | |
|---|---|
| Whisper tiny model | ~75 MB, auto-downloaded on first launch |
| Whisper base model | ~145 MB, downloaded when selected in the menu |
| Everything else | Nothing — zero telemetry, zero analytics |
| Where it's stored | `MindScript/Models/` — repo-local, gitignored |

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

- macOS 14.0+
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
