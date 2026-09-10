# Dotfiles Operations

This root `AGENTS.md` owns repository-wide agent instructions. Keep them here;
do not create `.github` configuration or separate Copilot instructions.

## Ownership and routing

- This repository owns shared configuration, symlinks, and package declarations.
  Machine setup and system orchestration belong in the machine repository.
- Work through [machine-thinkpad-p16s](../machine-thinkpad-p16s/AGENTS.md) and its
  [install workflow](../machine-thinkpad-p16s/docs/AI_PLAYBOOK.md). Installs go
  through the agent so packages, configs, and backups stay in sync.
- Shared packages belong in `packages/base.txt`; host packages in
  `packages/<host>.txt`. Host-specific Hyprland settings belong in
  `config/hypr/hosts/<host>.lua`. The active host is `thinkpad-p16s-gen4`.
- See [README.md](README.md) for configuration layout and maintenance commands.

## Changes

- Inspect active consumers before editing. Preserve unrelated worktree changes.
- Replace obsolete implementations and update all affected repositories;
  remove stale configs, references, symlinks, and package declarations.
- Keep package declarations and relevant tracked configuration consistent.
  Applications with private app-owned settings do not need tracked configs.
- Use Nord colors and Wayland settings. Follow existing app-specific flags;
  shared Electron flags live in `config/electron-flags.conf`.
- Use Bash and `set -e` for one-shot scripts; reuse existing color variables.
  Use pacman/yay for system packages and uv for Python.

## Privacy and validation

- Never track credentials, browser profiles, app data, or Electron caches.
- Check `sync.sh`'s `IGNORE_LIST` before adding configs; update it and
  `.gitignore` when new private or generated files need exclusion.
- Keep documentation concise and current, linking instead of duplicating.
- Check for stale references and run `git diff --check`. Run `sync.sh status`
  when configuration or symlink behavior changes; validate other changes
  proportionally.
- Commit task-scoped changes locally after validation. Do not push to GitHub.
