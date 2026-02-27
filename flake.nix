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
    frappe = {
      url = "github:frappe/frappe";
      flake = false;
    };
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

          # Create the virtual environment with all workspace packages
          pythonEnv = pythonSet.mkVirtualEnv "frappe-bench-env" workspace.deps.default;

          # Build PYTHONPATH from apps/ directories at Nix eval time.
          # This makes Python resolve workspace modules from local source
          # instead of the Nix store (like editable installs), so that
          # frappe.__file__ → apps/frappe/frappe/__init__.py.
          # Critical for bench build, bench watch, get_app_source_path(), etc.
          appNames = builtins.attrNames (builtins.readDir ./apps);
          appsPath = root: lib.concatMapStringsSep ":" (app: "${root}/apps/${app}") appNames;

          # ─────────────────────────────────────────────────────────
          # Production Container Infrastructure
          # ─────────────────────────────────────────────────────────
          #
          # Each Frappe production process gets a dedicated OCI
          # container built via nix2container (devenv containers).
          # All containers share the same base layer (pythonEnv +
          # runtime deps) for maximal layer deduplication, then
          # add process-specific entrypoints on top.
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
          containerEnv = [
            {
              name = "FRAPPE_BENCH_ROOT";
              value = "/bench";
            }
            {
              name = "SITES_PATH";
              value = "/bench/sites";
            }
            {
              name = "PYTHONPATH";
              value = appsPath "/bench";
            }
            {
              name = "DEV_SERVER";
              value = "0";
            }
            {
              name = "FRAPPE_ENV_TYPE";
              value = "production";
            }
            {
              name = "FRAPPE_STREAM_LOGGING";
              value = "1";
            }
            {
              name = "FRAPPE_TUNE_GC";
              value = "1";
            }
            {
              name = "SSL_CERT_FILE";
              value = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            }
            {
              name = "LD_LIBRARY_PATH";
              value = lib.makeLibraryPath [
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
              ];
            }
          ];

          # Entrypoint script that sets up the environment
          containerEntrypoint = pkgs.writeShellScript "frappe-entrypoint" ''
            set -euo pipefail

            export PATH="${pythonEnv}/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.which}/bin:$PATH"

            # Create required runtime directories
            mkdir -p /bench/sites /bench/logs /bench/config/pids

            # Symlink the Nix-built Python env to /bench/env where bench expects it
            if [ ! -e /bench/env ] || [ "$(readlink /bench/env 2>/dev/null)" != "${pythonEnv}" ]; then
              ln -sfn "${pythonEnv}" /bench/env
            fi

            cd /bench/sites
            exec "$@"
          '';

          # Node.js entrypoint for socketio
          socketioEntrypoint = pkgs.writeShellScript "socketio-entrypoint" ''
            set -euo pipefail

            export PATH="${pkgs.nodejs_24}/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin:$PATH"

            mkdir -p /bench/sites /bench/logs

            cd /bench
            exec "$@"
          '';

          # Nginx entrypoint - uses config/nginx.conf from the repo
          nginxEntrypoint = pkgs.writeShellScript "nginx-entrypoint" ''
            set -euo pipefail
            export PATH="${pkgs.nginx}/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin:$PATH"

            mkdir -p /tmp/nginx /bench/logs

            exec "$@"
          '';

        in
        {
          # Export the Python environment as a package
          packages.pythonEnv = pythonEnv;

          devenv.shells.default =
            { config, pkgs, ... }:
            {
              dotenv.enable = true;

              # ─────────────────────────────────────────────────────────────
              # Packages
              # ─────────────────────────────────────────────────────────────
              packages = with pkgs; [
                # The uv2nix-built Python environment with all Frappe apps
                pythonEnv

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
              # Python is provided via the pythonEnv package above
              # which contains all dependencies from uv.lock

              # ─────────────────────────────────────────────────────────────
              # Node.js Environment (for frontend builds and socketio)
              # ─────────────────────────────────────────────────────────────
              languages.javascript = {
                enable = true;
                package = pkgs.nodejs_24;
                yarn = {
                  enable = true;
                  install.enable = false; # Per-app install in enterShell instead
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

                # Prevent uv from creating a .venv in the project root.
                # Point at a writable disposable dir (env/ is a read-only Nix store symlink).
                UV_PROJECT_ENVIRONMENT = config.env.DEVENV_STATE + "/uv-env";

                # PYTHONPATH: local apps override Nix store site-packages
                # Makes Python resolve workspace modules from apps/ source
                # instead of the Nix store (like editable installs).
                PYTHONPATH = appsPath config.devenv.root;

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
                # Create required directories
                mkdir -p "$DEVENV_STATE/mariadb" "$DEVENV_STATE/sockets" logs config/pids

                # Symlink the Nix-built Python env to ./env where bench expects it
                if [ "$(readlink env 2>/dev/null)" != "${pythonEnv}" ]; then
                  ln -sfn "${pythonEnv}" env
                fi

                # Install node dependencies for each app (like bench setup requirements)
                for app_dir in apps/*/; do
                  if [ -f "$app_dir/package.json" ] && [ ! -d "$app_dir/node_modules" ]; then
                    echo "Installing node packages for $(basename $app_dir)..."
                    (cd "$app_dir" && yarn install --frozen-lockfile --check-files 2>/dev/null || yarn install)
                  fi
                done

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
                echo "   Python: ${pythonEnv}/bin/python"
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
                  exec ${pythonEnv}/bin/bench serve --port 8000
                '';

                # Frappe Scheduler
                scheduler.exec = ''
                  exec ${pythonEnv}/bin/bench schedule
                '';

                # Background Worker
                worker.exec = ''
                  exec ${pythonEnv}/bin/bench worker
                '';

                # SocketIO Server
                socketio.exec = ''
                  rm -f "$DEVENV_STATE/sockets/socketio.sock"
                  exec ${pkgs.nodejs_24}/bin/node apps/frappe/socketio.js
                '';

                # File Watcher (for development auto-rebuild)
                watch.exec = ''
                  exec ${pythonEnv}/bin/bench watch
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
                bench-console.exec = ''
                  bench --site frappe.localhost console
                '';

                bench-migrate.exec = ''
                  bench --site frappe.localhost migrate
                '';

                bench-clear-cache.exec = ''
                  bench --site frappe.localhost clear-cache
                '';

                bench-build.exec = ''
                  bench build
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
                  uv lock
                  echo "Updating Node dependencies..."
                  yarn install
                  echo "Done! Restart your shell to pick up changes."
                '';
              };

              # ─────────────────────────────────────────────────────────────
              # Production OCI Containers (devenv container <name> build)
              # ─────────────────────────────────────────────────────────────
              #
              # Each process gets a dedicated minimal container built with
              # nix2container. Layer deduplication ensures the Python env
              # and runtime deps are shared across all images.
              #
              # Usage:
              #   devenv container web build
              #   devenv container web copy docker-daemon:frappe/web:latest
              #   devenv container web run
              #
              # All containers expect these environment variables at runtime:
              #   FRAPPE_DB_HOST, FRAPPE_DB_PORT, FRAPPE_DB_TYPE
              #   FRAPPE_REDIS_CACHE, FRAPPE_REDIS_QUEUE, FRAPPE_REDIS_SOCKETIO
              #   FRAPPE_SITE (default site name)
              #
              # Site config and data should be mounted at /bench/sites/
              # ─────────────────────────────────────────────────────────────
              containers = {

                # ═══════════════════════════════════════════════════════════
                # Frappe Web Server (Gunicorn)
                # ═══════════════════════════════════════════════════════════
                # Production WSGI server with worker recycling, preloaded
                # application code, and configurable worker count.
                #
                # Exposed port: 8000
                # Mount: /bench/sites (site configs, uploaded files)
                #
                # Runtime env vars:
                #   GUNICORN_WORKERS (default: 4)
                #   GUNICORN_MAX_REQUESTS (default: 5000)
                #   GUNICORN_TIMEOUT (default: 120)
                # ═══════════════════════════════════════════════════════════
                web = {
                  name = "frappe/web";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench/sites";
                  entrypoint = [ containerEntrypoint ];
                  startupCommand = [
                    "${pythonEnv}/bin/gunicorn"
                    "--bind" "0.0.0.0:8000"
                    "--workers" "4"
                    "--max-requests" "5000"
                    "--max-requests-jitter" "500"
                    "--timeout" "120"
                    "--preload"
                    "--graceful-timeout" "30"
                    "--keep-alive" "5"
                    "--access-logfile" "-"
                    "--error-logfile" "-"
                    "frappe.app:application"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "bench-root";
                      paths = containerRuntimeDeps ++ [ pythonEnv ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    # Layer 1: Runtime system dependencies (rarely changes)
                    {
                      deps = containerRuntimeDeps;
                      maxLayers = 10;
                      reproducible = true;
                    }
                    # Layer 2: Python environment (changes on dependency updates)
                    {
                      deps = [ pythonEnv ];
                      maxLayers = 25;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 40;
                };

                # ═══════════════════════════════════════════════════════════
                # Frappe Scheduler
                # ═══════════════════════════════════════════════════════════
                # Long-running process that enqueues scheduled/cron jobs
                # into the Redis queue for workers to pick up.
                #
                # No exposed ports.
                # Mount: /bench/sites
                # ═══════════════════════════════════════════════════════════
                scheduler = {
                  name = "frappe/scheduler";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench/sites";
                  entrypoint = [ containerEntrypoint ];
                  startupCommand = [
                    "${pythonEnv}/bin/bench"
                    "schedule"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "bench-root";
                      paths = containerRuntimeDeps ++ [ pythonEnv ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    {
                      deps = containerRuntimeDeps;
                      maxLayers = 10;
                      reproducible = true;
                    }
                    {
                      deps = [ pythonEnv ];
                      maxLayers = 25;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 40;
                };

                # ═══════════════════════════════════════════════════════════
                # Default Queue Worker
                # ═══════════════════════════════════════════════════════════
                # Processes background jobs from the "default" queue.
                # This handles most standard async operations like sending
                # emails, data imports, report generation, etc.
                #
                # No exposed ports.
                # Mount: /bench/sites
                # ═══════════════════════════════════════════════════════════
                worker-default = {
                  name = "frappe/worker-default";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench/sites";
                  entrypoint = [ containerEntrypoint ];
                  startupCommand = [
                    "${pythonEnv}/bin/bench"
                    "worker"
                    "--queue" "default"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "bench-root";
                      paths = containerRuntimeDeps ++ [ pythonEnv ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    {
                      deps = containerRuntimeDeps;
                      maxLayers = 10;
                      reproducible = true;
                    }
                    {
                      deps = [ pythonEnv ];
                      maxLayers = 25;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 40;
                };

                # ═══════════════════════════════════════════════════════════
                # Short Queue Worker
                # ═══════════════════════════════════════════════════════════
                # Processes fast background jobs from the "short" queue.
                # These are lightweight tasks that should complete quickly
                # (cache invalidation, notifications, webhooks, etc.)
                #
                # No exposed ports.
                # Mount: /bench/sites
                # ═══════════════════════════════════════════════════════════
                worker-short = {
                  name = "frappe/worker-short";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench/sites";
                  entrypoint = [ containerEntrypoint ];
                  startupCommand = [
                    "${pythonEnv}/bin/bench"
                    "worker"
                    "--queue" "short"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "bench-root";
                      paths = containerRuntimeDeps ++ [ pythonEnv ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    {
                      deps = containerRuntimeDeps;
                      maxLayers = 10;
                      reproducible = true;
                    }
                    {
                      deps = [ pythonEnv ];
                      maxLayers = 25;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 40;
                };

                # ═══════════════════════════════════════════════════════════
                # Long Queue Worker
                # ═══════════════════════════════════════════════════════════
                # Processes heavy/long-running background jobs from the
                # "long" queue. BOM explosions, large data exports, bulk
                # operations, etc. Has a longer stop-wait to allow jobs
                # to complete gracefully.
                #
                # No exposed ports.
                # Mount: /bench/sites
                # ═══════════════════════════════════════════════════════════
                worker-long = {
                  name = "frappe/worker-long";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench/sites";
                  entrypoint = [ containerEntrypoint ];
                  startupCommand = [
                    "${pythonEnv}/bin/bench"
                    "worker"
                    "--queue" "long"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "bench-root";
                      paths = containerRuntimeDeps ++ [ pythonEnv ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    {
                      deps = containerRuntimeDeps;
                      maxLayers = 10;
                      reproducible = true;
                    }
                    {
                      deps = [ pythonEnv ];
                      maxLayers = 25;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 40;
                };

                # ═══════════════════════════════════════════════════════════
                # Socket.IO Realtime Server
                # ═══════════════════════════════════════════════════════════
                # Node.js server that bridges Redis pub/sub to WebSocket
                # clients for real-time events (document updates, chat,
                # progress bars, etc.)
                #
                # Exposed port: 9000
                # Mount: /bench/sites (reads common_site_config.json)
                #
                # Runtime env vars:
                #   FRAPPE_SOCKETIO_PORT (default: 9000)
                # ═══════════════════════════════════════════════════════════
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
                      name = "socketio-root";
                      paths = with pkgs; [
                        coreutils
                        bashInteractive
                        cacert
                        nodejs_24
                      ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    # Node.js runtime
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
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 10;
                };

                # ═══════════════════════════════════════════════════════════
                # Nginx Reverse Proxy
                # ═══════════════════════════════════════════════════════════
                # Production-grade reverse proxy with:
                #   - Static asset serving with cache headers
                #   - WebSocket upgrade for Socket.IO
                #   - X-Accel-Redirect for protected file downloads
                #   - Gzip compression
                #   - Security headers (HSTS, CSP, etc.)
                #
                # Exposed port: 80
                # Mount: /bench/sites (for static assets + public files)
                #
                # Runtime env vars:
                #   FRAPPE_WEB_HOST (default: web)
                #   FRAPPE_WEB_PORT (default: 8000)
                #   FRAPPE_SOCKETIO_HOST (default: socketio)
                #   FRAPPE_SOCKETIO_PORT (default: 9000)
                #   FRAPPE_DEFAULT_SITE (default: frappe.localhost)
                # ═══════════════════════════════════════════════════════════
                nginx = {
                  name = "frappe/nginx";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench";
                  entrypoint = [ nginxEntrypoint ];
                  startupCommand = [
                    "${pkgs.nginx}/bin/nginx"
                    "-c" "/bench/config/nginx.conf"
                    "-g" "daemon off;"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "nginx-root";
                      paths = with pkgs; [
                        coreutils
                        bashInteractive
                        nginx
                      ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
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
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 10;
                };

                # ═══════════════════════════════════════════════════════════
                # Bench CLI (one-off commands / migrations / init)
                # ═══════════════════════════════════════════════════════════
                # Utility container for running bench commands:
                #   bench --site <site> migrate
                #   bench --site <site> console
                #   bench --site <site> backup
                #   bench build
                #   bench new-site <site> ...
                #
                # Not a long-running service. Use with:
                #   docker run --rm -v sites:/bench/sites \
                #     frappe/bench:latest bench --site X migrate
                # ═══════════════════════════════════════════════════════════
                bench = {
                  name = "frappe/bench";
                  version = "latest";
                  registry = "docker-daemon:";
                  workingDir = "/bench/sites";
                  entrypoint = [ containerEntrypoint ];
                  startupCommand = [
                    "${pythonEnv}/bin/bench"
                    "--help"
                  ];
                  copyToRoot = [
                    (pkgs.buildEnv {
                      name = "bench-root";
                      paths = containerRuntimeDeps ++ [
                        pythonEnv
                        pkgs.nodejs_24 # needed for bench build
                        pkgs.yarn      # needed for bench build
                      ];
                      pathsToLink = [ "/bin" "/lib" "/share" "/etc" ];
                    })
                  ];
                  layers = [
                    {
                      deps = containerRuntimeDeps ++ [
                        pkgs.nodejs_24
                        pkgs.yarn
                      ];
                      maxLayers = 10;
                      reproducible = true;
                    }
                    {
                      deps = [ pythonEnv ];
                      maxLayers = 25;
                      reproducible = true;
                    }
                  ];
                  enableLayerDeduplication = true;
                  maxLayers = 40;
                };

              }; # end containers
            };
        };
    });
}
