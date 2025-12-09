# isolated-desktops

A modular system for installing, isolating, and managing multiple Linux desktop environments using fake HOME directories, launch scripts, and display manager sessions.

This project allows you to install and run multiple DE and WM setups such as Omarchy, JaKooLit Hyprland, DWM-Titus, ML4W, and others without mixing configurations.

## Example fake HOME folders

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

The script setup_desktops.sh creates the fake HOME, clones the repo, runs the installer, and logs everything.

## Automatic launch scripts

Generated start scripts:

    /usr/local/bin/start-<name>.sh

## Display manager integration

Creates sessions in:

    /usr/share/xsessions
    /usr/share/wayland-sessions

## Dotfiles support

Dotfiles per desktop:

    ~/isolated-desktops/desktops/<name>/

## Developer tools

- Open real or fake HOME in VS Code or VSCodium
- Open desktop-specific dotfiles
- Snapshot dotfiles to GitHub or GitLab

---

# Project Structure

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

## Clone and prepare

    git clone https://github.com/Vguver/isolated-desktops.git
    cd isolated-desktops
    chmod +x install.sh
    chmod +x scripts/*.sh

## Install the idtool wrapper

    mkdir -p ~/.local/bin
    cat > ~/.local/bin/idtool << 'EOF'
    #!/usr/bin/env bash
    "$HOME/isolated-desktops/install.sh" "$@"
    EOF
    chmod +x ~/.local/bin/idtool

## Run

    idtool

---

# Usage (idtool menu)

    1) Install an isolated desktop environment
    2) Create launch script (start-<name>.sh)
    3) Create display manager session (.desktop)
    4) Full interactive flow
    5) Dev tools (VS Code / VSCodium)
    6) Git snapshot dotfiles
    0) Exit

---

# Installer logs

Logs located in:

    ~/.<name>/logs/

Example:

    ~/.omarchy/logs/

---

# Dotfiles organization

Locations:

    ~/isolated-desktops/desktops/<name>/

Link dotfiles using:

    ./scripts/dotfiles-link.sh prepare <name>
    ./scripts/dotfiles-link.sh link-config <name>

---

# Developer tools

## VS Code / VSCodium

    ./scripts/dev-open.sh real-home
    ./scripts/dev-open.sh fake-home omarchy
    ./scripts/dev-open.sh dotfiles jakoolit

## Git snapshots

    ./scripts/dev-sync.sh snapshot omarchy git@github.com:User/omarchy-config.git main

---

# Requirements

- bash
- git
- curl

Optional:

- pacman
- VS Code or VSCodium
- Display manager (SDDM, LightDM, GDM)

---

# About this project

I am new to Linux, and I have not worked with PC customization since I was a kid. Thanks to people in the community, especially creators like Chris Titus, I rediscovered my interest in experimenting with computers.

While trying different Linux desktops, I noticed that many are designed for clean installations. When multiple desktops are installed on the same system, their configuration files mix together and break the intended experience.

I did not want to use virtual machines. I wanted a cleaner and more realistic way to learn how others configure their desktops without affecting my main system.

This project allows me to safely install and test different desktops, compare setups, experiment, and slowly build what will become my final configuration. This is only a hobby, but I hope it helps others too.

---

# License

This project is released under the MIT License. See the LICENSE file for details.
