---
name: serial
description: Start or stop the elm reactor development server for the serial project.
argument-hint: [start|stop]
allowed-tools: Bash(elm *), Bash(lsof *), Bash(kill *), Bash(pkill *)
---

Manage the `elm reactor` development server for `/home/jon/projects/serial`.

The server runs on port 8000. Open http://localhost:8000/index.html in Chrome or Edge to use the app.

## Instructions

Check `$ARGUMENTS` to decide what to do:

### If `$ARGUMENTS` is "stop" (or "down" or "kill"):
1. Find the PID: `lsof -ti:8000`
2. If a PID is found, kill it: `kill <pid>`
3. Confirm it's gone with a second `lsof -ti:8000`
4. Report success or "server was not running"

### If `$ARGUMENTS` is "start" (or "up" or empty):
1. First check if port 8000 is already in use: `lsof -ti:8000`
2. If already running, report that and provide the URL — don't start a second instance
3. If not running, start `elm reactor` in the background from `/home/jon/projects/serial`:
   `cd /home/jon/projects/serial && elm reactor`
   Run this with `run_in_background: true`
4. Report the URL: http://localhost:8000/index.html

### If `$ARGUMENTS` is "status":
1. Run `lsof -ti:8000`
2. If PID found, report running + URL
3. If not, report stopped
