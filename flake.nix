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
          { pkgs, ... }:
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

              # Per-app fetchYarnDeps hashes live in node-offline-hashes.json,
              # kept current by `bench-update` (or `bench-update --node-hashes`).

              containers.enable = true;
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
