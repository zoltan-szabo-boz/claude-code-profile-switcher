# Claude Code Profile Switcher

Switch between multiple Claude Code configurations (Pro, Enterprise/Bedrock, API key, etc.) on Windows. Handles the `.claude` directory, `.claude.json` auth files, and VS Code process management so environment variables from one profile don't leak into another.

## The Problem

Claude Code stores its configuration in `%USERPROFILE%\.claude\`. On Windows, VS Code shares a single process across all windows — so if you open a work project (with Bedrock env vars in `settings.json`), then open a personal project, the personal window inherits the work environment. Your personal Pro subscription ends up routing through Bedrock.

## How It Works

1. Each profile gets its own `.claude` directory (active profile lives at `.claude\`, parked ones at `.claude-<name>\`)
2. Desktop shortcut → VBS launcher → detects current profile → if VS Code is running with a different profile, prompts to close it → swaps directories → opens VS Code clean

```
Desktop shortcut (.lnk)
  → launch-<project>.vbs
    → claude-switch-and-launch.vbs  (detect, prompt, close VS Code)
      → claude-switch.bat           (swap directories + JSON files)
    → open VS Code with workspace
```

## Setup

### 1. Configure Profiles

Edit `profiles.ini` to define your profiles. Each profile needs a `detect` string — a unique substring in that profile's `settings.json` (e.g., `CLAUDE_CODE_USE_BEDROCK` for a Bedrock profile). The last profile is the fallback when no detect string matches.

```ini
[work]
detect=CLAUDE_CODE_USE_BEDROCK

[personal]
detect=
```

### 2. Prepare Profile Directories

Set up a `.claude` directory for each profile with its own `settings.json`. Start with your current config:

```
%USERPROFILE%\.claude\          ← active profile (whichever is current)
%USERPROFILE%\.claude-work\     ← parked work profile
%USERPROFILE%\.claude-personal\ ← parked personal profile
```

Only one profile is active at a time. The other stays parked. For example, if work is active:
- `.claude\` contains the work config
- `.claude-personal\` contains the personal config

Similarly for `.claude.json` (auth/session state):
```
%USERPROFILE%\.claude.json            ← active
%USERPROFILE%\.claude.json.work       ← parked
%USERPROFILE%\.claude.json.personal   ← parked
```

### 3. Create Launcher Scripts

Copy an example from `examples/` and customize:

```vbs
Set WshShell = CreateObject("WScript.Shell")
scriptDir = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
WshShell.Run "wscript """ & scriptDir & "claude-switch-and-launch.vbs"" work ""D:\my-project""", 0, False
```

Change `work` to your profile name and the path to your workspace.

### 4. Create Desktop Shortcuts

Right-click your launcher `.vbs` file → **Create shortcut** → move to Desktop. Optionally set a custom icon.

## Files

| File | Purpose |
|------|---------|
| `profiles.ini` | Profile names and detection strings |
| `claude-switch.bat` | Core swap logic (directories + JSON files) |
| `claude-switch-and-launch.vbs` | GUI wrapper: detect, prompt, close VS Code, switch, relaunch |
| `examples/` | Example launcher scripts to copy and customize |

## Notes

- The profile detection reads `settings.json` and searches for the `detect` string. Put something unique in each profile's settings (Bedrock profiles naturally have `CLAUDE_CODE_USE_BEDROCK`; for others, add a comment or unused key).
- The VS Code close is graceful first (`taskkill`), with a force-kill fallback after 10 seconds.
- Before the swap, the launcher also runs `taskkill /f /t /im claude.exe`. Killing `Code.exe` alone leaves the integrated-terminal `claude` CLI and its `node` MCP/SSE children orphaned, and they keep open handles inside `.claude` — which makes the directory rename fail. The kill is scoped to `claude.exe` (not a blanket `node.exe` kill) so unrelated dev servers are left alone.
- If the swap fails (e.g. a handle is still held), the launcher shows an error dialog and does **not** open VS Code, so you never silently land on the wrong profile. The rename itself also retries a few times, since handles can linger for about a second after a process exits.
- Auth files (`.claude.json`) are swapped alongside the config directory so you stay logged in to each account.
- Works with VS Code installed in the default user location. If your VS Code is elsewhere, edit the `vscode` path in `claude-switch-and-launch.vbs`.

## Troubleshooting

**Clicking a shortcut opens VS Code but the profile didn't change.** This was the classic failure before the `claude.exe` kill was added: orphaned `claude`/`node` processes held `.claude` open, the rename silently failed, and VS Code opened on the old profile anyway. If you still see it, check for stale processes with `Get-Process claude,node | Select Name,Id,StartTime` and confirm the parked directories are consistent (exactly one of `.claude` / `.claude-<name>` per profile). A failed swap now raises an error dialog instead of failing silently.

## License

MIT
