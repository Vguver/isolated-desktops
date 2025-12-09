# isolated-desktops

A modular system for installing, isolating, and managing multiple Linux desktop environments using fake HOME directories, launch scripts, and display manager sessions.

This project allows you to install and run multiple DE and WM setups such as Omarchy, JaKooLit Hyprland, DWM-Titus, ML4W, and others without mixing configurations. Each desktop environment runs with its own isolated structure:

Example fake HOME folders:
  ~/.omarchy/
  ~/.jakoolit/
  ~/.dwm-titus/
  ~/.ml4w-starter/

Each environment contains its own .config, .local, .cache, logs, and dotfiles.

---

# Features

## Complete desktop isolation
Each desktop environment has its own fake HOME directory.

## Automatic installers
setup_desktops.sh creates the fake HOME, clones the repository, runs its installer, and logs everything.

## Automatic launch scripts
desktop-launch.sh generates start scripts such as:
  /usr/local/bin/start-<name>.sh

Each script launches the desktop using its isolated HOME.

## Display manager integration
desktop-sessions.sh generates sessions for:
  /usr/share/xsessions
  /usr/share/wayland-sessions

## Dotfiles support
Each desktop has its own dotfiles directory:
  ~/isolated-desktops/desktops/<name>/

## Developer tools
- Open real or fake HOME in VS Code or VSCodium  
- Open dotfiles directly  
- Snapshot dotfiles to GitHub or GitLab  

---

# Project Structure

Folder layout:
  isolated-desktops/
    install.sh
    scripts/
      repos-desktops.sh
      setup_desktops.sh
      dotfiles-link.sh
      desktop-launch.sh
      desktop-sessions.sh
      dev-open.sh
      dev-sync.sh
    README.md

---

# Installation

Run the following after cloning:

  git clone https://github.com/Vguver/isolated-desktops.git
  cd isolated-desktops
  chmod +x install.sh
  chmod +x scripts/*.sh

Install the idtool helper:

  mkdir -p ~/.local/bin
  cat > ~/.local/
