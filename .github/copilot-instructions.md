# Copilot Instructions for emacs-openclaw

## User Experience Improvements

### Problem Statement

The openclaw-chat buffer displayed both user input and OpenClaw responses in similar pink colors (both using font-lock faces that rendered similarly), making it confusing to distinguish between messages during conversation.

### Solution Implemented

Implemented custom faces with distinct colors and visual separators to clearly differentiate between user input and AI responses.

### Changes Made

1. **Custom Faces** - Defined two new customizable faces in `emacs-openclaw.el`:
   - `emacs-openclaw-user-face`: Green, bold text for user input
   - `emacs-openclaw-response-face`: Cyan, normal weight for OpenClaw responses

2. **Visual Separators** - Added a customizable separator line between messages:
   - `emacs-openclaw-message-separator`: Unicode box-drawing characters by default

3. **Updated Display Logic** - Modified `emacs-openclaw--send-request` to:
   - Display user input with "You:" prefix in green bold
   - Display OpenClaw responses with "OpenClaw:" prefix in cyan
   - Add separator lines before user messages
   - Keep message content in default color for maximum readability

### Visual Comparison

#### Before (Confusing - both pink)
```
You: What is Emacs?
OpenClaw: Emacs is a powerful, extensible text editor...

You: How do I learn Emacs Lisp?
OpenClaw: Start with the built-in tutorial...
```
Problem: Both "You:" and "OpenClaw:" appear in similar pink/magenta colors, making it hard to distinguish who said what at a glance.

#### After (Clear distinction)
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  [gray]
You: What is Emacs?                 [green, bold]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  [gray]

OpenClaw: Emacs is a powerful,      [cyan, normal]
extensible text editor...           [default color]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  [gray]
You: How do I learn Emacs Lisp?     [green, bold]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  [gray]

OpenClaw: Start with the built-in   [cyan, normal]
tutorial...                         [default color]
```

### Key Improvements

1. **Color Differentiation**
   - User input: Green, bold → Easy to spot your questions
   - OpenClaw response: Cyan, normal → Clearly the AI's answer
   - Message content: Default color → Maximum readability

2. **Visual Separators**
   - Gray lines before each user message
   - Creates clear message boundaries
   - Customizable via `emacs-openclaw-message-separator`

3. **Consistent Prefixes**
   - "You:" always in green bold
   - "OpenClaw:" always in cyan
   - Immediately recognizable pattern

### Customization Examples

Users can customize the appearance by adding to their init.el:

```elisp
;; Change user input color
(custom-set-faces
 '(emacs-openclaw-user-face ((t :foreground "blue" :weight bold))))

;; Change OpenClaw response color
(custom-set-faces
 '(emacs-openclaw-response-face ((t :foreground "magenta" :weight normal))))

;; Change separator character/style
(setq emacs-openclaw-message-separator "────────────────────────────────")
```

### Benefits

- ✅ Clear visual distinction between user input and AI responses
- ✅ Improved readability and reduced confusion
- ✅ Fully customizable via standard Emacs face customization
- ✅ Minimal code changes (surgical modifications)
- ✅ No breaking changes to existing functionality

## Development Guidelines

### Code Style
- Use minimal, surgical changes when addressing issues
- Maintain backward compatibility
- Follow existing code patterns and conventions
- Keep documentation in `.github/copilot-instructions.md` rather than adding markdown files to the root

### Documentation
- Store implementation details and extended documentation in this file
- Keep README.md focused on user-facing configuration and usage
- Avoid adding extra markdown files to the repository root
