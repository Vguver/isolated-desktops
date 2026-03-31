# Adapters

An adapter is the project-specific install logic for one upstream desktop repo.

Each adapter may define:

- `adapter_prepare_layout <name> <mode>`
- `adapter_plan <name> <mode>`
- `adapter_install <name> <mode>`
- `adapter_post_install <name> <mode>`
- `adapter_start_command <name>`

## Included adapters

- `omarchy.sh`
- `jakoolit.sh`
- `ml4w-starter.sh`
- `ml4w-dotfiles.sh`
- `dwm-titus.sh`
- `generic-shell.sh`

## Rule of thumb

Use `generic-shell` only as a temporary bridge. For anything you care about, write a real adapter.
