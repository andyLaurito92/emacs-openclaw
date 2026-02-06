# Visual Comparison: Before and After

## BEFORE (Confusing - both pink)
```
You: What is Emacs?
OpenClaw: Emacs is a powerful, extensible text editor...

You: How do I learn Emacs Lisp?
OpenClaw: Start with the built-in tutorial...
```
Problem: Both "You:" and "OpenClaw:" appear in similar pink/magenta colors, 
making it hard to distinguish who said what at a glance.

## AFTER (Clear distinction)
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

## Key Improvements

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

## Try It Yourself

```elisp
;; Load the package
(require 'emacs-openclaw)

;; Start a chat
(emacs-openclaw-chat)

;; Type a message and press RET to see the improvements!
```

Or view the demo:
```elisp
(load-file "examples/demo-faces.el")
(demo-faces/show-example)
```

## Customization Examples

Want different colors? Easy!

```elisp
;; Blue user input instead of green
(custom-set-faces
 '(emacs-openclaw-user-face ((t :foreground "blue" :weight bold))))

;; Magenta AI responses instead of cyan
(custom-set-faces
 '(emacs-openclaw-response-face ((t :foreground "magenta" :weight normal))))

;; Simple dashes instead of Unicode lines
(setq emacs-openclaw-message-separator "------------------------------------")
```

## Impact

✅ Clear visual distinction → Less confusion  
✅ Improved readability → Better UX  
✅ Fully customizable → Fits any theme  
✅ Minimal changes → No breaking changes  
