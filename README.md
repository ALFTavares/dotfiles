# dotfiles

Config files and package lists for my Arch Linux + KDE Plasma machines.

## Installing on a fresh machine

1. Install Arch with a normal user account that can use `sudo`, and make sure the machine has a network connection.
2. Switch to a text console (Ctrl+Alt+F3) **before logging into Plasma for the first time**, and log in there.
3. Clone the repo, including the nvim config submodule:

   ```sh
   sudo pacman -S --needed git
   git clone --recursive https://github.com/ALFTavares/dotfiles.git ~/dotfiles
   ```

   Use https rather than SSH, because your SSH key isn't on the new machine yet. If the repo is private, sign in first with `sudo pacman -S github-cli && gh auth login`.

4. Check what the script will do, then run it:

   ```sh
   cd ~/dotfiles
   ./install.sh --dry-run
   ./install.sh
   ```

5. Reboot.

## What `install.sh` does

- **Packages:** installs `packages/pkglist-native.txt` with pacman, builds `yay` if it's missing, then installs `packages/pkglist-aur.txt` and the Flatpaks in `packages/flatpaks.txt`.
- **Home configs:** links each package folder (`bash`, `kde`, `nvim`, ...) into your home folder. Any existing file it would replace is moved to `~/.dotfiles-backup/<date>/` first.
- **System configs:** installs the files in `system/` into `/`. Hardware-specific files, such as the fixes for the MediaTek MT7902 WiFi card, are skipped when that hardware isn't present.
- **Services:** enables NetworkManager (with iwd for WiFi), bluetooth, power-profiles-daemon, systemd-resolved, ufw and the Plasma login screen.

It's safe to run again: anything already in place is left alone.

### Options

| Option | Effect |
| --- | --- |
| `--dry-run` | Print what would happen without changing anything |
| `--skip-packages` | Only link configs and enable services |
| `--yes` | Don't ask for confirmation |

### Why a text console

The KDE config files are linked into this repo. If Plasma is running while they're being linked, it can save its default settings over them when you log out. The script warns you if Plasma is running.

## After installing

These are deliberately not in the repo, so set them up by hand:

- SSH and GPG keys
- Saved WiFi networks
- Passwords and other credentials
- Game data (Steam, Lutris, Wine prefixes)

Expect to adjust some machine-specific KDE settings, such as screen layout and panel placement.

## Editing configs

Files in your home folder are links into this repo, so editing a config edits the repo. Commit and push to keep other machines in sync.

Files in `system/etc/modprobe.d/` are copies, not links, because they're read before `/home` is mounted. After editing one, run `./install.sh --skip-packages` (or copy the file to `/etc/modprobe.d/` with `sudo cp`) and reboot.

To refresh the package lists:

```sh
pacman -Qqen > packages/pkglist-native.txt
pacman -Qqem > packages/pkglist-aur.txt
flatpak list --app --columns=application,origin > packages/flatpaks.txt
```
