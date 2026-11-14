#!/usr/bin/env bash
# Set up a fresh Arch + KDE Plasma install from these dotfiles.
#
#   ./install.sh                  install packages, link configs, enable services
#   ./install.sh --dry-run        print what would happen, change nothing
#   ./install.sh --skip-packages  only link configs and enable services
#   ./install.sh --yes            don't ask for confirmation
#
# Safe to re-run: anything already in place is left alone, and any existing
# file that would be replaced is moved to a backup first.
#
# Best run from a TTY (Ctrl+Alt+F3) before logging into Plasma for the first
# time. A running Plasma session can write its own settings over the KDE
# files in this repo when it logs out.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
HOME_BACKUP="$HOME/.dotfiles-backup/$STAMP"

DRY_RUN=0
SKIP_PACKAGES=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# Hardware-specific files in system/: only installed when this PCI device
# (vendor:device, as shown by `lspci -n`) is present.
declare -A SYSTEM_REQUIRES_PCI=(
    [etc/iwd/main.conf]="14c3:7902"              # MediaTek MT7902 WiFi
    [etc/modprobe.d/mt7921e.conf]="14c3:7902"
)

# Files in system/ that are copied instead of symlinked, and the user that
# owns the copy. Prints nothing (and fails) for files that are symlinked.
#   etc/modprobe.d/       read early in boot, before /home is mounted
#   var/lib/plasmalogin/  login screen settings; the greeter runs as the
#                         plasmalogin user, which can't read files in $HOME
copy_owner() {
    case "$1" in
        etc/modprobe.d/*) echo root ;;
        var/lib/plasmalogin/*) echo plasmalogin ;;
        *) return 1 ;;
    esac
}

# Services enabled on the original machine.
SERVICES=(NetworkManager iwd bluetooth power-profiles-daemon systemd-resolved ufw)
DISPLAY_MANAGER=plasmalogin

# ---------------------------------------------------------------------------

bold() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }

run() {
    printf '    $ %s\n' "$*"
    if (( ! DRY_RUN )); then "$@"; fi
}

same_file() {
    [[ -e "$1" && -e "$2" && "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]
}

# link_home <source in repo> <target under $HOME>
link_home() {
    local src="$1" target="$2"
    if same_file "$src" "$target"; then
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        local backup="$HOME_BACKUP/${target#"$HOME"/}"
        note "backing up ${target/#$HOME/\~}"
        run mkdir -p "$(dirname "$backup")"
        run mv "$target" "$backup"
    fi
    run mkdir -p "$(dirname "$target")"
    run ln -s "$src" "$target"
}

# install_system <source in repo> <target under />
install_system() {
    local src="$1" target="$2" rel="$3" owner=""
    if owner="$(copy_owner "$rel")"; then
        if ! id "$owner" >/dev/null 2>&1; then
            note "skipping $target (user $owner doesn't exist)"
            return
        fi
        # sudo, because the target's directory may not be readable by us.
        if sudo test -f "$target" -a ! -L "$target" && sudo cmp -s "$src" "$target"; then
            return
        fi
    elif same_file "$src" "$target"; then
        return
    fi
    if [[ -e "$target" || -L "$target" ]] || { [[ -n "$owner" ]] && sudo test -e "$target"; }; then
        note "backing up $target to $target.bak-$STAMP"
        run sudo mv "$target" "$target.bak-$STAMP"
    fi
    if [[ -n "$owner" ]]; then
        # Missing parent directories are created owned by $owner, e.g.
        # /var/lib/plasmalogin/.config. Ones that already exist are untouched.
        local dir="$(dirname "$target")" missing=()
        while ! sudo test -d "$dir"; do
            missing=("$dir" "${missing[@]}")
            dir="$(dirname "$dir")"
        done
        for dir in "${missing[@]}"; do
            run sudo install -d -o "$owner" -g "$owner" "$dir"
        done
        run sudo install -o "$owner" -g "$owner" -m 644 "$src" "$target"
    else
        run sudo mkdir -p "$(dirname "$target")"
        run sudo ln -s "$src" "$target"
    fi
}

# ---------------------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root. It uses sudo where needed." >&2
    exit 1
fi
if ! command -v pacman >/dev/null; then
    echo "This script is for Arch Linux (pacman not found)." >&2
    exit 1
fi

if (( DRY_RUN )); then
    echo "Dry run: nothing will be changed."
elif (( ! ASSUME_YES )); then
    if pgrep -x plasmashell >/dev/null; then
        echo "Warning: Plasma is running. It may overwrite the KDE files in this"
        echo "repo when you log out. Running from a TTY before first login is safer."
    fi
    read -rp "Set up this machine from $DOTFILES? [y/N] " answer
    [[ "$answer" == [yY]* ]] || exit 1
fi

bold "Fetching the nvim submodule"
run git -C "$DOTFILES" submodule update --init --recursive

if (( ! SKIP_PACKAGES )); then
    bold "Installing native packages"
    mapfile -t native < <(grep -v '^\s*$' "$DOTFILES/packages/pkglist-native.txt")
    # Also needed by this script and the config, but only installed as
    # dependencies on the original machine.
    native+=(flatpak networkmanager pciutils)
    run sudo pacman -Syu --needed --noconfirm "${native[@]}"

    bold "Installing AUR packages"
    if ! command -v yay >/dev/null; then
        note "yay not found, building it from the AUR"
        build_dir="$(mktemp -d)"
        run git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
        if (( ! DRY_RUN )); then
            (cd "$build_dir/yay" && makepkg -si --noconfirm)
        else
            note "$ (cd $build_dir/yay && makepkg -si --noconfirm)"
        fi
        rm -rf "$build_dir"
    fi
    # yay is handled above; -debug packages aren't in the AUR.
    mapfile -t aur < <(grep -v -e '^\s*$' -e '-debug$' -e '^yay$' "$DOTFILES/packages/pkglist-aur.txt")
    if (( ${#aur[@]} )); then
        run yay -S --needed --noconfirm "${aur[@]}"
    fi

    bold "Installing Flatpak apps"
    run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    while IFS=$'\t' read -r app remote; do
        [[ -n "$app" ]] || continue
        run sudo flatpak install -y --noninteractive "${remote:-flathub}" "$app"
    done < "$DOTFILES/packages/flatpaks.txt"
fi

bold "Linking configs into $HOME"
for pkg_dir in "$DOTFILES"/*/; do
    pkg="$(basename "$pkg_dir")"
    case "$pkg" in
        packages|system) continue ;;
        nvim)
            # The whole nvim config directory is one link.
            link_home "$DOTFILES/nvim/.config/nvim" "$HOME/.config/nvim"
            continue
            ;;
    esac
    while IFS= read -r -d '' src; do
        link_home "$src" "$HOME/${src#"$pkg_dir"}"
    done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type l \) -print0)
done

bold "Installing system configs into /"
pci_ids="$(lspci -n 2>/dev/null || true)"
while IFS= read -r -d '' src; do
    rel="${src#"$DOTFILES/system/"}"
    need="${SYSTEM_REQUIRES_PCI[$rel]:-}"
    if [[ -n "$need" ]] && ! grep -qi " $need" <<<"$pci_ids"; then
        note "skipping /$rel (device $need not present)"
        continue
    fi
    install_system "$src" "/$rel" "$rel"
done < <(find "$DOTFILES/system" -type f -print0)

bold "Enabling services"
for svc in "${SERVICES[@]}"; do
    if systemctl cat "$svc.service" >/dev/null 2>&1; then
        if ! systemctl is-enabled -q "$svc.service" 2>/dev/null; then
            run sudo systemctl enable "$svc.service"
        fi
    else
        note "skipping $svc (not installed)"
    fi
done
# iwd replaces wpa_supplicant as NetworkManager's WiFi backend.
if systemctl is-enabled -q wpa_supplicant.service 2>/dev/null; then
    run sudo systemctl disable wpa_supplicant.service
fi
current_dm="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
if [[ -z "$current_dm" ]]; then
    run sudo systemctl enable "$DISPLAY_MANAGER.service"
elif [[ "$(basename "$current_dm")" != "$DISPLAY_MANAGER.service" ]]; then
    note "display manager is $(basename "$current_dm"), not $DISPLAY_MANAGER; leaving it."
    note "to switch: sudo systemctl enable -f $DISPLAY_MANAGER.service"
fi
# Use systemd-resolved for DNS.
if [[ "$(readlink /etc/resolv.conf 2>/dev/null)" != /run/systemd/resolve/stub-resolv.conf ]]; then
    run sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

bold "Done"
if [[ -d "$HOME_BACKUP" ]]; then
    note "replaced files were backed up to ${HOME_BACKUP/#$HOME/\~}"
fi
note "Reboot to start the services and load the new settings."
note "Not included (by design): SSH/GPG keys, saved WiFi networks, credentials."
