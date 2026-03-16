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

Wayland is intentionally **not disabled** during testing so you can always log in with “Ubuntu” (Wayland) if Xorg breaks.

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

Expected side effects on a current GNOME 50 host:

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

If the login screen becomes non-interactive, switch to a TTY (`Ctrl`+`Alt`+`F3`), log in, then (last resort) run:

```bash
sudo systemctl restart gdm3
```

## Important limitation

If your system has already moved to GNOME 50, this repo should be treated as documentation for the earlier successful GNOME 49 workaround, not as a supported fix for the current stack.

## Security note

Some GDM/Xsession logging can record environment variables into the journal. Avoid exporting secrets (API keys/tokens) globally in shell startup files; rotate anything that may have been logged.
