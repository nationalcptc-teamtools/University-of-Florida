{
  description = "Play asciinema .cast recordings in a web browser";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        system: pkgs:
        let
          castserve = pkgs.writeShellScriptBin "castserve" ''
            set -euo pipefail

            export PATH="${pkgs.curl}/bin:${pkgs.python3}/bin:${pkgs.coreutils}/bin:$PATH"

            # asciinema player version pulled from npm on first run (then cached)
            player_version="3.17.0"

            usage() {
              cat <<'EOF'
            castserve - play asciinema .cast recordings in your browser

            Usage:
              castserve [options] RECORDING.cast [RECORDING.cast ...]

            Options:
              -p, --port PORT   port to listen on (default: 8000, 0 = any free port)
              -n, --no-open     do not open a browser window
              -h, --help        show this help

            The recordings are copied into a temporary directory together with the
            asciinema web player and served over http://127.0.0.1:<port>/.
            Press Ctrl-C to stop the server.

            Environment:
              CASTSERVE_CACHE       where to cache the player assets
                                    (default: ${"$"}{XDG_CACHE_HOME:-$HOME/.cache}/asciinema-player)
              CASTSERVE_PLAYER_DIR  use already-downloaded player assets from this
                                    directory instead of downloading (works offline)
            EOF
            }

            port=8000
            open_browser=1
            files=()

            while [ "$#" -gt 0 ]; do
              case "$1" in
                -p|--port)
                  if [ "$#" -lt 2 ]; then
                    echo "castserve: --port needs a value" >&2
                    exit 2
                  fi
                  port="$2"
                  shift 2
                  ;;
                -n|--no-open)
                  open_browser=0
                  shift
                  ;;
                -h|--help)
                  usage
                  exit 0
                  ;;
                --)
                  shift
                  while [ "$#" -gt 0 ]; do files+=("$1"); shift; done
                  ;;
                -*)
                  echo "castserve: unknown option: $1" >&2
                  usage >&2
                  exit 2
                  ;;
                *)
                  files+=("$1")
                  shift
                  ;;
              esac
            done

            if [ "''${#files[@]}" -eq 0 ]; then
              usage >&2
              exit 2
            fi

            for f in "''${files[@]}"; do
              if [ ! -f "$f" ]; then
                echo "castserve: no such file: $f" >&2
                exit 1
              fi
            done

            site=$(mktemp -d "''${TMPDIR:-/tmp}/castserve.XXXXXXXX")
            trap 'rm -rf "$site"' EXIT INT TERM

            # ---------- player assets ----------
            if [ -n "''${CASTSERVE_PLAYER_DIR:-}" ]; then
              cp "$CASTSERVE_PLAYER_DIR"/* "$site"/
            else
              cache="''${CASTSERVE_CACHE:-''${XDG_CACHE_HOME:-$HOME/.cache}/asciinema-player}/$player_version"

              if [ ! -f "$cache/asciinema-player.min.js" ]; then
                echo "castserve: downloading asciinema player $player_version..." >&2
                mkdir -p "$cache"
                stage=$(mktemp -d "''${TMPDIR:-/tmp}/castserve-fetch.XXXXXXXX")
                if ! curl -fsSL \
                  "https://registry.npmjs.org/asciinema-player/-/asciinema-player-$player_version.tgz" \
                  | tar -xz -C "$stage" --strip-components=3 package/dist/bundle; then
                  rm -rf "$stage"
                  echo "castserve: could not download the player (offline?)." >&2
                  echo "castserve: set CASTSERVE_PLAYER_DIR to a directory with the bundle files." >&2
                  exit 1
                fi
                cp "$stage"/* "$cache"/
                rm -rf "$stage"
              fi

              cp "$cache"/* "$site"/
            fi

            # ---------- recordings ----------
            cast_names=()
            for f in "''${files[@]}"; do
              base=$(basename "$f")
              name="$base"
              n=1
              while [ -e "$site/$name" ]; do
                n=$((n + 1))
                name="$n-$base"
              done
              cp "$f" "$site/$name"
              cast_names+=("$name")
            done

            python3 - "$site/casts.json" "''${cast_names[@]}" <<'PY'
            import json, sys
            with open(sys.argv[1], "w", encoding="utf-8") as fh:
                json.dump(sys.argv[2:], fh, indent=1)
            PY

            # ---------- page ----------
            cat > "$site/index.html" <<'HTML'
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>asciinema recordings</title>
              <link rel="stylesheet" type="text/css" href="asciinema-player.css">
              <style>
                :root { color-scheme: dark; }
                body {
                  margin: 0;
                  padding: 1.5rem;
                  background: #101114;
                  color: #e8e8e8;
                  font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
                }
                main { max-width: 1100px; margin: 0 auto; }
                h1 { font-size: 1rem; font-weight: 600; letter-spacing: 0.02em; opacity: 0.65; margin: 0 0 1.5rem; }
                h2 { font-size: 0.9rem; font-weight: 500; margin: 2rem 0 0.5rem; opacity: 0.8;
                     font-family: ui-monospace, SFMono-Regular, Menlo, monospace; word-break: break-all; }
                h2:first-child { margin-top: 0; }
                .player { border-radius: 0.5rem; overflow: hidden; }
              </style>
            </head>
            <body>
              <main>
                <h1>asciinema recordings</h1>
                <div id="casts"></div>
              </main>
              <script src="asciinema-player.min.js"></script>
              <script>
                // @license magnet:?xt=urn:btih:8e4f440f4c65981c5bf93c76d35135ba5064d8b7&dn=apache-2.0.txt Apache-2.0
                const root = document.getElementById("casts");

                fetch("casts.json")
                  .then(function (response) { return response.json(); })
                  .then(function (casts) {
                    if (casts.length === 0) {
                      root.textContent = "No recordings to show.";
                      return;
                    }

                    for (const name of casts) {
                      if (casts.length > 1) {
                        const heading = document.createElement("h2");
                        heading.textContent = name;
                        root.append(heading);
                      }

                      const container = document.createElement("div");
                      container.className = "player";
                      root.append(container);

                      AsciinemaPlayer.create(name, container, {
                        fit: "width",
                        loop: false,
                        autoplay: casts.length === 1,
                        idleTimeLimit: 3
                      });
                    }
                  })
                  .catch(function (error) {
                    root.textContent = "Failed to load casts.json: " + error;
                  });
                // @license-end
              </script>
            </body>
            </html>
            HTML

            # ---------- serve ----------
            requested="$port"
            port=$(python3 - "$port" <<'PY'
            import socket, sys

            want = int(sys.argv[1])
            for candidate in (want, 0):
                sock = socket.socket()
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                try:
                    sock.bind(("127.0.0.1", candidate))
                except OSError:
                    sock.close()
                    continue
                print(sock.getsockname()[1])
                sock.close()
                break
            PY
            )

            if [ "$port" != "$requested" ]; then
              echo "castserve: port $requested is busy, using $port instead" >&2
            fi

            url="http://127.0.0.1:$port/"
            echo "castserve: serving ''${#cast_names[@]} recording(s) at $url" >&2
            echo "castserve: press Ctrl-C to stop" >&2

            if [ "$open_browser" -eq 1 ]; then
              if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$url" >/dev/null 2>&1 || true
              elif command -v open >/dev/null 2>&1; then
                open "$url" >/dev/null 2>&1 || true
              fi
            fi

            python3 -m http.server "$port" --bind 127.0.0.1 --directory "$site"
          '';
        in
        {
          inherit castserve;
          default = castserve;
        }
      );

      apps = forAllSystems (
        system: pkgs: {
          default = {
            type = "app";
            program = "${self.packages.${system}.castserve}/bin/castserve";
          };
          castserve = {
            type = "app";
            program = "${self.packages.${system}.castserve}/bin/castserve";
          };
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.asciinema # asciinema rec / play / cat
              pkgs.curl # player download
              pkgs.python3 # static file server
              self.packages.${system}.castserve
            ];

            shellHook = ''
              echo "castserve: play a recording ->  castserve demo.cast"
              echo "castserve: record a new one  ->  asciinema rec demo.cast"
            '';
          };
        }
      );
    };
}

