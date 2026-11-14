# Global instructions

These apply to every Claude Code session on this machine. Project-specific guidance belongs in that project's own `CLAUDE.md`.

## Machine

- Arch Linux with KDE Plasma (Wayland), shell is bash, editor is Neovim.
- Install software with `pacman` for official packages, an AUR helper for AUR packages, and Flatpak for desktop apps. Don't use `pip install` or `npm install -g` system-wide; prefer distro packages, `pipx`, or a project-local environment.
- Personal config lives in `~/dotfiles` (Stow-style packages symlinked into `$HOME`). Many files in `~` and `~/.config` are symlinks into that repo, so editing them edits the repo. When changing config, check whether the file is tracked there and keep the change in the repo.

## How to work with me

- When I ask what something would do, or for a plan, explain it and don't implement anything until I say to go ahead.
- Don't commit, push, or open PRs unless I ask.
- Ask before running anything with `sudo`, or anything that changes system state outside the current project (services, packages, files under `/etc`).
- Keep answers concise. Lead with the result, then the details that matter.
- Never commit secrets, credentials, keys, or tokens.
