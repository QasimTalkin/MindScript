# MindScript

**Instant voice-to-text, anywhere on your Mac. Press ⌃(ctrl)+0, speak, done.**

No subscription. No cloud. No one listening. Everything runs on your machine.

---

## The story behind this

I'm a slow typer. I constantly lose thoughts mid-sentence because my hands can't keep up with my brain. I tried every voice transcription app out there — they were either:

- **Expensive** ($10–$30/month for something I'd use 50x a day)
- **Slow** (round-trip to a server, 3–5 second lag)
- **Privacy nightmares** (everything you say goes to someone's server)
- **Clunky** (you have to open an app, click record, wait, copy, paste)

So I built MindScript. It lives in your menubar. Press **Control + 0** anywhere — in your email, your code editor, Slack, Notes, a browser form — speak, and the text appears exactly where your cursor is. Zero clicks. Zero lag. Zero cost.

The model runs entirely on your Mac using Apple's Neural Engine. On an M1/M2/M3, `whisper-tiny` transcribes 5 seconds of audio in under 500ms. It's faster than most people type.

I'm releasing this free and open source because tools like this should exist for everyone.

---

## What it does

- **Global hotkey** — `Control + 0` works in any app, any context
- **Hold to record, release to transcribe** — natural push-to-talk feel
- **Text injects at your cursor** — no copy-paste, no clipboard clobber
- **100% on-device** — audio never leaves your Mac (uses [WhisperKit](https://github.com/argmaxinc/WhisperKit) + Apple Neural Engine)
- **Menubar app** — no Dock icon, no window, stays out of your way
- **Floating HUD** — subtle indicator shows recording/transcribing state
- **Freemium** — free tier (60 min/month local), Pro tier removes limits

---

<!-- ## Demo

```
You're writing an email in Gmail.
You stop typing mid-sentence.
Press and hold ⌃0.
Say: "Let me know if Thursday works for a 30-minute call."
Release.
That sentence appears in your email instantly.
``` -->

---

## Requirements

- macOS 14+ (Sonoma or later)
- Apple Silicon Mac (M1 / M2 / M3 / M4) — required for CoreML/ANE acceleration
- Xcode 15+ (free from the App Store)
- ~75 MB disk space for the `whisper-tiny` model (downloaded automatically on first run)

> Intel Macs: technically possible but not tested. WhisperKit will fall back to CPU inference, which is slower (~5–10s per transcription).

---

## Running locally (free, no accounts needed)

This is the full setup to go from zero to speaking into any app on your Mac.

### Step 1 — Install Xcode

Download Xcode from the Mac App Store. It's free and required for building Swift apps with CoreML support.

After it installs, point the command line tools at it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify:
```bash
swift --version
# Apple Swift version 5.9+ expected
```

### Step 2 — Clone the repo

```bash
git clone https://github.com/yourusername/mindscript.git
cd mindscript
```

### Step 3 — Build

```bash
cd MindScript
swift package resolve   # downloads WhisperKit, HotKey, Supabase-swift, Sparkle (~2-3 min first time)
swift build             # compiles everything (~3-5 min first time, incremental after)
```

You should see:
```
Build complete!
```

### Step 4 — Run

```bash
.build/debug/MindScript
```

Or build a release binary (faster transcription):
```bash
swift build -c release
.build/release/MindScript
```

### Step 5 — First launch

1. A microphone icon appears in your menubar
2. A permission dialog asks for **Microphone access** — click Allow
3. The app downloads `whisper-tiny` (~75 MB) in the background — you'll see a progress indicator in the menubar popover
4. Once downloaded, you'll see "Ready — press ⌃0 to start"

### Step 6 — Use it

- Click anywhere you want to type (a text field, editor, browser, anything)
- Press and hold **Control + 0**
- Speak
- Release **Control + 0**
- Wait ~1 second
- Your words appear at the cursor

That's it.

---

## Optional: Better accuracy with Accessibility permission

By default, MindScript injects text using CGEvent unicode simulation — this works in almost every app without any permissions.

For apps that behave oddly (some Electron apps, certain terminals), enable the Accessibility fallback:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add MindScript to the list
3. In the MindScript menubar → Settings, the injection method will switch to "Pasteboard (Cmd+V)" — more reliable for complex apps

---

## Optional: Supabase (for usage tracking + Pro tier)

The app works **100% offline without any accounts**. Supabase is only needed if you want:
- Monthly usage tracking across devices
- Pro tier (unlimited transcriptions, `whisper-base` model)
- A real freemium backend

To skip this entirely, open `MindScript/Sources/MindScript/Utilities/Constants.swift` and the app will use local-only metering (UserDefaults, resets monthly).

If you want to set up the backend:

#### Supabase

1. Create a free project at [supabase.com](https://supabase.com)
2. Run the migrations in order:
   ```bash
   # from the supabase/ directory
   supabase db push
   ```
   Or paste them manually in the Supabase SQL editor:
   - `supabase/migrations/001_users.sql`
   - `supabase/migrations/002_usage.sql`

3. Copy your credentials from **Settings → API**:
   ```swift
   // MindScript/Sources/MindScript/Utilities/Constants.swift
   static let supabaseURL     = "https://YOUR_PROJECT.supabase.co"
   static let supabaseAnonKey = "YOUR_ANON_KEY"
   ```

4. Deploy the Stripe webhook Edge Function:
   ```bash
   supabase functions deploy stripe-webhook
   ```

#### Stripe (for paid Pro tier)

1. Create a [Stripe account](https://stripe.com) (free)
2. Create a product: **MindScript Pro** at $8/month
3. Copy the Payment Link URL into `Constants.stripeProMonthlyURL`
4. In Stripe Dashboard → Webhooks, add your Supabase Edge Function URL
5. Add your Stripe secrets to Supabase Edge Function environment:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_live_...
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
   ```

---

## Project structure

```
mindscript/
├── MindScript/
│   ├── Package.swift                    # Dependencies: WhisperKit, HotKey, Supabase-swift, Sparkle
│   └── Sources/MindScript/
│       ├── App/
│       │   ├── MindScriptApp.swift      # Entry point — menubar only, no Dock icon
│       │   ├── AppDelegate.swift        # NSStatusItem, popover, URL scheme handler
│       │   ├── AppState.swift           # @Observable global state
│       │   └── Pipeline.swift          # Full hotkey → record → transcribe → inject flow
│       ├── HotKey/
│       │   └── HotKeyManager.swift      # Control+0 global hotkey registration
│       ├── Audio/
│       │   ├── RecordingManager.swift   # AVAudioEngine mic capture
│       │   └── AudioBuffer.swift        # Resamples any format → 16kHz mono WAV for Whisper
│       ├── Transcription/
│       │   ├── TranscriptionService.swift  # WhisperKit wrapper (single warm instance)
│       │   └── ModelManager.swift          # Model download/cache management
│       ├── Injection/
│       │   └── TextInjector.swift       # CGEvent unicode injection + pasteboard fallback
│       ├── Metering/
│       │   ├── MeteringService.swift    # Freemium usage check (offline-resilient)
│       │   └── UsageCache.swift         # Local UserDefaults counter
│       ├── Auth/
│       │   ├── AuthManager.swift        # Supabase auth (email magic link + Apple Sign In)
│       │   └── SessionStore.swift       # Keychain JWT storage
│       └── UI/
│           ├── MenuBarView.swift        # Popover: status, usage gauge, account
│           ├── TranscriptionOverlay.swift  # Floating HUD (Recording… / Transcribing…)
│           ├── OnboardingView.swift     # First-run flow: mic → model → account
│           ├── SettingsView.swift       # Model, hotkey, account, injection method
│           └── UpgradeView.swift        # Paywall for free tier limit
│
├── supabase/
│   ├── migrations/
│   │   ├── 001_users.sql               # profiles table (id, tier, stripe_customer_id)
│   │   └── 002_usage.sql               # usage_events table + monthly_usage view
│   └── functions/
│       └── stripe-webhook/index.ts     # Deno Edge Function: updates tier on Stripe events
│
└── scripts/
    ├── setup.sh                         # Install dependencies
    ├── build.sh                         # Release build + .app bundle
    └── notarize.sh                      # Apple notarization for distribution
```

---

## How the pipeline works

Every time you use the hotkey, this is exactly what happens:

```
⌃0 pressed
  │
  ├─ HotKeyManager captures the frontmost app reference
  │  (so text goes back to where you were, not the menubar)
  │
  ├─ RecordingManager taps AVAudioEngine input node
  │  (16kHz mono, native Apple audio stack, zero latency to start)
  │
  └─ TranscriptionOverlay shows floating "Recording…" HUD

⌃0 released
  │
  ├─ RecordingManager stops tap, writes PCM buffers → 16kHz mono WAV
  │
  ├─ TranscriptionOverlay switches to "Transcribing…"
  │
  ├─ TranscriptionService.transcribe(audioURL:) — WhisperKit on ANE
  │  (whisper-tiny: ~400ms for 5s of audio on M2)
  │
  ├─ MeteringService.checkAndIncrement() — local counter, async Supabase sync
  │  (if free tier limit hit → show UpgradeView, stop here)
  │
  ├─ Original app re-activated (50ms delay for window focus)
  │
  └─ TextInjector sends Unicode CGEvents character by character
     → Text appears at cursor in whatever app you were in
```

**Why check metering after transcription, not before?**
Transcription is local and instant. Checking the usage limit before would add a network round-trip to every single transcription. The small risk of one over-limit transcription slipping through is a better tradeoff than making the product feel slow.

---

## Why WhisperKit over whisper.cpp or the OpenAI API?

| | whisper.cpp | OpenAI Whisper API | WhisperKit |
|---|---|---|---|
| Runs on-device | Yes | No | Yes |
| Cost per transcription | $0 | ~$0.006/min | $0 |
| Privacy | Full | None | Full |
| Swift integration | Hard (C bridge) | Easy (HTTP) | Native (SPM) |
| Apple Silicon optimization | Good (Metal) | N/A | Best (CoreML + ANE) |
| Model management | Manual | N/A | Built-in |
| Latency on M2 (5s audio) | ~800ms | ~1.5s (+ network) | ~400ms |

WhisperKit uses CoreML models compiled for the Apple Neural Engine. On M-series chips, the ANE runs at ~11 TOPS and is specifically optimized for the kind of matrix multiplications Whisper uses. It's the fastest and cheapest option for a Mac-native app.

---

## Freemium model

| Tier | Monthly limit | Model | Price |
|---|---|---|---|
| Free | 60 min/month | `whisper-tiny` (75MB) | $0 |
| Pro | Unlimited | `whisper-base` (150MB) | $8/mo or $72/yr |

**Why 60 minutes for free?**

All processing is local. 60 minutes of free usage costs you literally $0 per user — no server, no GPU, no API calls. It's enough for casual daily use (standup notes, quick emails, Slack messages) but not enough for heavy dictation users, who will upgrade.

**Free tier counter is local and offline-resilient.** If Supabase is unreachable, transcriptions still work. The counter syncs in the background. Users are never blocked because of your infrastructure.

---

## Roadmap

- [ ] Custom hotkey (user-configurable, not just ⌃0)
- [ ] Streaming transcription (words appear as you speak, not after)
- [ ] Language selection (auto-detect works well but explicit is better for some)
- [ ] `whisper-small` on Pro tier (higher accuracy, 500MB)
- [ ] Snippet library (save frequently-used phrases)
- [ ] AppleScript / URL scheme API for automation
- [ ] Windows version (likely Electron + whisper.cpp when the time comes)
- [ ] App Store release

---

## Contributing

PRs welcome. The codebase is intentionally small and focused.

If you find a bug, open an issue with:
1. macOS version
2. Mac model (M1/M2/M3 etc.)
3. The app you were transcribing into
4. What happened vs. what you expected

If you want to add a feature, open an issue first so we can discuss it before you write the code.

---

## Building for distribution

If you want to sign and distribute the app yourself:

```bash
# 1. Set up signing
# You need an Apple Developer account ($99/yr) and a Developer ID certificate

# 2. Generate Sparkle keys for auto-update
cd MindScript/.build/checkouts/Sparkle-*/bin
./generate_keys
# Copy the public key into Info.plist → SUPublicEDKey
# Store the private key somewhere safe

# 3. Build release binary
./scripts/build.sh

# 4. Sign and notarize
APPLE_ID="you@example.com" \
TEAM_ID="XXXXXXXXXX" \
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize.sh

# 5. The notarized .dmg is at dist/MindScript.dmg
```

---

## License

MIT. Use it, fork it, ship it, sell it. Credit appreciated but not required.

---

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax — the CoreML/ANE wrapper that makes on-device Whisper fast on Apple Silicon
- [OpenAI Whisper](https://github.com/openai/whisper) — the underlying model weights
- [HotKey](https://github.com/soffes/HotKey) by Sam Soffes — the cleanest global hotkey library for macOS
- [Supabase](https://supabase.com) — open source Firebase alternative for auth + database
- [Sparkle](https://sparkle-project.org) — the standard for macOS auto-updates

---

*Built by someone who types too slowly and thinks too fast.*
