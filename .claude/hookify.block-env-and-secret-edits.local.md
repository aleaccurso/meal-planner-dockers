---
name: block-env-and-secret-edits
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env(\.|$)|google_client_secret.*\.json
---

🚫 **Blocked: editing a live credential file**

This project's CLAUDE.md states these files hold live credentials/config and must never be edited by Claude:
- Any `.env*` file
- `google_client_secret_*.json`

If a value needs to change, tell the user what to change and let them edit it themselves.
