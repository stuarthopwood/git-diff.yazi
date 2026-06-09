# git-diff.yazi

Toggle the [Yazi](https://github.com/sxyazi/yazi) preview pane between the normal
file preview and the hovered file's uncommitted **`git diff`** — rendered inline,
in colour, scrollable. Press a key to flip it on, press again to flip back.

Unlike an always-on git previewer, this **defaults to off** and delegates to Yazi's
built-in `code` previewer, so your normal previews are completely unchanged until
you ask for the diff.

## Requirements

- Yazi **≥ 25.4** (uses the `[mgr]` config section and `ya.preview_widget`).
- `git` on `PATH`.

## Installation

### Via `ya pkg` (once published)

```sh
ya pkg add stuarthopwood/git-diff
```

### Manual

Clone into your Yazi plugins directory:

```sh
# Linux / macOS
git clone https://github.com/stuarthopwood/git-diff.yazi \
  ~/.config/yazi/plugins/git-diff.yazi

# Windows (PowerShell)
git clone https://github.com/stuarthopwood/git-diff.yazi `
  "$env:APPDATA\yazi\config\plugins\git-diff.yazi"
```

## Setup

**1. Register it as a wildcard previewer** in `yazi.toml`:

```toml
[[plugin.prepend_previewers]]
url = "*"
run = "git-diff"
```

> It runs for every file, but when toggled **off** (the default) it delegates to
> the built-in `code` previewer — so normal previews are untouched.

**2. Bind a key to toggle it** in `keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "<C-g>" ]
run  = "plugin git-diff"
desc = "Toggle git-diff in the preview pane"
```

## Usage

- Hover a file, press your toggle key → the pane shows `git diff` for that file.
- `J` / `K` scrolls the diff.
- Press the key again → back to the normal preview.
- A toast confirms **Diff view ON / OFF**.

Behaviour:

| Situation | Shown |
|---|---|
| File has uncommitted changes | Coloured diff |
| No changes / not modified | *No uncommitted changes* |
| Not a git repo / untracked | git's stderr message |

## How it works

The plugin is a single wildcard previewer. A toggle flag is stored in the plugin's
sync `state`. The keybound `entry` (sync context) flips the flag and re-emits
`peek` to force a redraw. The async `peek`:

- **off** → `require("code"):peek(job)` (normal preview), or
- **on** → runs `git --no-pager diff --color=always -- <file>` in the file's
  directory and renders the ANSI output with `ui.Text.parse`.

Scrolling is handled in `seek` via `job.skip`.

## Notes

- On **Windows**, `git` must be reachable from the shell Yazi spawns. If file
  previews are blank in general, set the `YAZI_FILE_ONE` env var to your
  `file.exe` (e.g. Git's `C:\Program Files\Git\usr\bin\file.exe`) — that's a
  separate Yazi/Windows requirement, not this plugin.

## Licence

[MIT](LICENSE)
