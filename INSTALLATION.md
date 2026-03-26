# Installation Guide - Isolated Desktops

## 📋 Prerequisites

### Required
- **Bash** 4.0 or higher
- **Git** for cloning repositories
- **curl** for downloading installers

### Optional but Recommended
- **VS Code** or **VSCodium** for development tools
- **fzf** for interactive selection
- **pacman** (Arch-based) for package tracking

## 🚀 Quick Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Vguver/isolated-desktops.git
cd isolated-desktops
```

### 2. Make Scripts Executable

```bash
chmod +x install.sh
chmod +x scripts/*.sh
```

### 3. Install the idtool Wrapper (Optional but Recommended)

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/idtool << 'EOF'
#!/usr/bin/env bash
"$HOME/isolated-desktops/install.sh" "$@"
EOF
chmod +x ~/.local/bin/idtool
```

Make sure `~/.local/bin` is in your PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Run the Interactive Menu

```bash
./install.sh
# or if you installed idtool:
idtool
```

## 📖 Step-by-Step Usage

### Option 1: Use Quick Setup (Easiest)

From the main menu, select option **21** (Quick Setup). This will guide you through:
1. Installing a desktop environment
2. Adopting existing configuration
3. Creating a launch script
4. Creating a display manager session

### Option 2: Manual Step-by-Step

#### Step 1: Install a Desktop

```bash
./install.sh
# Choose: 1) Install isolated desktop environment
# Select desktop: omarchy (or another)
```

Or via command line:
```bash
./scripts/setup_desktops.sh create omarchy
```

#### Step 2: Manage Dotfiles (Optional but Recommended)

After installation, adopt the generated config:

```bash
./scripts/dotfiles-link.sh adopt-config omarchy
```

This moves `~/.omarchy/.config/` to `~/isolated-desktops/desktops/omarchy/.config/` and creates a symlink.

#### Step 3: Create Launch Script

```bash
./scripts/desktop-launch.sh create omarchy Hyprland
```

This creates `/usr/local/bin/start-omarchy.sh` (requires sudo).

#### Step 4: Create Display Manager Session

```bash
./scripts/desktop-sessions.sh create-interactive
# Select: omarchy
# Choose: Wayland (or X11, or both)
```

This creates session files in `/usr/share/wayland-sessions/` (requires sudo).

#### Step 5: Restart and Login

1. Restart your display manager:
   ```bash
   sudo systemctl restart sddm  # or gdm, lightdm, etc.
   ```
   Or simply reboot.

2. At the login screen, select "omarchy (Isolated)" from the session menu

3. Log in with your credentials

## 🎯 Testing Before Production

### Test from TTY

Before setting up display manager integration, you can test from a TTY:

1. Press `Ctrl+Alt+F2` to switch to TTY2
2. Login with your user
3. Run:
   ```bash
   start-omarchy.sh
   ```

If it works, you can proceed with display manager setup.

## 🔧 Common Configurations

### Environment Variables

You can customize behavior with environment variables:

```bash
# Fake HOME prefix (default: $HOME/.)
export CONFIG_BASE_PREFIX="$HOME/.desktops/"

# Dotfiles location (default: $HOME/isolated-desktops/desktops)
export DOTFILES_ROOT="$HOME/my-dotfiles"

# Launch scripts location (default: /usr/local/bin)
export START_SCRIPTS_DIR="/usr/local/bin"
```

### Adding Custom Desktop Repositories

```bash
./scripts/repos-desktops.sh add my-desktop https://github.com/user/my-desktop.git
```

## 📁 Directory Structure After Installation

```
~/
├── .omarchy/                          # Fake HOME for omarchy
│   ├── .config/                       # Symlink to dotfiles
│   ├── .local/
│   ├── .cache/
│   ├── .repo/                         # Cloned repository
│   └── logs/                          # Installation logs
│
├── .logs-desktops/                    # Global logs
│   └── omarchy/
│
└── isolated-desktops/                 # Project root
    ├── install.sh                     # Main menu
    ├── scripts/                       # All scripts
    └── desktops/                      # Dotfiles per desktop
        └── omarchy/
            └── .config/               # Actual dotfiles location
```

## 🛠️ Development Workflow

### 1. Open in Editor

```bash
./scripts/dev-open.sh dotfiles omarchy
```

### 2. Make Changes

Edit files in VS Code/VSCodium

### 3. Create Git Snapshot

```bash
./scripts/dev-sync.sh snapshot omarchy git@github.com:user/omarchy-dots.git
```

## 🆘 Troubleshooting

### Launch Script Not Working

**Issue:** Permission denied or script not found

**Solution:**
```bash
# Check if script exists
ls -l /usr/local/bin/start-omarchy.sh

# If missing, recreate it
./scripts/desktop-launch.sh create omarchy Hyprland
```

### Display Manager Session Not Showing

**Issue:** Desktop not appearing in session menu

**Solutions:**

1. Check session file exists:
   ```bash
   ls -l /usr/share/wayland-sessions/omarchy-isolated.desktop
   ```

2. Restart display manager:
   ```bash
   sudo systemctl restart sddm  # or your DM
   ```

3. Check logs:
   ```bash
   cat ~/.omarchy/logs/startup-*.log
   ```

### Fake HOME Not Found

**Issue:** "Environment not found" error

**Solution:**
```bash
# Reinstall the desktop
./scripts/setup_desktops.sh create omarchy
```

### Dotfiles Not Linking

**Issue:** Symlink errors

**Solution:**
```bash
# Check status
./scripts/dotfiles-link.sh status omarchy

# If needed, adopt existing config
./scripts/dotfiles-link.sh adopt-config omarchy
```

## 🔄 Updating

To update the project:

```bash
cd ~/isolated-desktops
git pull origin main
chmod +x install.sh scripts/*.sh
```

## 🗑️ Uninstalling

### Remove a Single Desktop

```bash
./scripts/setup_desktops.sh remove omarchy
sudo rm /usr/local/bin/start-omarchy.sh
sudo rm /usr/share/wayland-sessions/omarchy-isolated.desktop
```

### Complete Removal

```bash
# Remove all fake HOMEs (be careful!)
rm -rf ~/.*omarchy ~/..*jakoolit  # etc.

# Remove project
rm -rf ~/isolated-desktops

# Remove idtool
rm ~/.local/bin/idtool

# Remove logs
rm -rf ~/.logs-desktops
```

## 📚 Next Steps

- Read [README.md](README.md) for project overview
- Check [examples/](examples/) for configuration examples
- Join discussions on GitHub Issues
- Contribute improvements via Pull Requests

## 💡 Tips

1. **Start Small:** Begin with one desktop and test thoroughly
2. **Backup First:** Before adopting configs, backup your current setup
3. **Use TTY Testing:** Always test from TTY before display manager integration
4. **Version Control:** Use Git snapshots to track your dotfiles changes
5. **Read Logs:** Installation logs in `~/.<n>/logs/` are very helpful

## 🤝 Getting Help

- Check logs: `~/.<desktop-name>/logs/`
- Run system info: `./install.sh` → option 22
- Open an issue: https://github.com/Vguver/isolated-desktops/issues
- Include:
  - Your distro and version
  - Desktop environment you're installing
  - Error messages from logs
  - Output of `./install.sh` → System Information
