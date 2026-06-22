{
  description = "Frappe Bench Development Environment";

  inputs = {
    self.submodules = true;
    frappe-nix.url = "path:/home/batonac/Development/frappe-nix";
    nixpkgs.follows = "frappe-nix/nixpkgs";
    flake-parts.follows = "frappe-nix/flake-parts";
    devenv.follows = "frappe-nix/devenv";
  };

  outputs =
    {
      self,
      flake-parts,
      frappe-nix,
      devenv,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        frappe-nix.flakeModules.default
      ];

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
            benchName = "frappe";
            siteName = "frappe.localhost";
            workspaceRoot = ./.;
            python = pkgs.python314;
            nodejs = pkgs.nodejs_24;

            mariadb.package = pkgs.mariadb;
            mariadb.initialDatabases = [
              { name = "_0edd63f3387bcb99"; }
            ];

            # hrms needs special yarn flags due to nested install scripts
            nodeOverrides = {
              hrms = {
                yarnFlags = [
                  "--offline"
                  "--frozen-lockfile"
                  "--ignore-engines"
                  "--ignore-scripts"
                ];
                preInstall = ''
                  rm -rf "node_modules/hrms"
                '';
              };
            };

            extraEnv = {
              MYSQL_ROOT_PASSWORD = "";
            };

            containers.enable = true;
          };
        };
    };
}
