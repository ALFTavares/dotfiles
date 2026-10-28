# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for an Arch Linux + KDE Plasma machine. There is no build, lint, or test tooling — the repo is just config files plus package lists.

## Layout (GNU Stow-style packages)

Each top-level directory is a "package" whose internal path mirrors `$HOME`. For example, `bash/.bashrc` maps to `~/.bashrc`, and `kde/.config/kwinrc` maps to `~/.config/kwinrc`. The home directory holds symlinks back into this repo (e.g. `~/.bashrc -> dotfiles/bash/.bashrc`), so editing a file here edits the live config. No stow script or install script is committed. Keep new files in the same `<package>/<path-relative-to-home>` shape.

Packages: `bash`, `claude` (`~/.claude/settings.json`), `gtk`, `kde` (Plasma, KWin, Dolphin, shortcuts, etc.), `konsole` (Flatpak path under `.var/app/`), `lutris`, `npm`, `pupgui`.

`packages/` holds package inventories for rebuilding the system:
- `pkglist-native.txt`: native pacman packages
- `pkglist-aur.txt`: AUR packages
- `flatpaks.txt`: Flatpak apps, tab-separated as `<app-id>\t<remote>`

Regenerate these lists from the system rather than hand-editing, e.g. `pacman -Qqen`, `pacman -Qqem`, and `flatpak list --app --columns=application,origin`.

## Things to watch

- `.gitignore` excludes secrets and machine state (`.claude.json`, credentials, `.ssh/`, `.gnupg/`, keys, NetworkManager connections, Steam/Wine/Proton/Lutris game data). Check it before adding new files, and never commit credentials. `lutris/.local/share/lutris/lutris.conf` is tracked even though the `.local/share/lutris/` ignore rule exists, so adding files under that path would need `git add -f`.
- KDE config files (`kdeglobals`, `kwinrc`, `plasma-org.kde.plasma.desktop-appletsrc`, etc.) are rewritten by Plasma itself. Expect noisy diffs, and prefer editing them while the relevant KDE component isn't running.
