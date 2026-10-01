# Repository Guidelines

## Project Structure & Module Organization

This repository builds macOS 27 CI virtual machines with Packer and Tart.
`src/templates/` contains numbered HCL templates for the base, GUI, recovery,
and SSH stages. Provisioning scripts live in `src/templates/scripts/`, grouped
by responsibility (for example, `homebrew/` and `xcode/`). Guest shell profiles
and tool configuration live in `src/templates/data/`. Repository maintenance
utilities are in `scripts/`; lint configuration is in `hk.pkl` and `.config/`.

## Build, Test, and Development Commands

Use a Mac running macOS 27 for VM builds. Run commands from the root.

- `mise install`: install configured tools and run the bootstrap hook.
- `mise run check` (alias `chk` or `lint`): run all hk checks, matching CI.
- `mise run fix`: apply automated formatting and fixes; review the diff afterward.
- Run `mise run build:base`, `mise run build:ci-gui`, `mise run build:ci-recovery`, and `mise run build:ci-ssh` in order to build the VM stages. Each task initializes, validates, and builds its template.

Use task names from `mise.toml`; the README's `build:boot` reference is outdated.
Builds write ignored `packer-*.log` files and pause for inspection on errors.
When invoking Packer directly, build each template separately.

## Coding Style & Naming Conventions

Follow `.editorconfig`: tabs by default; two spaces for HCL, Pkl, YAML, and
`mise.toml`. End files with a newline and remove trailing whitespace. Use
kebab-case filenames for new scripts and preserve numbered template names.
Use descriptive snake_case Bash functions and quote variable expansions.
Formatting and linting include Packer fmt, shfmt, ShellCheck, actionlint,
Tombi, and editorconfig-checker, coordinated through hk.

## Testing Guidelines

Run `mise run check` before submitting changes. Xcode utilities have a standalone
Bash smoke suite:
`bash src/templates/scripts/xcode/tests/test_xcode-utils.bash`.
Run it on macOS with Xcode installed; test functions use the `test_` prefix.
Inspect printed failures because the runner does not reliably return a failing
exit status. No coverage threshold is configured. Validate provisioning changes
by rebuilding the affected VM stages; CI currently runs lint checks only.

## Commit & Pull Request Guidelines

History uses descriptive subjects such as `Add commands to disable wifi
and bluetooth`; Conventional Commits are not required. In PR descriptions, explain the affected stages, behavior changes, and validation
performed. Link relevant issues and include logs or screenshots when they clarify
VM boot or GUI behavior.

## Security & Configuration

Templates default to `admin` credentials and relax guest security for CI.
Keep these VMs isolated and never commit secrets, private keys, or build logs.
