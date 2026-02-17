# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important

**All documentation is maintained in `AGENTS.md`.**

Please read `AGENTS.md` for comprehensive guidance on:
- Repository architecture and decisions
- Installation procedures
- Common tasks and conventions
- Testing and troubleshooting
- Platform-specific notes

## Goal

Keep this file minimal. All updates should go to `AGENTS.md`.

## Quick Reference

- Repository: https://github.com/jelera/dotfiles
- Installation: `./install.sh`
- Helper functions: `install/common.sh`
- Tool manager: **mise** (PRIMARY - see `mise/config.toml`)
- Package priority: **mise** → Homebrew → PPA → Apt → Flathub → Source (NO snap)
- Secrets: `~/.env.local` (see `shell/.env.local.example`)
- Add tools: Check `mise ls-remote <tool>` first, add to `mise/config.toml`
- Bash requirement: **4.0+** (auto-installed on macOS via Homebrew)
