# Manifests

Built-in manifests live in:

```text
manifests/*.json
```

Custom override manifests live in:

```text
~/.config/isolated-desktops/profiles.d/*.json
```

If a custom manifest has the same name as a built-in one, the custom manifest wins.

## Main fields

- `name`
- `display_name`
- `repo_url`
- `ref`
- `adapter`
- `session_type`
- `default_mode`
- `supported_modes`
- `start_command`
- `risk`
- `summary`
- `host_changes`
- `profile_changes`
- `notes`
