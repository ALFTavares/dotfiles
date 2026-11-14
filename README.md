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

## What `install.sh` changes

The script works in five steps. It's safe to run again: anything already in place is left alone, and `--dry-run` prints every command without running it.

### 1. Packages

| Source | Installed with |
| --- | --- |
| `packages/pkglist-native.txt` | `pacman`, plus `flatpak`, `networkmanager` and `pciutils`, which the setup needs |
| `packages/pkglist-aur.txt` | `yay`, which is built from the AUR first if it's missing. `-debug` packages are skipped. |
| `packages/flatpaks.txt` | `flatpak`, system-wide, after adding the Flathub remote |

### 2. Configs in your home folder

Each file in these folders is linked into your home folder at the same path. For example, `kde/.config/kwinrc` becomes `~/.config/kwinrc`. Any file already there is moved to `~/.dotfiles-backup/<date>/` first.

| Folder | What it configures |
| --- | --- |
| `bash` | `~/.bashrc`, `~/.bash_profile` |
| `claude` | Claude Code settings (`~/.claude/settings.json`) |
| `gtk` | GTK 2/3/4 theme settings, so GTK apps match Plasma |
| `kde` | Plasma, KWin, window rules, shortcuts, KRunner, Dolphin, power management, screen locker, KWallet, default apps |
| `konsole` | Konsole profile and settings (Flatpak version) |
| `lutris` | Lutris settings |
| `npm` | `~/.npmrc` |
| `nvim` | Neovim config. The whole `~/.config/nvim` folder is one link to the [nvim repo](https://github.com/ALFTavares/nvim) submodule. |
| `pupgui` | ProtonUp-Qt settings |

### 3. System configs in `/etc` and `/var/lib`

| File | Setting | Why | Installed when |
| --- | --- | --- | --- |
| `/etc/default/grub` | `GRUB_TIMEOUT=1` | Show the boot menu for 1 second instead of 5. Otherwise Arch's default file. `/boot/grub/grub.cfg` is rebuilt with `grub-mkconfig` whenever this file is newer than it. | Always (linked) |
| `/etc/NetworkManager/conf.d/wifi_backend.conf` | `wifi.backend=iwd` | Use iwd instead of wpa_supplicant for WiFi | Always (linked) |
| `/etc/iwd/main.conf` | `[DriverQuirks]`<br>`PowerSaveDisable=mt7921e` | Keep WiFi power saving off, since it can cause dropouts and lag | MT7902 card present (linked) |
| `/etc/modprobe.d/mt7921e.conf` | `options mt7921e disable_aspm=1` | Turn off PCIe power saving (ASPM) on the WiFi card. The BIOS has no setting for this. | MT7902 card present (copied) |
| `/var/lib/plasmalogin/.config/kcminputrc` | `[Keyboard]`<br>`NumLock=0` | Turn NumLock on at the login screen. Your own `kcminputrc` (in the `kde` package) turns it on once you're logged in. | `plasmalogin` user exists (copied, owned by `plasmalogin`) |

The MT7902 is the MediaTek WiFi card in the desktop (PCI ID `14c3:7902`, `mt7921e` driver). On other hardware these two files are skipped. Any existing file is renamed to `<file>.bak-<date>` before being replaced.

### 4. Services

| Service | Purpose |
| --- | --- |
| `NetworkManager` | Network connections |
| `iwd` | WiFi, used by NetworkManager |
| `bluetooth` | Bluetooth |
| `power-profiles-daemon` | Power profiles in Plasma (performance, balanced, power saver) |
| `systemd-resolved` | DNS |
| `ufw` | Firewall |
| `plasmalogin` | Plasma login screen. Only enabled if no other login screen is set up; otherwise the script prints how to switch. |

The script also:

- disables `wpa_supplicant` if it's enabled, because iwd replaces it
- links `/etc/resolv.conf` to `/run/systemd/resolve/stub-resolv.conf`, so DNS goes through systemd-resolved

Services are enabled but not started, so the network doesn't drop mid-install. They start on the next boot.

### 5. Checking it worked

After rebooting:

```sh
systemctl is-active NetworkManager iwd bluetooth   # all "active"
readlink /etc/resolv.conf                          # /run/systemd/resolve/stub-resolv.conf
```

On a machine with the MT7902 card:

```sh
iw dev wlan0 get power_save                        # Power save: off
cat /sys/module/mt7921e/parameters/disable_aspm    # Y
```

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

Some files in `system/` are copies, not links, so they need installing again after you edit them: run `./install.sh --skip-packages` and reboot.

- `system/etc/modprobe.d/`: read before `/home` is mounted.
- `system/var/lib/plasmalogin/`: the login screen runs as the `plasmalogin` user, which can't read files in your home folder. The copies are owned by `plasmalogin`.

To refresh the package lists:

```sh
pacman -Qqen > packages/pkglist-native.txt
pacman -Qqem > packages/pkglist-aur.txt
flatpak list --app --columns=application,origin > packages/flatpaks.txt
```
