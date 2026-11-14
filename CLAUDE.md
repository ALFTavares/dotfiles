# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for an Arch Linux + KDE Plasma machine. There is no build, lint, or test tooling — the repo is just config files plus package lists.

## Layout (GNU Stow-style packages)

Each top-level directory is a "package" whose internal path mirrors `$HOME`. For example, `bash/.bashrc` maps to `~/.bashrc`, and `kde/.config/kwinrc` maps to `~/.config/kwinrc`. The home directory holds symlinks back into this repo (e.g. `~/.bashrc -> dotfiles/bash/.bashrc`), so editing a file here edits the live config. `install.sh` sets up a fresh machine: it installs the package lists, links every package into `$HOME` (backing up anything it replaces), installs `system/`, and enables services. It is safe to re-run, and `./install.sh --dry-run` shows what it would do. Keep new files in the same `<package>/<path-relative-to-home>` shape.

Packages: `bash`, `claude` (`~/.claude/settings.json`), `gtk`, `kde` (Plasma, KWin, Dolphin, shortcuts, etc.), `konsole` (Flatpak path under `.var/app/`), `lutris`, `npm`, `nvim` (`~/.config/nvim`; a git submodule pointing to the separate `ALFTavares/nvim` repo on its `main` branch, so commit nvim changes there and then bump the submodule pointer here), `pupgui`.

The exception is `system/`, which mirrors `/` instead of `$HOME` (e.g. `system/etc/iwd/main.conf` maps to `/etc/iwd/main.conf`). These files are symlinked into place as root, e.g. `sudo ln -s ~/dotfiles/system/etc/iwd/main.conf /etc/iwd/main.conf`. Some files must be copied instead of symlinked, so after editing them here, copy them again (`./install.sh --skip-packages` does this): files read early in boot, before `/home` is mounted (such as `etc/modprobe.d/`), and the Plasma Login Manager greeter's settings under `var/lib/plasmalogin/`, which must be owned by the `plasmalogin` user because the greeter can't read files in `$HOME`. It currently holds the GRUB settings (`etc/default/grub`, 1-second menu timeout; `install.sh` reruns `grub-mkconfig` when it's newer than `/boot/grub/grub.cfg`), the NetworkManager setting that makes iwd the WiFi backend, the WiFi fixes for the MT7902 card (iwd power save off, PCIe ASPM off via a modprobe option), and NumLock on at the login screen. Hardware-specific files are listed in `SYSTEM_REQUIRES_PCI` in `install.sh`, so they're only installed when that device is present, and copied paths are listed in `copy_owner` along with the user that owns the copy. Update both when adding files to `system/`.

`packages/` holds package inventories for rebuilding the system:
- `pkglist-native.txt`: native pacman packages
- `pkglist-aur.txt`: AUR packages
- `flatpaks.txt`: Flatpak apps, tab-separated as `<app-id>\t<remote>`

Regenerate these lists from the system rather than hand-editing, e.g. `pacman -Qqen`, `pacman -Qqem`, and `flatpak list --app --columns=application,origin`.

## Things to watch

- `.gitignore` excludes secrets and machine state (`.claude.json`, credentials, `.ssh/`, `.gnupg/`, keys, NetworkManager connections, Steam/Wine/Proton/Lutris game data). Check it before adding new files, and never commit credentials. `lutris/.local/share/lutris/lutris.conf` is tracked even though the `.local/share/lutris/` ignore rule exists, so adding files under that path would need `git add -f`.
- KDE config files (`kdeglobals`, `kwinrc`, `plasma-org.kde.plasma.desktop-appletsrc`, etc.) are rewritten by Plasma itself. Expect noisy diffs, and prefer editing them while the relevant KDE component isn't running.
