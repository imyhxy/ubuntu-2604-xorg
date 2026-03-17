# Enable “Ubuntu on Xorg” (X11) on Ubuntu 26.04

## Status

This repo's tested working path is for the Ubuntu 26.04 snapshots that still used the GNOME 49 stack, specifically the `49.2-1ubuntu1` mutter line.

It is **not a working solution for updated GNOME 50 builds** on current Ubuntu 26.04 development snapshots.

Why:

- GNOME 49 disabled X11 sessions by default upstream.
- Upstream explicitly said that X11 session support was planned to be removed in GNOME 50.
- On current Ubuntu 26.04 GNOME 50 packages, the old native GNOME-on-Xorg session path no longer works with only a local `ubuntu-xorg-session` package plus a mutter rebuild.

References:

- GNOME 49 release notes, September 18, 2024: https://release.gnome.org/49/
- Jordan Petridis, “Why X11 sessions are disabled by default in GNOME 49”, September 10, 2024: https://blogs.gnome.org/alatiera/2024/09/10/x11-session-removal/

## Last GNOME 49 snapshot window

Using direct package-index fetches from `snapshot.ubuntu.com` and a binary search over UTC timestamps, the `resolute` `mutter-common` package flips from the GNOME 49 line to GNOME 50 between:

- `2026-03-01T21:30:00Z` -> `49.2-1ubuntu1`
- `2026-03-01T21:45:00Z` -> `50~beta-2ubuntu4`

So the **last snapshot day with mutter 49.2 is March 1, 2026 UTC**.

To reproduce that search without touching local APT state:

```bash
./scripts/find-last-mutter-49-snapshot.sh
```

Ubuntu 26.04 can land in an awkward state where:

1) **There is no “Ubuntu on Xorg” option** in the GDM gear menu, and
2) Even if you add an Xorg session entry yourself, **it login-loops** (black screen → back to GDM; second attempt hangs).

This repo is a reproducible tutorial + scripts for what we actually did to make “Ubuntu on Xorg” work again, while keeping Wayland available as a safety net.

No build artifacts or logs are committed — outputs go to `out/` / `work/` and are `.gitignore`’d.

## The “story” (what we had to fix, in order)

### Part A — Get “Ubuntu on Xorg” to even show up

On our Ubuntu 26.04 install, `/usr/share/xsessions/` didn’t provide an Ubuntu-flavoured X11 session, so there was nothing to pick in GDM.

We built a tiny local package called **`ubuntu-xorg-session`** that only does the safe/minimal bits:

- Installs `/usr/share/xsessions/ubuntu-xorg.desktop` so GDM shows **“Ubuntu on Xorg”**
- Installs the missing systemd user units needed for GNOME on X11:
  - `gnome-session-x11@.target`, `gnome-session-x11.target`
  - `org.gnome.Shell@x11.service`
  - a drop-in that makes `org.gnome.Shell.target` want the X11 shell unit
- Does **not** edit `/etc/gdm3/custom.conf` and does **not** disable/hide Wayland

That makes the option appear, but it still doesn’t mean it can successfully log in…

### Part B — Fix the mutter side of the Xorg session

What mutter needs depends on which Ubuntu 26.04 snapshot you are on:

- Earlier GNOME 49 / mutter 49 snapshots needed a local mutter rebuild with the X11 backend enabled.
- Updated GNOME 50 / mutter 50 snapshots are **not supported by this repo as a working Ubuntu Xorg login solution**.

For current mutter 50 sources, Ubuntu packaging also carried a stale Meson flag:

```text
ERROR: Unknown option: "x11"
```

That packaging issue can be patched well enough to make the source package build, but that does **not** restore a working native GNOME X11 session on GNOME 50.

## What this repo provides

- A reproducible builder for **`ubuntu-xorg-session`** (adds the session entry + missing systemd user units).
- A Docker-based builder for the GNOME 49-era Ubuntu `mutter` source path we actually used successfully.
- A rollback script that removes the local session package and downgrades mutter back to the Ubuntu repo version.

## Requirements

- Ubuntu 26.04
- `docker` working for your user (`docker ps` works)
- `sudo` access (only used by install/rollback steps)

Wayland is intentionally **not disabled** during the main desktop-session setup so you can always log in with “Ubuntu” (Wayland) if Xorg breaks.

## Quick start

Only use this on the GNOME 49 / mutter 49 package line.

```bash
./scripts/run-all.sh --yes
```

Then log out and pick **“Ubuntu on Xorg”** in GDM.

## Current GNOME 50 hosts: supported downgrade path

If your Ubuntu 26.04 machine has already moved to the GNOME 50 stack, the supported path in this repo is:

1. Downgrade the GNOME session packages back to the older Ubuntu 49-era binaries.
2. Install the patched mutter 49.2 runtime packages.
3. Install the local `ubuntu-xorg-session` package so GDM exposes **Ubuntu on Xorg** again.

The matched downgrade bundle is:

- `gdm3 49.2-1ubuntu3`
- `libgdm1 49.2-1ubuntu3`
- `gir1.2-gdm-1.0 49.2-1ubuntu3`
- `gnome-session 49.2-3ubuntu1`
- `gnome-session-bin 49.2-3ubuntu1`
- `gnome-session-common 49.2-3ubuntu1`
- `ubuntu-session 49.2-3ubuntu1`
- `gnome-shell 49.2-1ubuntu2`
- `gnome-shell-common 49.2-1ubuntu2`
- `gnome-shell-ubuntu-extensions 49.26.04.2ubuntu`
- patched mutter release assets built from the `49.2-1ubuntu1` line

Preview the downgrade first:

```bash
./scripts/simulate-gnome49-downgrade.sh
```

If the simulation looks acceptable, do the real downgrade:

```bash
./scripts/install-gnome49-downgrade.sh --yes
```

If you also want the **GDM greeter / login screen itself** to run on Xorg so tools like RustDesk can work there, add this extra step:

```bash
./scripts/enable-gdm-xorg-greeter.sh --yes
```

That changes `/etc/gdm3/custom.conf` to set:

```ini
[daemon]
WaylandEnable=false
```

Tradeoff:

- `WaylandEnable=false`: X11 greeter, better login-screen compatibility for X11-only remote tools, but recovery is less forgiving if Xorg breaks again.
- default GDM config: Wayland greeter, safer fallback, but RustDesk will say login-screen Wayland is unsupported.

## RustDesk slowdown after package updates

If Xorg login works but RustDesk itself becomes very slow after a package update, the first rollback path in this repo is the exact Mesa userspace set that changed on `2026-03-16 09:41:06`:

- `libegl-mesa0 26.0.1-2ubuntu1 -> 25.2.8-2ubuntu1`
- `libgl1-mesa-dri 26.0.1-2ubuntu1 -> 25.2.8-2ubuntu1`
- `libglx-mesa0 26.0.1-2ubuntu1 -> 25.2.8-2ubuntu1`
- `libgbm1 amd64/i386 26.0.1-2ubuntu1 -> 25.2.8-2ubuntu1`
- `mesa-libgallium amd64/i386 26.0.1-2ubuntu1 -> 25.2.8-2ubuntu1`
- restore `mesa-va-drivers` and `mesa-vdpau-drivers`, which were removed during that upgrade

Download the exact old package files from Launchpad:

```bash
./scripts/download-rustdesk-slowdown-rollback-debs.sh
```

Preview the rollback first:

```bash
./scripts/simulate-rustdesk-slowdown-rollback.sh
```

Install the Mesa rollback:

```bash
./scripts/install-rustdesk-slowdown-rollback.sh --yes
```

Important:

- Mesa-only rollback is the lower-risk path.
- I checked the helper-package rollback too (`gnome-settings-daemon`, `gnome-settings-daemon-common`, `xdg-desktop-portal-gnome`), but current `libgtk-4-1 4.21.6+ds-1` explicitly breaks `xdg-desktop-portal-gnome < 50`, so that path is not scripted here as a supported install flow.

## RustDesk UI alignment rollback

If the Mesa rollback does not help, the next candidate set is the GTK/GNOME helper side:

- `libgtk-4-1 4.21.6+ds-1 -> 4.21.5+ds-5`
- `libgtk-4-common 4.21.6+ds-1 -> 4.21.5+ds-5`
- `gir1.2-gtk-4.0 4.21.6+ds-1 -> 4.21.5+ds-5`
- `gnome-settings-daemon 50~beta-0ubuntu2 -> 49.0-1ubuntu3`
- `gnome-settings-daemon-common 50~beta-0ubuntu2 -> 49.0-1ubuntu3`

Download those packages:

```bash
./scripts/download-rustdesk-ui-alignment-debs.sh
```

Preview the rollback:

```bash
./scripts/simulate-rustdesk-ui-alignment.sh
```

Install it:

```bash
./scripts/install-rustdesk-ui-alignment.sh --yes
```

Important:

- This is more experimental than the Mesa rollback.
- GTK packages are pulled from the earlier Resolute `4.21.5+ds-5` build that was on the machine before the morning upgrade.
- `gnome-settings-daemon` is pulled from Ubuntu Questing `49.0-1ubuntu3`, because current Resolute no longer publishes the GNOME 49-era package.
- This flow intentionally does **not** downgrade `xdg-desktop-portal-gnome`, because GTK 4 on current Resolute declares `Breaks: xdg-desktop-portal-gnome (< 50~)`.

## RustDesk boot-time env workaround

If both rollback paths fail, check whether `rustdesk.service` is still spawning its desktop-side `--server` process with stale greeter variables like:

- `WAYLAND_DISPLAY=wayland-0`
- `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/60578/bus`

while your real desktop session is already `XDG_SESSION_TYPE=x11`.

This repo includes a systemd workaround that restarts `rustdesk.service` when your X11 user session becomes ready:

```bash
sudo ./scripts/install-rustdesk-x11-refresh-workaround.sh --yes --user "$USER"
```

It installs:

- a helper under `/usr/local/lib/ubuntu-2604-xorg/`
- `rustdesk-x11-refresh.service`
- `rustdesk-x11-refresh.path`

The path unit watches for `/run/user/<uid>/gdm/Xauthority` and then restarts `rustdesk.service` once the user has an active X11 session.

To remove it later:

```bash
sudo ./scripts/uninstall-rustdesk-x11-refresh-workaround.sh
```

## Exact pre-update session stack restore

If you want to put the login/session stack back to the exact state from just before the `2026-03-16 09:09:48` `apt dist-upgrade`, use:

```bash
./scripts/download-preupdate-session-stack-debs.sh
./scripts/simulate-preupdate-session-stack.sh
./scripts/install-preupdate-session-stack.sh --yes
```

This restores, among other things:

- `gdm3 49.2-1ubuntu4`
- `libgdm1 49.2-1ubuntu4`
- `gir1.2-gdm-1.0 49.2-1ubuntu4`
- `gnome-settings-daemon 50~beta-0ubuntu2`
- `gnome-settings-daemon-common 50~beta-0ubuntu2`
- `xdg-desktop-portal-gnome 50~rc-0ubuntu1`
- `libgtk-4-1 4.21.5+ds-5`
- `libgtk-4-common 4.21.5+ds-5`
- `gir1.2-gtk-4.0 4.21.5+ds-5`
- the GNOME 49 shell/session packages and patched mutter packages used by this repo

This is the exact “pre-update first” rollback path, not the narrower Mesa-only or GTK-only rollback.

Expected side effects on a current GNOME 50 host:

## Snapshot rollback for all Ubuntu-archive packages changed in the last two weeks

If you want a broader rollback than the hand-picked GNOME or Mesa scripts, this repo also includes a snapshot-based script that:

- parses the last `14` days of `apt` history
- finds packages whose version changed in that window (`Upgrade` / `Downgrade`)
- keeps only packages that are currently installed and backed by the Ubuntu archive
- resolves the version available from the Ubuntu Snapshot Service at the chosen cutoff
- only targets packages whose current installed version still differs from that snapshot version

Default behavior is simulation only:

```bash
./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh
```

List the selected and skipped packages without touching apt:

```bash
./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh --list-only
```

Apply the rollback for the selected Ubuntu-archive packages:

```bash
./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh --yes
```

Important:

- This does **not** restore local `.deb` installs or third-party repository packages.
- It only operates on packages the script can confirm are backed by the Ubuntu archive.
- The default snapshot is computed as `14` days ago in UTC, but you can override it with `--snapshot-id YYYYMMDDTHHMMSSZ`.

- `gnome-shell-extension-prefs`, `gnome-initial-setup`, and `gnome-remote-desktop` may be removed if you do not separately downgrade them too.
- `ubuntu-desktop` metapackages may stop being installed. That does not by itself remove the desktop you already have.
- `libmutter-18-0` and `gir1.2-mutter-18` are replaced by the older `17` ABI line.

## Step-by-step

### 0) Sanity check

```bash
./scripts/check.sh
```

### 1) Build the `ubuntu-xorg-session` package (no sudo)

```bash
./scripts/build-ubuntu-xorg-session-deb.sh
```

### 2) Install the `ubuntu-xorg-session` package (sudo)

```bash
./scripts/install-ubuntu-xorg-session-deb.sh --yes
```

At this point, you should see “Ubuntu on Xorg” in the GDM gear menu (after logging out).

### 3) Build mutter (no sudo; runs in Docker)

```bash
./scripts/build-mutter-x11-debs.sh
```

You can override the Docker base image if needed:

```bash
UBUNTU_IMAGE=ubuntu:devel ./scripts/build-mutter-x11-debs.sh
```

The script applies the repo patch automatically when it matches.

### 4) Install rebuilt mutter packages (sudo)

```bash
./scripts/install-mutter-x11-debs.sh --yes
```

### 5) Log out and verify

- Log out
- In GDM, choose **“Ubuntu on Xorg”**
- After login:

```bash
echo "$XDG_SESSION_TYPE"      # expect: x11
loginctl show-session "$XDG_SESSION_ID" -p Type
```

## Rollback (if anything goes wrong)

1) In the GDM login screen, choose “Ubuntu” (Wayland) via the gear icon and log in.
2) Run:

```bash
./scripts/rollback.sh --yes
```

If you previously forced the GDM greeter onto Xorg, re-enable the default Wayland greeter first:

```bash
./scripts/disable-gdm-xorg-greeter.sh --yes
```

If the login screen becomes non-interactive, switch to a TTY (`Ctrl`+`Alt`+`F3`), log in, then (last resort) run:

```bash
sudo systemctl restart gdm3
```

## Important limitation

If your system has already moved to GNOME 50, this repo should be treated as documentation for the earlier successful GNOME 49 workaround, not as a supported fix for the current stack.

## Security note

Some GDM/Xsession logging can record environment variables into the journal. Avoid exporting secrets (API keys/tokens) globally in shell startup files; rotate anything that may have been logged.
