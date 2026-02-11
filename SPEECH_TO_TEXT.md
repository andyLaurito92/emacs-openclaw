# Speech-to-Text Support (whisper.el)

emacs-openclaw now supports optional speech-to-text transcription via [whisper.el](https://github.com/narangthemang/whisper.el).

## Setup

### Prerequisites

Speech-to-text requires three components:

1. **whisper.el** — Emacs package for speech recording and transcription
2. **Whisper CLI** — OpenAI's speech-to-text tool
3. **ffmpeg** — Audio processing library

### Installation

#### 1. Install Whisper CLI

```bash
# Using pip (recommended)
pip install openai-whisper

# Or via Homebrew (macOS)
brew install openai-whisper
```

#### 2. Install ffmpeg

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt-get install ffmpeg

# Other systems: https://ffmpeg.org/download.html
```

#### 3. Install whisper.el

Add to your Emacs config:

```elisp
;; Using straight.el
(use-package whisper
  :straight (:host github :repo "narangthemang/whisper.el")
  :bind ("C-c w" . whisper-run))

;; Then configure whisper.el itself
(setq whisper-install-whispercpp-on-startup nil)  ; Already have Whisper CLI
(setq whisper-model "base")  ; Or "tiny", "small", "medium", "large"
```

#### 4. Enable in emacs-openclaw

In your Emacs config:

```elisp
(use-package emacs-openclaw
  :straight (:host github :repo "andyLaurito92/emacs-openclaw")
  :custom
  (emacs-openclaw-allow-speech-to-text t)        ; Enable speech-to-text
  (emacs-openclaw-whisper-keybinding "C-c C-s") ; Transcription keybinding
  :bind ("C-c C-o" . emacs-openclaw-chat))
```

## Usage

1. Open the OpenClaw chat buffer:
   ```
   M-x emacs-openclaw-chat
   ```

2. Press the configured keybinding (default: `C-c C-s`) to start recording

3. Speak into your microphone

4. Press `C-c C-c` to stop recording and transcribe

5. The transcribed text will be inserted into the chat input

6. Press `RET` to send the transcribed message to OpenClaw

## Configuration

### Main Toggle

```elisp
(setq emacs-openclaw-allow-speech-to-text t)
```

Enable/disable speech-to-text support. Set to `nil` (default) to disable and avoid loading whisper.el.

### Custom Keybinding

```elisp
(setq emacs-openclaw-whisper-keybinding "C-c C-s")
```

Change the keybinding for starting transcription. Set to `nil` to disable the keybinding.

### whisper.el Configuration

For full whisper.el options, see [its documentation](https://github.com/narangthemang/whisper.el).

Common options:

```elisp
(setq whisper-model "base")           ; Model size: tiny, small, base, medium, large
(setq whisper-language "en")          ; Language code (e.g., "es", "fr", "de")
(setq whisper-transcript-mode 'insert) ; Where to put transcription
```

## Troubleshooting

### "whisper.el is not installed"

Install whisper.el as shown in the [Installation](#installation) section.

### "Whisper CLI not found"

The Whisper CLI (`whisper` command) is not in your PATH.

```bash
# Verify installation
which whisper

# If not found, install it
pip install openai-whisper
```

### "ffmpeg not found"

ffmpeg is required for audio processing. Install it:

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt-get install ffmpeg
```

### Transcription is slow or inaccurate

This depends on:
- **Model size**: Larger models (medium, large) are slower but more accurate
- **Audio quality**: Speak clearly into the microphone
- **Language**: Make sure the configured language matches your speech

## Design Notes

- **Zero overhead when disabled**: If `emacs-openclaw-allow-speech-to-text` is `nil` (default), whisper.el is never loaded or required
- **User responsibility for setup**: whisper.el, Whisper CLI, and ffmpeg are user dependencies — emacs-openclaw assumes they're correctly installed and configured
- **Clean integration**: Speech transcription simply inserts text into the chat input; it integrates naturally with the existing send-message workflow
- **Non-intrusive**: The feature is entirely optional and doesn't affect core chat functionality

## Related

- [whisper.el](https://github.com/narangthemang/whisper.el) — Original speech recording integration
- [OpenAI Whisper](https://github.com/openai/whisper) — Speech-to-text model
