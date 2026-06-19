{
  description = "Frappe Bench Development Environment (frappe-nix wrapper PoC)";

  inputs = {
    # apps/* are git submodules; expose their contents to the flake source tree.
    self.submodules = true;

    # All the heavy lifting (uv2nix python env, yarn node_modules, benchRoot,
    # OCI containers, devenv shell, scripts, NixOS module) lives in frappe-nix.
    # frappe-nix.lib.mkFlake merges frappe-nix's own inputs (nixpkgs, devenv,
    # pyproject-nix, uv2nix, pyproject-build-systems, nix2container) into ours,
    # so we don't re-declare them here.
    frappe-nix.url = "github:Avunu/frappe-nix";

    # flake-parts resolves perSystem `pkgs` from an input literally named
    # `nixpkgs`; follow frappe-nix's pin so we don't diverge from the modules.
    nixpkgs.follows = "frappe-nix/nixpkgs";
  };

  nixConfig = {
    extra-substituters = [ "https://devenv.cachix.org" ];
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  outputs =
    { self, frappe-nix, ... }@inputs:
    frappe-nix.lib.mkFlake { inherit inputs; } (
      { inputs, self, ... }:
      {
        imports = [ frappe-nix.flakeModules.default ];

        systems = [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-darwin"
          "x86_64-linux"
        ];

        perSystem =
          { pkgs, lib, ... }:
          {
            frappe-nix = {
              enable = true;
              benchName = "frappe"; # container images: frappe/web, frappe/nginx, …
              siteName = "frappe.localhost"; # → FRAPPE_SITE
              workspaceRoot = ./.;
              python = pkgs.python314; # module default is python312
              nodejs = pkgs.nodejs_24; # module default is nodejs_22

              mariadb.initialDatabases = [
                { name = "_0edd63f3387bcb99"; }
              ];

              # fetchYarnDeps offline-cache hashes (depend on each app's
              # yarn.lock). Regenerate after updating an app: unset the entry,
              # `nix build .#benchRoot`, copy the reported `got: sha256-…`.
              nodeOfflineHashes = {
                frappe = "sha256-NV6LX77aeEYFNbROkGkYcADOZAUl6C/c0eJh5BVpZx8=";
                erpnext = "sha256-25VPD0K192AMYRmOHhMao6I3As/KW9LvulB/6zK2Wbk=";
                hrms = "sha256-UFAEybvxz7uW26bz6JQ0VxQu8Tw08CdH7FjV6KaEfOk=";
              };

              containers.enable = true;

              # Scripts not provided (or weaker) in frappe-nix/lib/scripts.nix.
              # extraScripts is merged over the standard set, so a same-named key
              # here overrides the built-in one.
              extraScripts = {
                # Scaffold a new app and wire it into the uv workspace + apps.txt.
                # Not present in frappe-nix's standard script set.
                bench-new-app = {
                  exec = ''
                    if [ -z "$1" ]; then
                      echo "Usage: bench-new-app <app-name>"
                      echo ""
                      echo "Creates a new Frappe app and integrates it into the devenv workspace."
                      echo "Wraps 'bench new-app' to work around the read-only Nix environment."
                      exit 1
                    fi

                    APP_NAME="$1"
                    APP_DIR="apps/$APP_NAME"

                    cd "$FRAPPE_BENCH_ROOT"

                    if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/pyproject.toml" ]; then
                      echo "Error: App '$APP_NAME' already exists in $APP_DIR"
                      exit 1
                    fi

                    echo ""
                    echo "Creating app scaffold with 'bench new-app --no-git $APP_NAME'..."
                    echo "⚠  The install step will fail (read-only Nix env) — this is expected."
                    echo ""

                    bench new-app --no-git "$APP_NAME" || true

                    if [ ! -f "$APP_DIR/pyproject.toml" ]; then
                      echo "Error: App scaffold was not created at $APP_DIR"
                      exit 1
                    fi

                    echo "Registering $APP_NAME in pyproject.toml workspace..."
                    dasel put -f pyproject.toml -t string 'tool.uv.workspace.members.append()' "apps/$APP_NAME"
                    dasel put -f pyproject.toml -t bool "tool.uv.sources.$APP_NAME.workspace" true

                    echo "Adding $APP_NAME to sites/apps.txt..."
                    if ! grep -q "^$APP_NAME$" sites/apps.txt; then
                      echo "$APP_NAME" >> sites/apps.txt
                    fi

                    echo "Syncing Python dependencies..."
                    uv sync

                    echo ""
                    echo "Reloading devenv (direnv)..."
                    direnv reload

                    echo ""
                    echo "✅ App '$APP_NAME' created and integrated!"
                    echo ""
                    echo "Next steps:"
                    echo "  bench --site $FRAPPE_SITE install-app $APP_NAME"
                  '';
                  packages = [ pkgs.dasel ];
                  description = "Creates a new Frappe app scaffold and integrates it into the workspace.";
                };

                # Override frappe-nix's bench-get-app with the dasel variant that
                # also edits pyproject.toml ([tool.uv.workspace] + [tool.uv.sources]).
                bench-get-app = {
                  exec = ''
                    if [ -z "$1" ]; then
                      echo "Usage: bench-get-app <url-or-alias>"
                      echo ""
                      echo "Adds a Frappe app as a git submodule and integrates it into the workspace."
                      echo ""
                      echo "Examples:"
                      echo "  bench-get-app frappe/payments"
                      echo "  bench-get-app https://github.com/frappe/payments.git"
                      exit 1
                    fi

                    INPUT="$1"
                    cd "$FRAPPE_BENCH_ROOT"

                    if [[ "$INPUT" == */* ]] && [[ "$INPUT" != *://* ]]; then
                      URL="https://github.com/$INPUT.git"
                    else
                      URL="$INPUT"
                    fi

                    APP_NAME=$(basename "$URL" .git)
                    APP_DIR="apps/$APP_NAME"

                    if [ -d "$APP_DIR" ]; then
                      echo "Error: App '$APP_NAME' already exists in $APP_DIR"
                      exit 1
                    fi

                    echo "Adding git submodule: $URL -> $APP_DIR"
                    git submodule add "$URL" "$APP_DIR"
                    git submodule update --init --recursive "$APP_DIR"

                    echo "Adding $APP_NAME to pyproject.toml workspace members..."
                    dasel put -f pyproject.toml -t string 'tool.uv.workspace.members.append()' "apps/$APP_NAME"
                    dasel put -f pyproject.toml -t bool "tool.uv.sources.$APP_NAME.workspace" true

                    echo "Adding $APP_NAME to sites/apps.txt..."
                    if ! grep -q "^$APP_NAME$" sites/apps.txt; then
                      echo "$APP_NAME" >> sites/apps.txt
                    fi

                    echo "Syncing Python dependencies..."
                    uv sync

                    echo ""
                    echo "✅ App '$APP_NAME' added successfully!"
                    echo ""
                    echo "Next steps:"
                    echo "  1. Restart devenv: direnv reload --no-eval-cache"
                    echo "  2. Install the app: bench --site $FRAPPE_SITE install-app $APP_NAME"
                  '';
                  packages = [ pkgs.dasel ];
                  description = "Adds a Frappe app from a git URL or GitHub alias as a git submodule and integrates it into the workspace.";
                };
              };
            };
          };

        # Proof-of-concept production deployment consuming the frappe-nix NixOS
        # module. Build with:
        #   nix build .#nixosConfigurations.frappe-demo.config.system.build.toplevel
        #   nixos-rebuild build-vm --flake .#frappe-demo
        flake.nixosConfigurations.frappe-demo = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            frappe-nix.nixosModules.default
            (
              { ... }:
              {
                services.frappe = {
                  enable = true;
                  benchRoot = self.packages.x86_64-linux.benchRoot;
                  pythonEnv = self.packages.x86_64-linux.prodPythonEnv;
                  defaultSite = "frappe.localhost";
                  nginx.enable = true;
                  redis.createLocally = true;
                  database.createLocally = true;
                };

                # Minimal bootable host stub so `build-vm` works as a demo.
                boot.loader.grub.device = "nodev";
                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  fsType = "ext4";
                };
                system.stateVersion = "24.11";
              }
            )
          ];
        };
      }
    );
}
