You are an autonomous Linux build-and-packaging agent running locally on an Ubuntu 26.04 (resolute) machine with sudo access. I will give you an EMPTY working directory; you must do all work end-to-end inside it (you may read system files and install build dependencies system-wide). Your job is to produce and install Debian packages such that the machine offers a simplified “Ubuntu on Xorg” login (X11 session), suitable for unattended remote control (e.g., RustDesk), without requiring an interactive “approve screen share” prompt.

HARD CONSTRAINTS
- You cannot reboot the machine and you cannot log out / log in.
- Do NOT restart gdm/gdm3 (that logs the user out).
- You MUST still build successfully and install .deb packages successfully (dpkg -i should succeed; apt -f install is allowed).
- Target outcome: “Ubuntu on Xorg” available and set as default; Wayland sessions should be disabled/hidden so only the Ubuntu Xorg choice remains visible (or as close as possible without restarting gdm). Provide a clear “after reboot/logout” verification checklist.

HIGH-LEVEL STRATEGY
1) Prefer the least invasive solution first: create a small custom Debian package that:
   - Adds a GDM session entry for Ubuntu on Xorg (ubuntu-xorg.desktop) in /usr/share/xsessions/
   - Disables Wayland in /etc/gdm3/custom.conf (idempotently, preserving comments and backups)
   - Sets DefaultSession to ubuntu-xorg.desktop
   - Optionally hides competing sessions using dpkg-divert (safe + reversible) rather than deleting files.
2) BEFORE hiding sessions, verify whether GNOME Shell on this system can actually run on X11. If GNOME Shell is built Wayland-only, you must then rebuild the minimal upstream packages needed (likely gnome-session and possibly mutter/gnome-shell) with X11 enabled, then proceed with the session-only package.
3) Ensure everything is reproducible: keep patches, build logs, and the resulting .debs in the working directory.

OPERATING RULES
- Work in a strict, logged, step-by-step way. Use `set -euxo pipefail`.
- Create a top-level `logs/` directory and tee command outputs into log files.
- Never destroy system files; always back up before editing. Prefer dpkg-divert over rm/mv.
- At the end, print: what was built, what was installed, where the .debs are, and the exact manual step the human must do later (logout/login or reboot) to activate.

========================================================
STEP 0 — INITIALIZE WORKSPACE
========================================================
In the empty directory:
- Create:
  - `src/` for apt source trees
  - `pkg/` for your custom Debian packaging
  - `out/` for built .debs
  - `logs/` for logs
- Start a session log: `script -q -f logs/session.typescript` (if available) OR tee outputs.

========================================================
STEP 1 — DISCOVER CURRENT SYSTEM STATE
========================================================
Collect and save to logs:
- OS + arch:
  - `cat /etc/os-release`
  - `uname -a`
  - `dpkg --print-architecture`
- Installed versions:
  - `dpkg -l | egrep 'gdm3|gdm|gnome-session|gnome-shell|mutter|ubuntu-session|xorg|xserver-xorg'`
- Current session capability files:
  - `ls -la /usr/share/xsessions/`
  - `ls -la /usr/share/wayland-sessions/`
  - `cat /usr/share/xsessions/ubuntu.desktop`
  - `cat /usr/share/xsessions/gnome.desktop`
- Current GDM config:
  - `sudo cat /etc/gdm3/custom.conf || true`
- Determine if Xorg server exists:
  - `command -v Xorg && Xorg -version || true`
- Determine if GNOME Shell supports X11 backend (heuristic checks):
  - `gnome-shell --version || true`
  - `strings "$(command -v gnome-shell)" | grep -iE 'x11|xorg' | head -n 40 || true`
  - `ldd "$(command -v gnome-shell)" | grep -iE 'X11|xcb' || true`
  - `ls -la /usr/libexec | grep -i mutter || true`

Decision checkpoint:
- If Xorg is missing, you must ensure Xorg server packages are installed later.
- If GNOME Shell appears totally Wayland-only (no X11/Xcb deps and/or explicit “Wayland-only” indicators), plan to rebuild (Step 6). Otherwise proceed with the session-enabler package first.

========================================================
STEP 2 — ENSURE BUILD PREREQUISITES
========================================================
Install build tooling (log everything):
- `sudo apt update`
- `sudo apt install -y build-essential devscripts dpkg-dev debhelper fakeroot equivs quilt git ca-certificates`
Also ensure apt source repos are enabled:
- Check deb-src in `/etc/apt/sources.list*` or `/etc/apt/sources.list.d/*.sources` (Deb822 format).
- If deb-src disabled, enable it safely (edit with sudo; keep backups), then:
  - `sudo apt update`

========================================================
STEP 3 — CREATE A CUSTOM “UBUNTU-XORG-ONLY” DEB PACKAGE (PREFERRED PATH)
========================================================
Goal: Build a small Debian package that:
A) Installs `/usr/share/xsessions/ubuntu-xorg.desktop`
B) Idempotently updates `/etc/gdm3/custom.conf` to include:
   - `[daemon]`
   - `WaylandEnable=false`
   - `DefaultSession=ubuntu-xorg.desktop`
C) Optionally hides other sessions by diverting their .desktop files out of the way.

3.1 Create packaging skeleton
- Create package name: `ubuntu-xorg-only-session` (or similar).
- Use a simple debhelper-compat (>= 13).
- Provide:
  - `debian/control`, `debian/rules`, `debian/changelog`, `debian/install`, `debian/compat` (if needed)
  - Maintainer scripts: `debian/postinst`, `debian/prerm` (for dpkg-divert and config edits)
- Dependencies:
  - Depends: `gdm3`, `gnome-session`, `gnome-shell`, `mutter`, `xserver-xorg` (or minimal Xorg meta), `xwayland` optional.
  - For config editing: depend on `python3` (write a tiny Python script in postinst) OR use POSIX shell carefully.

3.2 Provide session file
Create `files/ubuntu-xorg.desktop` with content:
[Desktop Entry]
Name=Ubuntu on Xorg
Comment=This session logs you into Ubuntu using Xorg
Exec=env GNOME_SHELL_SESSION_MODE=ubuntu /usr/bin/gnome-session --session=ubuntu
TryExec=/usr/bin/gnome-shell
Type=Application
DesktopNames=ubuntu;GNOME
X-GDM-SessionRegisters=true
X-GDM-CanRunHeadless=true
X-GDM-SessionType=x11
X-Ubuntu-Gettext-Domain=gnome-session

Ensure it installs to `/usr/share/xsessions/ubuntu-xorg.desktop`.

3.3 Make “only Ubuntu on Xorg” visible (hide others safely)
Because you can’t restart gdm, changes won’t reflect immediately, but must be correct for next login.
Use dpkg-divert to hide these session entries from GDM menus:
- `/usr/share/xsessions/ubuntu.desktop`
- `/usr/share/xsessions/gnome.desktop`
- (Optionally) `/usr/share/wayland-sessions/ubuntu.desktop`
- `/usr/share/wayland-sessions/gnome.desktop`
- `/usr/share/wayland-sessions/ubuntu-wayland.desktop` (if exists)
- `/usr/share/wayland-sessions/gnome-wayland.desktop` (if exists)
Keep XFCE sessions untouched unless the requirement demands “only one” universally; if demanded, divert xfce.desktop too.
Implementation requirements:
- In `postinst`, for each target file that exists:
  - `dpkg-divert --package ubuntu-xorg-only-session --add --rename --divert <file>.disabled <file>`
- In `prerm` on remove:
  - `dpkg-divert --package ubuntu-xorg-only-session --remove --rename --divert <file>.disabled <file>`
Never delete files; only divert.

3.4 Update /etc/gdm3/custom.conf idempotently (no reboot; no gdm restart)
In `postinst`, do:
- Backup once: copy to `/etc/gdm3/custom.conf.bak.<timestamp>` if not already backed up.
- Ensure `[daemon]` section exists.
- Ensure keys:
  - WaylandEnable=false
  - DefaultSession=ubuntu-xorg.desktop
Implementation tips:
- Use a small embedded Python3 script to parse/patch INI-like config while preserving most content; if too hard, use careful sed/awk:
  - If line `WaylandEnable=` exists (commented or not), replace/uncomment to `WaylandEnable=false`.
  - If `DefaultSession=` exists, set to `ubuntu-xorg.desktop`, else append under `[daemon]`.
- Do not remove comments; minimal edits.

3.5 Build and install this custom package
- Build:
  - `dpkg-buildpackage -us -uc -b`
- Copy resulting `.deb` into `out/`
- Install:
  - `sudo dpkg -i out/<yourdeb>.deb` (or from parent dir)
  - If deps missing: `sudo apt -f install -y`
- Post-install validation (no logout/reboot):
  - `test -f /usr/share/xsessions/ubuntu-xorg.desktop`
  - `grep -n 'X-GDM-SessionType=x11' /usr/share/xsessions/ubuntu-xorg.desktop`
  - `sudo grep -nE 'WaylandEnable|DefaultSession|\[daemon\]' /etc/gdm3/custom.conf`
  - `sudo dpkg-divert --list | grep -E 'xsessions|wayland-sessions'` to confirm diversions

If GNOME Shell can run on X11, this should be enough.

========================================================
STEP 4 — CAN GNOME SHELL REALLY RUN ON X11? (NON-DISRUPTIVE CHECK)
========================================================
Because you cannot log out/in, do a safe “capability probe”:
- Ensure Xorg server packages exist: `sudo apt install -y xserver-xorg xserver-xorg-core`
- Install Xephyr to run nested Xorg without touching the current session:
  - `sudo apt install -y xserver-xephyr`
- Try launching a nested Xorg display:
  - `Xephyr :2 -screen 1280x720 -ac -noreset &`
  - `sleep 2`
- Then attempt to run GNOME Shell in nested mode:
  - `DISPLAY=:2 gnome-shell --nested --wayland` (if only wayland works)
  - AND attempt X11-style if supported:
    - Try: `DISPLAY=:2 gnome-shell --nested` (some builds default to X11 under Xephyr)
    - If there is an explicit X11 flag in `gnome-shell --help`, use it.
Capture errors to logs.
Success criteria:
- If gnome-shell starts and stays alive for >10 seconds on DISPLAY=:2 without a Wayland-only error, assume X11 backend is viable.
- If it errors with “Wayland-only”, “X11 backend not compiled”, or crashes immediately due to missing X11 support, you MUST rebuild (Step 6).

Clean up:
- Kill Xephyr after test: `pkill -f 'Xephyr :2' || true`

========================================================
STEP 5 — IF CAPABLE: FINALIZE “ONLY UBUNTU ON XORG” SETUP
========================================================
If Step 4 indicates X11 viability:
- Ensure diversions are applied so only ubuntu-xorg.desktop remains visible.
- Ensure `/etc/gdm3/custom.conf` has WaylandEnable=false and DefaultSession=ubuntu-xorg.desktop.
- Do NOT restart gdm. Provide the human with the exact “next login” expectation:
  - After reboot/logout, GDM should present only “Ubuntu on Xorg” (or minimal choices) and default to it.

Proceed to Step 8 (deliverables).

========================================================
STEP 6 — REBUILD UPSTREAM PACKAGES WITH X11 ENABLED (ONLY IF NECESSARY)
========================================================
Only do this if Step 4 indicates GNOME Shell/X11 not supported.

6.1 Identify which package disables X11
In working dir, fetch sources:
- `cd src/`
- `apt source gnome-session`
- `apt source gnome-shell`
- `apt source mutter`
For each source tree:
- `grep -RIn -- 'x11|xorg|wayland-only|Dx11|D x11|X11' debian/ . | tee ../logs/<pkg>-x11-grep.txt`
- Inspect `debian/rules`, `debian/control`, `debian/patches/*` for:
  - Meson flags disabling X11 (e.g., -Dx11=false)
  - Patches removing xsession targets or xorg session files
Your objective is:
- gnome-session: ensure it builds/installs X11 session support (and any xsession systemd targets if applicable).
- mutter/gnome-shell: ensure X11 backend isn’t disabled at build time.

6.2 Apply minimal packaging changes
For each package you must change:
- Create a local version suffix so apt/dpkg prefers it and doesn’t collide:
  - Use `dch --local +xorg1` to add an entry like “Enable X11 session support for Ubuntu on Xorg.”
- Modify build flags in `debian/rules` to enable X11.
- Keep patches minimal and documented (store diffs in `logs/`).

6.3 Install build dependencies and build
For each:
- `sudo apt build-dep -y <pkgname>`
- Build binary packages:
  - `debuild -us -uc -b`
- Copy resulting .debs into `out/`

6.4 Install rebuilt packages (order matters)
Typically install mutter first, then gnome-shell, then gnome-session:
- `sudo dpkg -i out/mutter_*xorg1*.deb out/*mutter*.deb` (select correct arch)
- `sudo dpkg -i out/gnome-shell_*xorg1*.deb ...`
- `sudo dpkg -i out/gnome-session_*xorg1*.deb ...`
- Then: `sudo apt -f install -y`
Verify installed versions:
- `apt-cache policy mutter gnome-shell gnome-session | tee logs/policy-after.txt`

6.5 Re-run the nested Xephyr capability test (Step 4)
If X11 now works, continue with Step 3/5 (session-only package + diversions + gdm config).

========================================================
STEP 7 — ENSURE “UBUNTU ON XORG” IS THE ONLY CHOICE (AS REQUIRED)
========================================================
If the requirement “only Ubuntu on Xorg” is strict:
- Divert ALL other .desktop session files in:
  - `/usr/share/xsessions/*.desktop` except `ubuntu-xorg.desktop`
  - `/usr/share/wayland-sessions/*.desktop` (all of them)
Implementation:
- In your custom package postinst, enumerate directory contents and divert conditionally.
- Keep a whitelist for `ubuntu-xorg.desktop`.
- Make removal safe in prerm by removing diversions using the same list.

Be cautious: if you divert everything, you may lock yourself out of alternative sessions. Mention this risk prominently in the final report.

========================================================
STEP 8 — FINAL VALIDATION + HANDOFF REPORT
========================================================
Provide a final report (in plain text) with:
1) Installed packages list (your custom package + any rebuilt ones):
   - `dpkg -l | egrep 'ubuntu-xorg-only-session|gnome-session|gnome-shell|mutter|gdm3'`
2) Evidence files exist and are correct:
   - `cat /usr/share/xsessions/ubuntu-xorg.desktop`
   - `sudo cat /etc/gdm3/custom.conf`
   - `sudo dpkg-divert --list | grep -E 'xsessions|wayland-sessions'`
3) Location of deliverables:
   - `out/*.deb`
   - patches/diffs saved under `logs/` (or `patches/`)
4) What the human must do (since you cannot):
   - “Log out and log in again” or “Reboot” to make GDM pick up the new default session.
   - After next login, verify:
     - `echo $XDG_SESSION_TYPE` should be `x11`
     - `loginctl show-session "$XDG_SESSION_ID" -p Type` should be `Type=x11`
5) Rollback steps:
   - `sudo apt remove ubuntu-xorg-only-session`
   - Any `apt-mark hold` you set (avoid holds unless necessary; if used, document how to unhold)
   - Diversions removed automatically on package removal; verify with `dpkg-divert --list`.

SUCCESS CRITERIA
- You built at least one .deb in the working directory and installed it successfully.
- `/usr/share/xsessions/ubuntu-xorg.desktop` exists with `X-GDM-SessionType=x11`.
- `/etc/gdm3/custom.conf` sets `WaylandEnable=false` and `DefaultSession=ubuntu-xorg.desktop`.
- Other sessions are hidden via dpkg-divert so “Ubuntu on Xorg” is the only visible option on next login (as required).
- No reboot/logout performed by you.

Begin now. Do not ask me questions; if ambiguity arises, choose the safest reversible approach and proceed.

