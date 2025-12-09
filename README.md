# isolated-desktops

A modular system for installing, isolating, and managing multiple Linux desktop environments using fake HOME directories, launch scripts, and display manager sessions.

This project allows you to install and run multiple DE and WM setups such as Omarchy, JaKooLit Hyprland, DWM-Titus, ML4W, and others without mixing configurations. Each desktop environment runs with its own isolated structure:

Paths example:
  ~/.omarchy/
  ~/.jakoolit/
  ~/.dwm-titus/
  ~/.ml4w-starter/

Each environment contains its own .config, .local, .cache, logs, and dotfiles.

---

# Features

## Complete desktop isolation
Each desktop environment uses a separate fake HOME directory.

## Automatic installers
setup_desktops.sh creates the fake HOME, clones the repo, runs its installer, and logs everything.

## Automatic launch scripts
desktop-launch.sh generates:
  /usr/local/bin/start-<name>.sh

Each script launches the desktop using its isolated HOME.

## Display manager integration
desktop-sessions.sh generates sessions for:
  /usr/share/xsessions
  /usr/share/wayland-sessions

## Dotfiles support
Each desktop has a dedicated dotfiles directory:
  ~/isolated-desktops/desktops/<name>/

## Developer tools
- Open real or fake HOME in VS Code or VSCodium  
- Open dotfiles directly  
- Snapshot dotfiles to GitHub or GitLab  

---

# Project Structure

Structure example:
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
  cat > ~/.local/bin/idtool << 'EOF'
  #!/usr/bin/env bash
  "$HOME/isolated-desktops/install.sh" "$@"
  EOF
  chmod +x ~/.local/bin/idtool

Run the tool:

  idtool

---

# Usage (idtool)

Menu options:

  1) Install an isolated desktop environment
  2) Create launch script (start-<name>.sh)
  3) Create display manager session (.desktop)
  4) Full interactive flow
  5) Dev tools (VS Code / VSCodium)
  6) Git snapshot dotfiles
  0) Exit

---

# Installer logs

Logs for each desktop environment are located in:

  ~/.<name>/logs/

Example:

  ~/.omarchy/logs/

---

# Dotfiles organization

Each desktop stores its dotfiles in:

  ~/isolated-desktops/desktops/<name>/

Link configuration directories:

  ./scripts/dotfiles-link.sh prepare <name>
  ./scripts/dotfiles-link.sh link-config <name>

---

# Developer tools

Open environments in the editor:

  ./scripts/dev-open.sh real-home
  ./scripts/dev-open.sh fake-home omarchy
  ./scripts/dev-open.sh dotfiles jakoolit

Snapshot to GitHub or GitLab:

  ./scripts/dev-sync.sh snapshot omarchy git@github.com:User/omarchy-config.git main

---

# Requirements

- bash  
- git  
- curl  
Optional:
- pacman  
- VS Code or VSCodium  
- A display manager such as SDDM, LightDM, or GDM  

---

# About this project

I am new to Linux, and I have not worked with PC customization since I was a kid. Thanks to people in the community, especially creators like Chris Titus, I rediscovered my interest in experimenting with computers.

While trying different Linux desktops, I noticed that many are designed for clean installations. When multiple desktops are installed on the same system, their configuration files mix together and break the intended experience. Many times I had to reinstall my whole system just to test another setup.

I did not want to use virtual machines, and I wanted a cleaner and more realistic way to learn how others configure their desktops without affecting my main system.

This project allows me to safely install and test different desktops, compare setups, experiment, and slowly build what will become my final configuration. This is only a hobby, but I hope others find it useful too.

---

# License

This project is released under the MIT License. See the LICENSE file for details.
