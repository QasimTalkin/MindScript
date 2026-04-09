# Future Work

## Speaker Diarization

**Goal:** Distinguish between speakers in a recording and label transcribed output as "Speaker 1:", "Speaker 2:", etc.

---

### Ticket 1: Heuristic Speaker Diarization (Phase 1)

**What it is:** Detect speaker changes using silence gaps between WhisperKit segments. When the gap between segment N's end and segment N+1's start exceeds a threshold (default ~1.5s), assume a new speaker started.

**Why:** No additional models or downloads needed. Works well for interviews and meetings with clear conversational turn-taking.

**Limitation:** Detects pauses, not voices — can't identify the same person across sessions or distinguish speakers who talk without pausing.

**New files needed:**
- `Sources/MindScript/Diarization/DiarizationTypes.swift` — `SpeakerTurn`, `DiarizedTranscript` structs
- `Sources/MindScript/Diarization/HeuristicDiarizer.swift` — pure struct, takes `[TranscriptionSegment]`, returns `DiarizedTranscript`

**Files to modify:**
- `TranscriptionService.swift` — add `transcribeWithSegments()` overload returning `[TranscriptionSegment]` alongside plain text
- `AppState.swift` — add `diarizationEnabled: Bool`, `diarizationPauseThreshold: Float`, `lastDiarizedTranscript: DiarizedTranscript?`
- `Pipeline.swift` — suppress streaming injection when diarization is on; call diarizer on final audio; inject labelled text
- `MenuBarView.swift` — add diarization toggle row + speakers panel (modelled on the existing summary panel)
- `SettingsView.swift` — add Speaker Diarization section with toggle + pause threshold slider

**Expected output:**
```
Speaker 1: I wanted to follow up on the project timeline.
Speaker 2: Sure, we can push the deadline by a week.
Speaker 1: That works for me.
```

---

### Ticket 2: ML-Based Speaker Diarization (Phase 2)

**What it is:** Use a CoreML speaker embedding model (e.g. SpeechBrain ECAPA-TDNN converted from PyTorch → ONNX → CoreML) to compute per-segment voice embeddings, then cluster them to identify unique speakers.

**Why:** True voice identification — can distinguish speakers who don't pause between turns, and in theory could recognise known voices across sessions.

**Prerequisite:** Ticket 1 must be complete. All pipeline wiring (deferred injection, `transcribeWithSegments`, `AppState` flags, UI panels) is shared.

**Additional files needed:**
- `Sources/MindScript/Diarization/SpeakerEmbeddingService.swift` — actor, loads `.mlpackage`, extracts mel-filterbank features, returns embedding vector per audio slice
- `Sources/MindScript/Diarization/EmbeddingDiarizer.swift` — agglomerative cosine-distance clustering of embeddings → speaker labels

**Additional files to modify:**
- `AudioBuffer.swift` — add `extractSamples(from:startSeconds:endSeconds:)` to slice raw PCM for a segment window
- `AppState.swift` — add `diarizationMode: DiarizationMode` enum (`.heuristic` / `.embedding`)
- `SettingsView.swift` — add mode picker; show embedding model download size and status
- `ModelManager.swift` / `TranscriptionService.swift` — follow existing model download/cache pattern for the embedding model

**Model to use:** `speechbrain/spkrec-ecapa-voxceleb` (~100MB). Requires offline conversion step:
`PyTorch → ONNX (speechbrain export) → CoreML (coremltools ct.convert)`

---

### Ticket 3: Named Speaker Profiles (Phase 3 — Long Term)

**What it is:** Let users register voice profiles ("that's Alice", "that's Bob") so diarization output uses real names instead of generic labels.

**Depends on:** Ticket 2 (embedding model required for voice matching).

**Rough idea:**
- UI to record a short voice sample per person
- Store their average embedding in user preferences
- At diarization time, match each cluster's centroid against stored profiles using cosine similarity
- Fall back to "Speaker N" for unrecognised voices
