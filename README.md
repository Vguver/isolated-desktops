
Isolated-Desktops
A modular system for installing, isolating, and managing multiple desktop environments using fake HOME directories, custom launch scripts, and display manager session entries.
This project allows you to install and run multiple DE/WM setups (e.g., Omarchy, JaKooLit, DWM-Titus, ML4W, etc.) without mixing configurations, thanks to a per-desktop isolated environment:
~/.omarchy/
~/.jakoolit/
~/.dwm-titus/
~/.ml4w-starter/
...
Each environment keeps its own:
•	.config/
•	.local/share/
•	.cache/
•	.local/state/
•	Installer logs
•	Dotfiles directory
________________________________________
✨ Features
✔ Full desktop isolation
Each WM/DE gets its own fake HOME, preventing config conflicts.
✔ Automatic installers
setup_desktops.sh clones the repo, runs its installer, and logs all file changes.
✔ Automatic launch scripts
desktop-launch.sh creates executable scripts like:
/usr/local/bin/start-omarchy.sh
/usr/local/bin/start-jakoolit.sh
Each sets the correct fake HOME before launching the desktop.
✔ Display manager session integration
desktop-sessions.sh generates .desktop files for:
•	/usr/share/xsessions
•	/usr/share/wayland-sessions
✔ Dotfiles support
Each desktop has its own folder under:
~/isolated-desktops/desktops/<name>
✔ Developer tools integration
•	Open real/fake HOME or dotfiles in VS Code/VSCodium.
•	Snapshot dotfiles into GitHub/GitLab repos.
✔ Fully modular
All components live under /scripts and are loaded on demand.
________________________________________
📦 Project Structure
isolated-desktops/
├── install.sh
├── scripts/
│   ├── repos-desktops.sh       # REPOS registry
│   ├── setup_desktops.sh       # Fake HOME + installer runner
│   ├── dotfiles-link.sh        # Dotfiles structure & linking
│   ├── desktop-launch.sh       # start-<name>.sh generator
│   ├── desktop-sessions.sh     # DM sessions .desktop generator
│   ├── dev-open.sh             # VS Code / Codium integration
│   └── dev-sync.sh             # GitHub/GitLab snapshot tool
└── README.md
________________________________________
🧰 Installation (local machine)
Clone the repository:
git clone https://github.com/Vguver/isolated-desktops.git
cd isolated-desktops
chmod +x install.sh
chmod +x scripts/*.sh
Create the wrapper tool:
mkdir -p ~/.local/bin
cat > ~/.local/bin/idtool << 'EOF'
#!/usr/bin/env bash
"$HOME/isolated-desktops/install.sh" "$@"
EOF
chmod +x ~/.local/bin/idtool
Make sure ~/.local/bin is in $PATH.
Then run:
idtool
________________________________________
🚀 Usage (idtool menu)
=== Isolated Desktops Installer (idtool) ===

1) Install an isolated desktop environment
2) Create launch script (start-<name>.sh)
3) Create display manager session (.desktop)
4) Full interactive flow (1 -> 2 -> 3)
5) Dev tools (VS Code / VSCodium)
6) Git snapshot dotfiles
0) Exit
________________________________________
🛠 Key Concepts
🏠 Fake HOME directories
Each desktop lives in its own HOME:
~/.omarchy/.config/
~/.jakoolit/.config/
...
This ensures complete isolation between desktops.
________________________________________
🔧 Installer logs
Each environment stores logs under:
~/.<name>/logs/
Includes:
•	Installer stdout/stderr
•	Pacman pre/post install diffs
•	Local file changes under fake HOME
•	Optional system-wide file changes (TRACK_SYSTEM_FILES=1)
________________________________________
📁 Dotfiles organization
Each desktop has:
~/isolated-desktops/desktops/<name>/
Can be linked into the fake HOME via:
./scripts/dotfiles-link.sh link-config <name>
________________________________________
🧑‍💻 Developer tools
VS Code / Codium
./scripts/dev-open.sh real-home
./scripts/dev-open.sh fake-home omarchy
./scripts/dev-open.sh dotfiles jakoolit
Git Snapshot (GitHub/GitLab)
./scripts/dev-sync.sh snapshot omarchy git@github.com:User/omarchy-config.git main
________________________________________
🧩 Requirements
•	Bash
•	Git
•	curl
•	Optional:
o	pacman (Arch-based auto-installers)
o	VS Code or VSCodium
o	Display manager (SDDM, LightDM, GDM, etc.)
________________________________________
🔮 Future Plans
•	Module 4: VM/workspace profiles
•	Module 5: Cloud sync automation
•	Module 6: Desktop template builder
________________________________________
📄 License
This project does not yet specify a license.
