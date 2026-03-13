# [devenv](https://github.com/cachix/devenv)-managed [Frappe](https://github.com/frappe/frappe) Bench

A declarative Frappe developer environment, providing reproducible development and production environments for Frappe sites and applications.

## Overview

This repository serves as a monorepo workspace template for Frappe development, including a few flagship Frappe apps:

* **Frappe Framework** (apps/frappe)
* **ERPNext** (apps/erpnext)
* **HRMS** (apps/hrms)

The environment uses Nix flakes and devenv to declaratively manage:

* Python virtual environments with all dependencies
* Node.js packages for frontend assets
* Development tools (ruff, pytest, mypy, etc.)
* Production container images for deployment

## Getting Started

### Prerequisites

* [Nix](https://nixos.org/download.html) with flakes enabled
* [direnv](https://direnv.net/)

#### Getting started with WSL on Windows

If you aren't yet set up for running NixOS Flake-based software locally, the easiest route is to install NixOS on WSL and use the Avunu configuration.

1. Enable/install NixOS WSL via the [Quickstart documentation](https://nix-community.github.io/NixOS-WSL/).
2. Activate the [Avunu NixOS configuration](https://github.com/avunu/nixos-wsl) within the NixOS shell:

```Shell
curl -fsSL https://raw.githubusercontent.com/Avunu/nixos-wsl/main/local/flake.nix | \
  sudo install -Dm644 /dev/stdin /etc/nixos/flake.nix && \
  sudo nixos-rebuild switch --flake /etc/nixos#nixos --impure
```

3. Install the [WSL extension in VSCode](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) to connect to the NixOS instance.
4. After opening a NixOS session in VSCode, use the source control sidebar to clone this repository into the NixOS instance.

### Setup

1. Clone the repository with submodules:
   ```Shell
   git clone --recurse-submodules https://github.com/Avunu/frappe-devenv.git
   cd frappe-devenv
   ```

2. Allow direnv to load the environment:
   ```Shell
   direnv allow
   ```

3. Start the Devenv-managed services:
   ```Shell
   devenv up
   ```

4. Initialize a new Frappe site (root password is blank/unset):
   ```Shell
   bench new-site frappe.localhost
   bench --site frappe.localhost install-app erpnext
   bench --site frappe.localhost install-app hrms
   ```

5. Open the development site in your browser: <http://localhost:8000/>

## Managing Apps

Frappe apps are included as **git submodules** under the `apps/` directory (see [.gitmodules](.gitmodules)). Each submodule is also registered as a [uv workspace](https://docs.astral.sh/uv/concepts/workspaces/) member in [pyproject.toml](pyproject.toml), so Python dependencies are resolved together across all apps.

### Custom Commands

The devenv shell provides several convenience commands:

* **`bench-get-app <url-or-alias>`** — Adds a new Frappe app by cloning it as a git submodule, registering it in the uv workspace, and syncing dependencies. Accepts a GitHub shorthand (e.g. `frappe/payments`) or a full git URL.
* **`bench-restore <sql-file> [options]`** — Restores the local Frappe site from a SQL backup file, automatically supplying the database credentials from the environment.
* **`update-deps`** — Re-locks and syncs both Python (uv) and Node (yarn) dependencies across all apps, then reminds you to commit the updated lock files.

## Notes

This is very much a work in progress, and the container workflow is not yet tested. Feel free to give it a go and report back with your findings!

