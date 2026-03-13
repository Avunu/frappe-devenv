{
  description = "Frappe Bench Development Environment";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    # Python dependency management via uv
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      devenv,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({
      imports = [
        devenv.flakeModule
      ];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          lib,
          ...
        }:
        let
          # Load uv workspace from root pyproject.toml + uv.lock
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

          # Read the root pyproject.toml to extract direct dependencies.
          # These are re-added explicitly when the root virtual package
          # (frappe-bench-devenv) is filtered out of mkVirtualEnv specs,
          # so we don't need a wheel_target stub directory.
          rootPyproject = builtins.fromTOML (builtins.readFile ./pyproject.toml);
          rootDepNames = map (
            dep: lib.strings.toLower (builtins.head (builtins.match "([A-Za-z0-9_-]+).*" dep))
          ) (rootPyproject.project.dependencies or [ ]);
          rootDepsAttr = lib.genAttrs rootDepNames (_: [ ]);

          # Create overlay from workspace
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };

          # Python package set with uv2nix overlay
          python = pkgs.python314;

          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  # Custom overrides for packages that need special handling
                  (
                    final: prev:
                    let
                      # Helper function to add setuptools as a build dependency
                      addSetuptools =
                        pkg:
                        pkg.overrideAttrs (old: {
                          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.setuptools ];
                        });

                      # Helper to conditionally add setuptools only if package exists
                      maybeAddSetuptools =
                        name: if prev ? ${name} then { ${name} = addSetuptools prev.${name}; } else { };

                      # List of packages that need setuptools but don't declare it
                      # These are typically older packages that predate PEP 517/518
                      packagesNeedingSetuptools = [
                        "backcall"
                        "backoff"
                        "barcodenumber"
                        "bleach-allowlist"
                        "braintree"
                        "chardet"
                        "colorama"
                        "croniter"
                        "cssselect"
                        "cssselect2"
                        "cssutils"
                        "dataclasses-json"
                        "decorator"
                        "docopt"
                        "dropbox"
                        "email-reply-parser"
                        "et-xmlfile"
                        "executing"
                        "filetype"
                        "getmac"
                        "gocardless-pro"
                        "googlemaps"
                        "gunicorn"
                        "hiredis"
                        "html5lib"
                        "httplib2"
                        "jellyfish"
                        "jsonpath-ng"
                        "ldap3"
                        "markdown2"
                        "markdownify"
                        "marshmallow"
                        "matplotlib-inline"
                        "maxminddb-geolite2"
                        "maxminddb"
                        "monotonic"
                        "num2words"
                        "oauthlib"
                        "openpyxl"
                        "parso"
                        "passlib"
                        "paytmchecksum"
                        "pdfkit"
                        "pexpect"
                        "phonenumbers"
                        "pickleshare"
                        "plaid-python"
                        "ply"
                        "polyline"
                        "posthog"
                        "premailer"
                        "prompt-toolkit"
                        "psutil"
                        "ptyprocess"
                        "pure-eval"
                        "pyasn1-modules"
                        "pyasn1"
                        "pycountry"
                        "pycryptodome"
                        "pydyf"
                        "pyjwt"
                        "pymysql"
                        "pyopenssl"
                        "pyotp"
                        "pyparsing"
                        "pypdf"
                        "pyphen"
                        "pypika"
                        "pypng"
                        "pyqrcode"
                        "python-barcode"
                        "python-docx"
                        "python-ldap"
                        "python-magic"
                        "python-pptx"
                        "python-stdnum"
                        "python-youtube"
                        "pytz"
                        "rapidfuzz"
                        "rauth"
                        "razorpay"
                        "redis"
                        "requests-oauthlib"
                        "responses"
                        "restrictedpython"
                        "rq"
                        "rsa"
                        "ruamel-yaml-clib"
                        "six"
                        "soupsieve"
                        "sql-metadata"
                        "sqlparse"
                        "stack-data"
                        "stone"
                        "stripe"
                        "tenacity"
                        "terminaltables"
                        "tinycss2"
                        "tinyhtml5"
                        "traceback-with-variables"
                        "traitlets"
                        "typing-inspect"
                        "unidecode"
                        "uritemplate"
                        "us"
                        "vobject"
                        "wcwidth"
                        "weasyprint"
                        "webencodings"
                        "whoosh"
                        "xlrd"
                        "xmltodict"
                        "zopfli"
                        "zxcvbn"
                      ];

                      # Build the attribute set of overridden packages
                      setuptoolsOverrides = lib.foldl' (
                        acc: name: acc // (maybeAddSetuptools name)
                      ) { } packagesNeedingSetuptools;
                    in
                    setuptoolsOverrides
                    // {
                      # cairocffi needs setuptools, cffi, and pycparser for building
                      cairocffi = prev.cairocffi.overrideAttrs (old: {
                        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                          final.setuptools
                          final.cffi
                          final.pycparser
                        ];
                      });

                      # mysqlclient needs mariadb headers
                      mysqlclient = prev.mysqlclient.overrideAttrs (old: {
                        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                          final.setuptools
                          pkgs.pkg-config
                          pkgs.mariadb-connector-c
                        ];
                        buildInputs = (old.buildInputs or [ ]) ++ [
                          pkgs.mariadb.client
                          pkgs.openssl
                          pkgs.zlib
                        ];
                      });
                    }
                  )
                ]
              );

          # ── Production Python environment ──────────────────────────
          # Contains only workspace members + their runtime deps.
          # No dev tools (ruff, mypy, semgrep, pytest, …).
          # Used by all OCI container images.
          prodPythonEnv = pythonSet.mkVirtualEnv "frappe-bench-prod-env" (
            lib.filterAttrs (name: _: name != "frappe-bench-devenv") workspace.deps.default
            // rootDepsAttr
          );

          # ── Development Python environment ──────────────────────────
          # Adds dev dependency-group (ruff, mypy, semgrep, pytest, …)
          # and frappe's optional dev/test extras on top of the
          # production deps.
          #
          # Uses uv2nix's editable overlay so that workspace packages
          # resolve from the local source tree (apps/*) rather than
          # Nix-store copies.  This replaces the old PYTHONPATH hack
          # and gives proper __file__ paths, entry-point discovery,
          # and hot-reload support.
          editablePythonSet = pythonSet.overrideScope (
            workspace.mkEditablePyprojectOverlay {
              root = "$REPO_ROOT";
            }
          );

          devPythonEnv = editablePythonSet.mkVirtualEnv "frappe-bench-dev-env" (
            lib.filterAttrs (name: _: name != "frappe-bench-devenv") (
              workspace.deps.default // workspace.deps.groups
            )
            // rootDepsAttr
          );

          # Build PYTHONPATH from apps/ directories for production
          # containers.  The containers use the non-editable
          # prodPythonEnv, so PYTHONPATH is still needed to resolve
          # workspace packages from benchRoot's /bench/apps/* copies.
          appNames = builtins.attrNames (builtins.readDir ./apps);
          appsPath = root: lib.concatMapStringsSep ":" (app: "${root}/apps/${app}") appNames;

          # Node.js dependencies for apps with package.json and yarn.lock
          # Used by mkYarnPackage for production container builds only;
          # in development, Yarn manages node_modules natively (mutable).
          appsWithNode = lib.filter (
            app:
            builtins.pathExists (./apps + "/${app}/package.json")
            && builtins.pathExists (./apps + "/${app}/yarn.lock")
          ) appNames;

          # Production-only: build immutable node_modules from yarn.lock
          # via mkYarnPackage. Used in container images for reproducible deploys.
          # In development, Yarn manages node_modules natively so that
          # `yarn add`, `yarn remove`, and `yarn upgrade` work freely.
          nodeModulesForApp =
            app:
            let
              pkg = pkgs.mkYarnPackage {
                name = app;
                src = ./apps/${app};
                nodejs = pkgs.nodejs_24;
                # get app_version from the app's hooks.py or __init__.py, otherwise default to "0.1.0"
                version =
                  let
                    hooksPath = ./apps/${app}/hooks.py;
                    initPath = ./apps/${app}/${app}/__init__.py;
                    hooksContent = if builtins.pathExists hooksPath then builtins.readFile hooksPath else "";
                    initContent = if builtins.pathExists initPath then builtins.readFile initPath else "";
                    # First try app_version in hooks.py
                    appVersionMatch = builtins.match ".*app_version[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"].*" hooksContent;
                    # Fallback to __version__ in __init__.py
                    versionMatch = builtins.match ".*__version__[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"].*" initContent;
                  in
                  if appVersionMatch != null then
                    builtins.elemAt appVersionMatch 0
                  else if versionMatch != null then
                    builtins.elemAt versionMatch 0
                  else
                    "0.1.0";
                yarn = pkgs.yarn;
              };
            in
            pkgs.runCommand "${app}-node-modules" { } ''
              mkdir -p $out
              ln -s ${pkg}/libexec/${app}/node_modules $out/node_modules
            '';

          nodeModules = lib.genAttrs appsWithNode nodeModulesForApp;

          # ─────────────────────────────────────────────────────────
          # Production Container Infrastructure
          # ─────────────────────────────────────────────────────────
          #
          # Everything below is built declaratively from lock files
          # and source — no imperative yarn install / uv sync at
          # container start.  The dev→prod contract:
          #
          #   Developer (imperative)     Nix build (declarative)
          #   ──────────────────────     ──────────────────────────
          #   uv add / uv sync     →    uv2nix reads uv.lock
          #   yarn add / yarn install →  mkYarnPackage reads yarn.lock
          #   edits apps/ source   →    benchRoot copies source tree
          #
          # Architecture:
          #   ┌─────────┐  ┌───────────┐  ┌────────────┐
          #   │   web   │  │ socketio  │  │  nginx     │
          #   │ gunicorn│  │  node.js  │  │  reverse   │
          #   │ :8000   │  │  :9000    │  │  proxy :80 │
          #   └────┬────┘  └─────┬─────┘  └─────┬──────┘
          #        │             │               │
          #   ┌────┴────┐  ┌────┴─────┐  ┌──────┴──────┐
          #   │ worker  │  │ worker   │  │   worker    │
          #   │ default │  │  short   │  │    long     │
          #   └─────────┘  └──────────┘  └─────────────┘
          #        │             │               │
          #   ┌────┴─────────────┴───────────────┴────┐
          #   │            scheduler                   │
          #   └────────────────────────────────────────┘
          #
          # External (not containerized here):
          #   - MariaDB (managed database)
          #   - Redis Cache / Queue / Socketio
          #
          # Usage:
          #   devenv container <name> build
          #   devenv container <name> copy [registry]
          #   devenv container <name> run
          # ─────────────────────────────────────────────────────────

          # Declaratively assemble the /bench directory for production.
          # Combines app source, Nix-built node_modules (from mkYarnPackage),
          # Python env symlink, config files, and site metadata into a
          # single derivation — no imperative setup at container start.
          benchRoot = pkgs.runCommand "bench-root" { } ''
            mkdir -p $out/bench/{sites,logs,config/pids}

            # Python env → /bench/env (where bench expects it)
            ln -s ${prodPythonEnv} $out/bench/env

            # App source with declarative node_modules from mkYarnPackage
            mkdir -p $out/bench/apps
            ${lib.concatStringsSep "\n" (
              map (app: ''
                cp -r ${./apps/${app}} $out/bench/apps/${app}
                chmod -R u+w $out/bench/apps/${app}
                ${lib.optionalString (builtins.elem app appsWithNode) ''
                  rm -rf $out/bench/apps/${app}/node_modules
                  ln -s ${nodeModules.${app}}/node_modules $out/bench/apps/${app}/node_modules
                ''}
              '') appNames
            )}

            # Site metadata (tells Frappe which apps are installed)
            ${lib.optionalString (builtins.pathExists ./sites/apps.json) ''
              cp ${./sites/apps.json} $out/bench/sites/apps.json
            ''}
            ${lib.optionalString (builtins.pathExists ./sites/apps.txt) ''
              cp ${./sites/apps.txt} $out/bench/sites/apps.txt
            ''}

            # Config files (nginx.conf, etc.)
            ${lib.optionalString (builtins.pathExists ./config) ''
              cp -r ${./config}/* $out/bench/config/ 2>/dev/null || true
              chmod -R u+w $out/bench/config
            ''}
          '';

          # Runtime dependencies shared across all Python containers
          containerRuntimeDeps = with pkgs; [
            # Core utilities needed at runtime
            coreutils
            bashInteractive
            gnused
            gnugrep
            findutils
            which
            cacert

            # File type detection (python-magic)
            file

            # PDF generation
            wkhtmltopdf
            chromium

            # Image processing (Pillow)
            libjpeg
            libpng
            zlib

            # WeasyPrint / cairocffi
            cairo
            pango
            gdk-pixbuf
            harfbuzz
            fontconfig
            freetype

            # Native library deps
            openssl
            libffi
            mariadb.client

            # Fonts for PDF rendering
            liberation_ttf
            noto-fonts
          ];

          # Shared environment variables for production containers
          containerEnvVars = lib.concatStringsSep "\n" [
            ''export FRAPPE_BENCH_ROOT="/bench"''
            ''export SITES_PATH="/bench/sites"''
            ''export PYTHONPATH="${appsPath "/bench"}"''
            ''export DEV_SERVER="0"''
            ''export FRAPPE_ENV_TYPE="production"''
            ''export FRAPPE_STREAM_LOGGING="1"''
            ''export FRAPPE_TUNE_GC="1"''
            ''export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"''
            ''export LD_LIBRARY_PATH="${
              lib.makeLibraryPath [
                pkgs.zlib
                pkgs.openssl
                pkgs.libffi
                pkgs.file.out
                pkgs.mariadb.client
                pkgs.cairo
                pkgs.pango
                pkgs.gdk-pixbuf
                pkgs.harfbuzz
                pkgs.fontconfig
                pkgs.freetype
                pkgs.libjpeg
                pkgs.libpng
              ]
            }"''
          ];

          # Entrypoint for Frappe Python containers.
          # All build-time assembly (env symlink, app source, node_modules)
          # is handled by benchRoot — only runtime state dirs created here.
          containerEntrypoint = pkgs.writeShellScript "frappe-entrypoint" ''
            set -euo pipefail
            export PATH="${prodPythonEnv}/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.which}/bin:$PATH"
            ${containerEnvVars}

            # Runtime-only: mutable dirs for logs and process state
            mkdir -p /bench/logs /bench/config/pids

            cd /bench/sites
            exec "$@"
          '';

          # Node.js entrypoint for socketio
          socketioEntrypoint = pkgs.writeShellScript "socketio-entrypoint" ''
            set -euo pipefail
            export PATH="${pkgs.nodejs_24}/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin:$PATH"
            cd /bench
            exec "$@"
          '';

          # Nginx entrypoint
          nginxEntrypoint = pkgs.writeShellScript "nginx-entrypoint" ''
            set -euo pipefail
            export PATH="${pkgs.nginx}/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin:$PATH"
            mkdir -p /tmp/nginx
            exec "$@"
          '';

          # Helper to build a Frappe Python container with shared structure.
          # All containers get: benchRoot (app source + env + node_modules +
          # config), prodPythonEnv, and runtime deps — fully declarative.
          mkFrappeContainer =
            {
              name,
              startupCommand,
              workingDir ? "/bench/sites",
              entrypoint ? [ containerEntrypoint ],
              extraPaths ? [ ],
              extraLayerDeps ? [ ],
            }:
            {
              inherit
                name
                workingDir
                entrypoint
                startupCommand
                ;
              version = "latest";
              registry = "docker-daemon:";
              copyToRoot = [
                (pkgs.buildEnv {
                  name = builtins.replaceStrings [ "/" ] [ "-" ] name + "-env";
                  paths = containerRuntimeDeps ++ [ prodPythonEnv ] ++ extraPaths;
                  pathsToLink = [
                    "/bin"
                    "/lib"
                    "/share"
                    "/etc"
                  ];
                })
                benchRoot
              ];
              layers = [
                # Layer 1: System runtime deps (rarely changes)
                {
                  deps = containerRuntimeDeps ++ extraLayerDeps;
                  maxLayers = 10;
                  reproducible = true;
                }
                # Layer 2: Python environment (changes on uv.lock updates)
                {
                  deps = [ prodPythonEnv ];
                  maxLayers = 20;
                  reproducible = true;
                }
                # Layer 3: App source + config + node_modules (changes on code/yarn.lock updates)
                {
                  deps = [ benchRoot ];
                  maxLayers = 5;
                  reproducible = true;
                }
              ];
              enableLayerDeduplication = true;
              maxLayers = 40;
            };

        in
        {
          # Export the Python environments as packages
          packages.prodPythonEnv = prodPythonEnv;
          packages.devPythonEnv = devPythonEnv;

          devenv.shells.default =
            { config, pkgs, ... }:
            {
              dotenv.enable = true;

              # ─────────────────────────────────────────────────────────────
              # Packages
              # ─────────────────────────────────────────────────────────────
              packages = with pkgs; [
                # The uv2nix-built Python environment with all Frappe apps + dev tools
                devPythonEnv

                # Build dependencies
                gcc
                pkg-config
                openssl
                zlib
                libffi

                # PDF/printing dependencies
                cups
                poppler-utils
                chromium # for PDF generation
                wkhtmltopdf # for legacy PDF generation

                # uv for managing the workspace lockfile
                uv

                # Development email server
                mailpit

                # Linting and security
                # semgrep is managed via uv (pyproject.toml) so it lives in
                # the Python 3.14 venv — no version mismatch with nixpkgs.

                # Utilities
                curl
                file
                git
                gnused
                htop
                jq
                just
                pv
              ];

              # ─────────────────────────────────────────────────────────────
              # Python Environment (provided by uv2nix)
              # ─────────────────────────────────────────────────────────────
              # Python is provided via devPythonEnv (editable + dev deps);
              # production containers use the leaner prodPythonEnv.

              # ─────────────────────────────────────────────────────────────
              # Node.js Environment (for frontend builds and socketio)
              # ─────────────────────────────────────────────────────────────
              # In development, Yarn manages node_modules natively (mutable)
              # so that `yarn add`, `yarn remove`, etc. work freely.
              # Production containers use mkYarnPackage to consume yarn.lock
              # declaratively for reproducible, immutable node_modules.
              languages.javascript = {
                enable = true;
                package = pkgs.nodejs_24;
                yarn = {
                  enable = true;
                  install.enable = false; # We run per-app yarn install in enterShell
                };
              };

              # ─────────────────────────────────────────────────────────────
              # Environment Variables
              # ─────────────────────────────────────────────────────────────
              env = {
                # Frappe environment
                DEV_SERVER = "1";
                FRAPPE_ENV_TYPE = "development";
                FRAPPE_STREAM_LOGGING = "1";
                FRAPPE_TUNE_GC = "1";
                LIVE_RELOAD = "1";
                NO_SERVICE_RESTART = "1";

                # Disable optional services
                USE_PROFILER = "";
                USE_PROXY = "";
                NO_STATICS = "";

                # Database configuration
                FRAPPE_DB_HOST = "127.0.0.1";
                FRAPPE_DB_PORT = "3306";
                FRAPPE_DB_TYPE = "mariadb";

                # Redis configuration (matching common_site_config.json)
                FRAPPE_REDIS_CACHE = "redis://localhost:13000";
                FRAPPE_REDIS_QUEUE = "redis://localhost:13000";
                FRAPPE_REDIS_SOCKETIO = "redis://localhost:13000";

                # Default site
                FRAPPE_SITE = "frappe.localhost";

                # Ports
                FRAPPE_WEBSERVER_PORT = "8000";
                FRAPPE_SOCKETIO_PORT = "9000";
                FRAPPE_FILE_WATCHER_PORT = "6787";

                # Mailpit (development email server)
                MAILPIT_SMTP_PORT = "1025";
                MAILPIT_HTTP_PORT = "8025";

                # Socket paths - using config.env at Nix eval time
                # Note: MySQL socket is at DEVENV_RUNTIME (devenv's default), not DEVENV_STATE
                FRAPPE_DB_SOCKET = config.env.DEVENV_RUNTIME + "/mysql.sock";
                FRAPPE_SOCKETS_DIR = config.env.DEVENV_STATE + "/sockets";
                FRAPPE_WEB_SOCKET = config.env.DEVENV_STATE + "/sockets/frappe.sock";
                # FRAPPE_SOCKETIO_UDS = config.env.DEVENV_STATE + "/sockets/socketio.sock";

                # Bench root - using config.devenv.root
                FRAPPE_BENCH_ROOT = config.devenv.root;
                SITES_PATH = config.devenv.root + "/sites";

                # ── Dev vs Prod separation ──────────────────────────────
                # In development, we need mutable environments so that
                # dependency managers (uv, yarn) can add/upgrade deps
                # imperatively. The resulting lock files (uv.lock, yarn.lock)
                # are then consumed declaratively by Nix for production
                # container builds.

                # uv: redirect the virtual-env to a mutable path so `uv add`,
                # `uv remove`, etc. don't collide with the read-only Nix
                # store venv. The Nix-built devPythonEnv is still on PATH for
                # running the app; this env is only for uv's bookkeeping.
                UV_PROJECT_ENVIRONMENT = config.env.DEVENV_STATE + "/uv-env";

                # yarn: persist the download cache across shells for speed.
                # Note: unlike UV there is no env var to redirect node_modules;
                # instead we let Yarn manage node_modules natively in dev
                # (see enterShell) and use mkYarnPackage for prod containers.
                YARN_CACHE_FOLDER = config.env.DEVENV_STATE + "/yarn-cache";

                # REPO_ROOT: used by the uv2nix editable overlay so that
                # workspace packages (frappe, erpnext, hrms, …) resolve from
                # the local source tree instead of Nix-store copies.
                # This replaces the old PYTHONPATH hack with proper editable
                # installs — correct __file__ paths, entry-point discovery,
                # and hot-reload all work out of the box.
                REPO_ROOT = config.devenv.root;

                # Library paths for native dependencies
                LD_LIBRARY_PATH = lib.makeLibraryPath [
                  pkgs.zlib
                  pkgs.openssl
                  pkgs.libffi
                  pkgs.file.out
                  pkgs.mariadb.client
                ];
              };

              # ─────────────────────────────────────────────────────────────
              # Shell Initialization
              # ─────────────────────────────────────────────────────────────
              enterShell = ''
                # Initialize git submodules if needed
                if git submodule status 2>/dev/null | grep -q '^-'; then
                  echo "Initializing git submodules..."
                  git submodule update --init --recursive
                fi

                # Create required directories
                mkdir -p "$DEVENV_STATE/mariadb" "$DEVENV_STATE/sockets" logs config/pids

                # Symlink the Nix-built Python env to ./env where bench expects it
                if [ "$(readlink env 2>/dev/null)" != "${devPythonEnv}" ]; then
                  ln -sfn "${devPythonEnv}" env
                fi

                # Install node_modules for each app with yarn (mutable, dev-friendly).
                # Unlike production containers (which use mkYarnPackage for
                # immutable Nix store node_modules), dev needs a writable
                # node_modules so `yarn add`/`yarn remove` work.
                # If node_modules already exists and is a Nix store symlink,
                # remove it first so yarn can create a real directory.
                ${lib.concatStringsSep "\n" (
                  map (app: ''
                    if [ -L "apps/${app}/node_modules" ] && readlink "apps/${app}/node_modules" | grep -q '/nix/store'; then
                      echo "Replacing Nix store node_modules symlink for ${app}..."
                      rm "apps/${app}/node_modules"
                    fi
                    if [ ! -d "apps/${app}/node_modules" ]; then
                      echo "Installing node_modules for ${app}..."
                      (cd "apps/${app}" && yarn install --frozen-lockfile 2>&1 | tail -1)
                    fi
                  '') appsWithNode
                )}

                echo ""
                echo "╔════════════════════════════════════════════════════════════╗"
                echo "║         frappe Frappe Bench Development Environment        ║"
                echo "╠════════════════════════════════════════════════════════════╣"
                echo "║  Start all services:                                       ║"
                echo "║    devenv up                                               ║"
                echo "║                                                            ║"
                echo "║  Default site: frappe.localhost                            ║"
                echo "║                                                            ║"
                echo "║  Common commands:                                          ║"
                echo "║    bench --site frappe.localhost migrate                   ║"
                echo "║    bench --site frappe.localhost console                   ║"
                echo "║    bench --site frappe.localhost clear-cache               ║"
                echo "║    bench build                                             ║"
                echo "╚════════════════════════════════════════════════════════════╝"
                echo ""
                echo "✅ frappe bench environment ready!"
                echo "   Python: ${devPythonEnv}/bin/python"
                echo "   Bench root: $PWD"
                echo "   Site: frappe.localhost"
                echo ""
                echo "💡 Run 'devenv up' to start all services"
              '';

              # ─────────────────────────────────────────────────────────────
              # Services (managed by process-compose via devenv up)
              # ─────────────────────────────────────────────────────────────

              # MariaDB via devenv's mysql service
              services.mysql = {
                enable = true;
                package = pkgs.mariadb;
                settings = {
                  mysqld = {
                    character-set-server = "utf8mb4";
                    collation-server = "utf8mb4_unicode_ci";
                    skip-character-set-client-handshake = true;
                    innodb-buffer-pool-size = "256M";
                    innodb-log-file-size = "64M";
                    max-connections = 200;
                    innodb-read-only-compressed = "OFF";
                    port = 3306;
                    bind-address = "127.0.0.1";
                  };
                };
                initialDatabases = [
                  { name = "frappe"; } # Frappe site database
                ];
                # ensureUsers = [
                #   {
                #     name = "frappe-root";
                #     password = "123";
                #     ensurePermissions = {
                #       "*.*" = "ALL PRIVILEGES";
                #     };
                #   }
                # ];
              };

              # Redis via devenv's redis service
              services.redis = {
                enable = true;
                port = 13000; # Cache port - we'll add more instances via processes
              };

              # Additional Redis instances and Frappe processes
              processes = {
                # Frappe Web Server
                web.exec = ''
                  exec ${devPythonEnv}/bin/bench serve --port 8000
                '';

                # Frappe Scheduler
                scheduler.exec = ''
                  exec ${devPythonEnv}/bin/bench schedule
                '';

                # Background Worker
                worker.exec = ''
                  exec ${devPythonEnv}/bin/bench worker
                '';

                # SocketIO Server
                socketio.exec = ''
                  rm -f "$DEVENV_STATE/sockets/socketio.sock"
                  exec ${pkgs.nodejs_24}/bin/node apps/frappe/socketio.js
                '';

                # File Watcher (for development auto-rebuild)
                watch.exec = ''
                  exec ${devPythonEnv}/bin/bench watch
                '';

                # Mailpit (development email server)
                mailpit.exec = ''
                  exec ${pkgs.mailpit}/bin/mailpit \
                    --smtp 127.0.0.1:1025 \
                    --listen 127.0.0.1:8025 \
                    --database "$DEVENV_STATE/mailpit.db"
                '';
              };

              # Process dependencies
              process.managers.process-compose.settings.processes = {
                web.depends_on = {
                  mysql.condition = "process_started";
                  redis.condition = "process_started";
                };
                scheduler.depends_on.mysql.condition = "process_started";
                worker.depends_on = {
                  mysql.condition = "process_started";
                  redis.condition = "process_started";
                };
                socketio.depends_on.redis.condition = "process_started";
                watch.depends_on.web.condition = "process_started";
              };

              # ─────────────────────────────────────────────────────────────
              # Scripts (convenience commands)
              # ─────────────────────────────────────────────────────────────
              scripts = {

                # Add a new Frappe app from git URL or GitHub alias
                # Usage: bench-get-app <url-or-alias>
                # Examples:
                #   bench-get-app frappe/payments
                #   bench-get-app https://github.com/frappe/payments.git
                bench-get-app.exec = ''
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

                  # ensure we're in the bench root directory
                  cd "$FRAPPE_BENCH_ROOT"

                  # Convert GitHub alias to full URL
                  if [[ "$INPUT" == */* ]] && [[ "$INPUT" != *://* ]]; then
                    URL="https://github.com/$INPUT.git"
                  else
                    URL="$INPUT"
                  fi

                  # Extract app name from URL
                  APP_NAME=$(basename "$URL" .git)
                  APP_DIR="apps/$APP_NAME"

                  if [ -d "$APP_DIR" ]; then
                    echo "Error: App '$APP_NAME' already exists in $APP_DIR"
                    exit 1
                  fi

                  echo "Adding git submodule: $URL -> $APP_DIR"
                  git submodule add "$URL" "$APP_DIR"

                  echo "Fetching app source..."
                  git submodule update --init --recursive "$APP_DIR"

                  echo "Adding $APP_NAME to pyproject.toml workspace members..."
                  # Add to [tool.uv.workspace] members list
                  sed -i "/^members = \[/,/^]/ { /^]/ i\    \"apps\/$APP_NAME\"," pyproject.toml

                  # Add to [tool.uv.sources] for workspace linking
                  sed -i "/frappe = { workspace = true }/ a\\$APP_NAME = { workspace = true }" pyproject.toml

                  echo "Adding $APP_NAME to sites/apps.txt..."
                  # Add to apps.txt if not already present
                  if ! grep -q "^$APP_NAME$" sites/apps.txt; then
                    echo "" >> sites/apps.txt
                    echo "$APP_NAME" >> sites/apps.txt
                  fi

                  echo "Syncing Python dependencies..."
                  uv sync

                  echo ""
                  echo "✅ App '$APP_NAME' added successfully!"
                  echo ""
                  echo "Next steps:"
                  echo "  1. Exit this shell: exit"
                  echo "  2. Restart devenv: devenv shell"
                  echo "  3. Run: bench --site frappe.localhost migrate"
                  echo "  4. Install the app: bench --site frappe.localhost install-app $APP_NAME"
                '';

                # Restore a site from a SQL backup file
                # Usage: frappe-restore <sql-file-path> [additional-bench-restore-options]
                bench-restore.exec = ''
                  if [ -z "$1" ]; then
                    echo "Usage: frappe-restore <sql-file-path> [options]"
                    echo ""
                    echo "Restores the Frappe site from a SQL backup file."
                    echo "Database credentials are automatically provided from environment variables."
                    echo ""
                    echo "Options (passed to bench restore):"
                    echo "  --with-public-files <path>   Restore public files from tar"
                    echo "  --with-private-files <path>  Restore private files from tar"
                    echo "  --encryption-key <key>       Backup encryption key"
                    echo "  --force                      Ignore validations and warnings"
                    exit 1
                  fi

                  SQL_FILE="$1"
                  shift

                  echo "Restoring site $FRAPPE_SITE from $SQL_FILE..."
                  echo "Using database user: $FRAPPE_DB_ROOT_USERNAME"

                  exec bench --site "$FRAPPE_SITE" restore "$SQL_FILE" \
                    --db-root-username "root" \
                    --db-root-password "" \
                    "$@"
                '';

                # Update all dependencies (Python + Node)
                update-deps.exec = ''
                  echo "Updating Python dependencies..."
                  uv lock && uv sync
                  echo ""
                  echo "Updating Node dependencies..."
                  ${lib.concatStringsSep "\n" (
                    map (app: ''
                      echo "  yarn install: ${app}"
                      (cd "apps/${app}" && yarn install)
                    '') appsWithNode
                  )}
                  echo ""
                  echo "Done! Lock files updated. Commit uv.lock and yarn.lock files."
                  echo "Production containers will pick up changes on next nix build."
                '';

                # Replacement for `bench update` that works with submodule-based apps.
                #
                # Frappe bench hardcodes an `upstream` remote for all apps, but in this
                # devenv apps are git submodules whose only remote is `origin`. This script
                # replicates the pull+reset+patch+build pipeline without touching pip or
                # the read-only Nix store.
                #
                # Usage:
                #   bench-update            # pull, migrate, build
                #   bench-update --pull     # pull only (skip migrate + build)
                #   bench-update --migrate  # migrate only
                #   bench-update --build    # build only
                bench-update.exec = ''
                  set -euo pipefail

                  PULL=true
                  MIGRATE=true
                  BUILD=true

                  for arg in "$@"; do
                    case "$arg" in
                      --pull)    MIGRATE=false; BUILD=false ;;
                      --migrate) PULL=false;   BUILD=false  ;;
                      --build)   PULL=false;   MIGRATE=false;;
                      --help|-h)
                        echo "Usage: bench-update [--pull | --migrate | --build]"
                        echo ""
                        echo "  (no flags)  Pull all apps, run migrations, build assets"
                        echo "  --pull      Pull latest commits for each app only"
                        echo "  --migrate   Run DB migrations only"
                        echo "  --build     Build JS/CSS assets only"
                        exit 0 ;;
                      *) echo "Unknown flag: $arg" >&2; exit 1 ;;
                    esac
                  done

                  BENCH_ROOT="$(git rev-parse --show-toplevel)"

                  if $PULL; then
                    echo "── Pulling latest commits for all app submodules ────────────"
                    git submodule foreach --recursive '
                      # Ensure we are on a real branch (not detached HEAD)
                      branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
                        echo "  ⚠  $name: detached HEAD — skipping pull"
                        exit 0
                      }
                      echo "  → $name ($branch)"
                      git fetch --depth=1 --no-tags origin "$branch"
                      git reset --hard "origin/$branch"
                      git reflog expire --all
                      git gc --quiet --prune=all
                      find . -name "*.pyc" -delete
                    '
                    echo ""
                  fi

                  if $MIGRATE; then
                    echo "── Running migrations ───────────────────────────────────────"
                    bench --site "$FRAPPE_SITE" migrate
                    echo ""
                  fi

                  if $BUILD; then
                    echo "── Building assets ──────────────────────────────────────────"
                    bench build
                    echo ""
                  fi

                  echo "✅ bench-update complete"
                '';
              };
              # ─────────────────────────────────────────────────────────────
              # Production OCI Containers (devenv container <name> build)
              # ─────────────────────────────────────────────────────────────
              #
              # Fully declarative: benchRoot provides the complete /bench
              # directory (app source + node_modules + env + config),
              # prodPythonEnv provides the Python runtime, and
              # containerRuntimeDeps provides system libraries.
              #
              # No imperative steps at container start — all dependency
              # resolution happens at Nix build time from lock files.
              #
              # Usage:
              #   devenv container web build
              #   devenv container web copy docker-daemon:frappe/web:latest
              #   devenv container web run
              #
              # All containers expect these runtime env vars:
              #   FRAPPE_DB_HOST, FRAPPE_DB_PORT, FRAPPE_DB_TYPE
              #   FRAPPE_REDIS_CACHE, FRAPPE_REDIS_QUEUE, FRAPPE_REDIS_SOCKETIO
              #   FRAPPE_SITE (default site name)
              #
              # Site config and data should be mounted at /bench/sites/
              # ─────────────────────────────────────────────────────────────
              containers = {

                # Gunicorn WSGI server (:8000)
                web = mkFrappeContainer {
                  name = "frappe/web";
                  startupCommand = [
                    "${prodPythonEnv}/bin/gunicorn"
                    "--bind"
                    "0.0.0.0:8000"
                    "--workers"
                    "4"
                    "--max-requests"
                    "5000"
                    "--max-requests-jitter"
                    "500"
                    "--timeout"
                    "120"
                    "--preload"
                    "--graceful-timeout"
                    "30"
                    "--keep-alive"
                    "5"
                    "--access-logfile"
                    "-"
                    "--error-logfile"
                    "-"
                    "frappe.app:application"
                  ];
                };

                # Enqueues scheduled/cron jobs into Redis
                scheduler = mkFrappeContainer {
                  name = "frappe/scheduler";
                  startupCommand = [
                    "${prodPythonEnv}/bin/bench"
                    "schedule"
                  ];
                };

                # Processes background jobs from the "default" queue
                worker-default = mkFrappeContainer {
                  name = "frappe/worker-default";
                  startupCommand = [
                    "${prodPythonEnv}/bin/bench"
                    "worker"
                    "--queue"
                    "default"
                  ];
                };

                # Processes fast background jobs from the "short" queue
                worker-short = mkFrappeContainer {
                  name = "frappe/worker-short";
                  startupCommand = [
                    "${prodPythonEnv}/bin/bench"
                    "worker"
                    "--queue"
                    "short"
                  ];
                };

                # Processes heavy background jobs from the "long" queue
                worker-long = mkFrappeContainer {
                  name = "frappe/worker-long";
                  startupCommand = [
                    "${prodPythonEnv}/bin/bench"
                    "worker"
                    "--queue"
                    "long"
                  ];
                };

                # Socket.IO realtime server (:9000)
                # Node.js — bridges Redis pub/sub to WebSocket clients
                socketio = {
                  name = "frappe/socketio";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench";
                  entrypoint = [ socketioEntrypoint ];
                  startupCommand = [
                    "${pkgs.nodejs_24}/bin/node"
                    "/bench/apps/frappe/socketio.js"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "socketio-env";
                      paths = with pkgs; [
                        coreutils
                        bashInteractive
                        cacert
                        nodejs_24
                      ];
                      pathsToLink = [
                        "/bin"
                        "/lib"
                        "/share"
                        "/etc"
                      ];
                    })
                    benchRoot
                  ];
                  layers = [
                    {
                      deps = with pkgs; [
                        coreutils
                        bashInteractive
                        cacert
                        nodejs_24
                      ];
                      maxLayers = 5;
                      reproducible = true;
                    }
                    {
                      deps = [ benchRoot ];
                      maxLayers = 5;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 15;
                };

                # Nginx reverse proxy (:80)
                # Static assets, WebSocket upgrade, X-Accel-Redirect, gzip
                nginx = {
                  name = "frappe/nginx";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench";
                  entrypoint = [ nginxEntrypoint ];
                  startupCommand = [
                    "${pkgs.nginx}/bin/nginx"
                    "-c"
                    "/bench/config/nginx.conf"
                    "-g"
                    "daemon off;"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "nginx-env";
                      paths = with pkgs; [
                        coreutils
                        bashInteractive
                        nginx
                      ];
                      pathsToLink = [
                        "/bin"
                        "/lib"
                        "/share"
                        "/etc"
                      ];
                    })
                    benchRoot
                  ];
                  layers = [
                    {
                      deps = with pkgs; [
                        coreutils
                        bashInteractive
                        nginx
                      ];
                      maxLayers = 5;
                      reproducible = true;
                    }
                    {
                      deps = [ benchRoot ];
                      maxLayers = 5;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 15;
                };

                # Bench CLI — one-off commands, migrations, bench build
                # Usage: docker run --rm -v sites:/bench/sites \
                #   frappe/bench:latest bench --site X migrate
                bench = mkFrappeContainer {
                  name = "frappe/bench";
                  startupCommand = [
                    "${prodPythonEnv}/bin/bench"
                    "--help"
                  ];
                  # Node.js needed for bench build (esbuild); node_modules
                  # are already in benchRoot via mkYarnPackage — no yarn needed.
                  extraPaths = [ pkgs.nodejs_24 ];
                  extraLayerDeps = [ pkgs.nodejs_24 ];
                };

              }; # end containers
            };
        };
    });
}
