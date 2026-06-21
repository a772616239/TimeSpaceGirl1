---
name: external-file-modifier
description: Handle file edits outside workspace when macOS TCC blocks direct writes — write to /tmp then give cp command
---

# External File Modifier Skill

## Purpose
When Reasonix cannot directly write to a file due to macOS TCC (Transparency, Consent, and Control) restrictions or workspace sandbox limits, use this workflow to apply the changes and guide the user.

## Detection
You're in this situation when:
- `edit_file` returns "outside the workspace" error
- `cp`, `mv`, `sed`, `python` file writes all return "Operation not permitted"
- `xattr -c` + `chmod u+w` doesn't help
- The target is under `~/Downloads/`, `~/Desktop/`, `~/Documents/` (external to workspace)

## Workflow

### Step 1: Write the modified file to a location Reasonix CAN write to
Choose one:
- `/tmp/<filename>` — temporary, survives until reboot
- `<workspace>/<filename>.fixed` — persistent, user can find later

Use Python to apply edits:
```bash
python3 -c "
with open('/tmp/target_file.java', 'r') as f:
    content = f.read()
# ... string replacements ...
with open('/tmp/target_file_fixed.java', 'w') as f:
    f.write(content)
"
```

### Step 2: Generate the fix summary
Show the user:
1. What was changed (diff summary)
2. Exact file path of the fixed file
3. Exact destination they need to copy to
4. A one-liner `cp` command they can paste in terminal

### Step 3: Give the user a clear one-liner
Always include a ready-to-paste `cp` command and a Finder-friendly path.

## Common Command Pattern
```bash
cp "/tmp/<fixed_file>" "/path/to/original/destination/<file>"
```

## Notes
- This is purely a macOS TCC issue — the Reasonix process lacks Full Disk Access for external directories
- The user's terminal.app likely has Full Disk Access already, so their `cp` will work
- Never try more than 3 different write approaches — after that, just give the user the cp command
