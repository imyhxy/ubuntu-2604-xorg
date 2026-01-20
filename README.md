# Enable “Ubuntu on Xorg” (X11) on Ubuntu 26.04 — and fix the GNOME 49 login loop

Ubuntu 26.04 (Resolute / GNOME 49 / mutter 49) can land in an awkward state where:

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

### Part B — Fix the actual login loop (mutter is built without X11)

When selecting **“Ubuntu on Xorg”**:

- First attempt: black screen → returns to login screen
- Second attempt: password entry greys out and hangs; often needs a TTY + `systemctl restart gdm3`
- Journal shows GNOME Shell failing to take logind control (`TakeControl … EBUSY`)

Root cause: on Ubuntu 26.04 (resolute), the distro `mutter` build has the **X11 backend disabled** (Meson `x11=false`).

In an X11 session, rootless Xorg already owns logind control. GNOME Shell (without a real X11 compositor backend available) ends up on the wrong code path and tries to take control again → `EBUSY` → session aborts.

Fix: rebuild `mutter` with `-Dx11=true` and install the rebuilt runtime packages.

## What this repo provides

- A reproducible builder for **`ubuntu-xorg-session`** (adds the session entry + missing systemd user units).
- A Docker-based builder for **mutter with X11 enabled** (`-Dx11=true`) and an installer for the rebuilt `.deb`s.
- A rollback script that removes the local session package and downgrades mutter back to the Ubuntu repo version.

## Requirements

- Ubuntu 26.04
- `docker` working for your user (`docker ps` works)
- `sudo` access (only used by install/rollback steps)

Wayland is intentionally **not disabled** during testing so you can always log in with “Ubuntu” (Wayland) if Xorg breaks.

## Quick start

```bash
./scripts/run-all.sh --yes
```

Then log out and pick **“Ubuntu on Xorg”** in GDM.

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

### 3) Build mutter with X11 enabled (no sudo; runs in Docker)

```bash
./scripts/build-mutter-x11-debs.sh
```

You can override the Docker base image if needed:

```bash
UBUNTU_IMAGE=ubuntu:devel ./scripts/build-mutter-x11-debs.sh
```

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

## Security note

Some GDM/Xsession logging can record environment variables into the journal. Avoid exporting secrets (API keys/tokens) globally in shell startup files; rotate anything that may have been logged.
