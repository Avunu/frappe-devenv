# [devenv](https://github.com/cachix/devenv)-managed [Frappe](https://github.com/frappe/frappe) Bench

A declarative developer environment for Frappe sites. This setup provides reproducible development and production environments for Frappe sites and applications.

## Overview

This repository serves as a monorepo workspace for Frappe development, including a few flagship Frappe apps:

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
* [devenv](https://devenv.sh/getting-started/)
* [direnv](https://direnv.net/)

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

## Notes

This is very much a work in progress, and the container workflow is not yet tested. Feel free to give it a go and report back with your findings!

