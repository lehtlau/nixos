# home/mullvad.nix
#
# Scripts behind the combined VPN widget (see "custom/default-vpn" in
# waybar.nix): a status readout, a connect/disconnect toggle for left click
# and a wofi settings menu for right click.
#
# Everything here is gated on the host actually running the daemon, since only
# some machines have Mullvad installed.
{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  mullvadCfg = osConfig.services.mullvad-vpn;

  # The CLI that ships with the daemon this host runs, so client and daemon
  # can never drift apart.
  mullvadPkg = mullvadCfg.package;

  # waybar re-runs custom/default-vpn on SIGRTMIN+<signal>; the number has to match
  # the "signal" key in waybar.nix.
  signal = 8;
  refreshWaybar = "pkill -RTMIN+${toString signal} waybar || true";

  # Running something outside the tunnel needs the setuid wrapper, not the
  # plain binary from the package - see security.wrappers.mullvad-exclude.
  excludeBin = "/run/wrappers/bin/mullvad-exclude";

  # Status line for waybar. Keep this cheap: it runs on every interval tick.
  waybarMullvad = pkgs.writeShellApplication {
    name = "waybar-mullvad";
    runtimeInputs = [mullvadPkg pkgs.gawk pkgs.gnugrep pkgs.gnused pkgs.jq];
    text = ''
      status="$(mullvad status -v 2>/dev/null)" || status=""

      if [ -z "$status" ]; then
        jq -nc '{text: "🔓 ?", class: "unavailable", alt: "unavailable",
                 tooltip: "Mullvad daemon is not responding"}'
        exit 0
      fi

      # "Connected to se-got-wg-001 in ...", "Blocked: ...", "Disconnected", ...
      state="$(awk '/^[[:space:]]*(Connected|Connecting|Disconnecting|Disconnected|Blocked)/ {
                      gsub(/:/, "", $1); print $1; exit
                    }' <<<"$status")"
      relay="$(grep -oE '[a-z]{2}-[a-z]{3}-(wg|ovpn)-[0-9]+' <<<"$status" | awk 'NR == 1')" || relay=""
      country="$(awk 'NR == 1 {print toupper(substr($0, 1, 2))}' <<<"$relay")"
      lockdown="$(mullvad lockdown-mode get 2>/dev/null | awk '{print $NF}')" || lockdown="?"

      case "$state" in
        Connected)
          text="🛡️ ''${country:-ON}"
          class="connected"
          ;;
        Connecting)
          text="🛡️ …"
          class="connecting"
          ;;
        Disconnecting)
          text="🔓 …"
          class="disconnecting"
          ;;
        Disconnected)
          # lockdown mode keeps traffic blocked while disconnected
          if [ "$lockdown" = "on" ]; then
            text="🔒"
            class="lockdown"
          else
            text="🔓"
            class="disconnected"
          fi
          ;;
        Blocked)
          text="🔒 !"
          class="blocked"
          ;;
        *)
          text="🔓 ?"
          class="unknown"
          ;;
      esac

      # waybar runs tooltips through pango, so the markup characters have to go
      tooltip="$(printf '%s\nLockdown mode: %s\n\nLeft click: connect / disconnect\nRight click: settings' \
                   "$status" "$lockdown" \
                 | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"

      jq -nc --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
        '{text: $text, class: $class, alt: $class, tooltip: $tooltip}'
    '';
  };

  # Left click on the widget.
  mullvadToggle = pkgs.writeShellApplication {
    name = "mullvad-toggle";
    runtimeInputs = [mullvadPkg pkgs.gawk pkgs.libnotify pkgs.procps];
    text = ''
      state="$(mullvad status 2>/dev/null | awk 'NR == 1 {print $1}')" || state=""

      case "$state" in
        "")
          notify-send -a Mullvad -u critical "Mullvad" "Daemon is not responding"
          exit 1
          ;;
        Connected* | Connecting* | Blocked*)
          mullvad disconnect >/dev/null
          notify-send -a Mullvad -i network-vpn "Mullvad" "Disconnecting"
          ;;
        *)
          mullvad connect >/dev/null
          notify-send -a Mullvad -i network-vpn "Mullvad" "Connecting"
          ;;
      esac

      # the daemon switches state asynchronously: show the new state now, then
      # again once the tunnel has had time to come up
      ${refreshWaybar}
      {
        sleep 2
        ${refreshWaybar}
      } &
    '';
  };

  # Right click on the widget: the settings menu.
  mullvadMenu = pkgs.writeShellApplication {
    name = "mullvad-menu";
    runtimeInputs = [
      mullvadPkg
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.libnotify
      pkgs.procps
      pkgs.util-linux
      pkgs.wofi
    ];
    text = ''
      ask() {
        # entries on stdin, selected entry on stdout, exit 1 when cancelled
        wofi --dmenu --insensitive --no-custom-entry --cache-file /dev/null \
          --width 640 --lines 16 --prompt "$1"
      }

      show() {
        # read-only list: text on stdin, selection ignored
        ask "$1" >/dev/null || true
      }

      notify() {
        notify-send -a Mullvad -i network-vpn "Mullvad" "$1"
      }

      refresh() {
        ${refreshWaybar}
      }

      # value behind "<label>:" on the first line that carries it
      value_of() {
        awk -v label="$1" '{
          i = index($0, label ":")
          if (i) {
            v = substr($0, i + length(label) + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            print v
            exit
          }
        }'
      }

      opposite() {
        if [ "$1" = "on" ]; then echo off; else echo on; fi
      }

      run_outside() {
        if [ ! -x ${excludeBin} ]; then
          notify "mullvad-exclude is unavailable (services.mullvad-vpn.enableExcludeWrapper)"
          return 0
        fi
        setsid -f ${excludeBin} "$@" >/dev/null 2>&1
        notify "Launched outside the VPN: $1"
      }

      # Desktop entries, so split tunnelling can be pointed at an installed app.
      # Exec lines with quoted arguments are rare enough to not bother with.
      launch_outside() {
        local dir file name exec choice cmdline
        local -a apps=() cmd=()
        local -A app_cmd=()

        for dir in \
          "$HOME/.local/share/applications" \
          "$HOME/.nix-profile/share/applications" \
          "/etc/profiles/per-user/$USER/share/applications" \
          "/run/current-system/sw/share/applications"; do
          if [ ! -d "$dir" ]; then
            continue
          fi
          for file in "$dir"/*.desktop; do
            if [ ! -f "$file" ]; then
              continue
            fi
            if grep -qx 'NoDisplay=true' "$file"; then
              continue
            fi
            name="$(awk '/^Name=/ {print substr($0, 6); exit}' "$file")"
            exec="$(awk '/^Exec=/ {print substr($0, 6); exit}' "$file")"
            # strip the %f/%U/... field codes, nothing fills them in here
            exec="''${exec//%[a-zA-Z]/}"
            if [ -z "$name" ] || [ -z "$exec" ]; then
              continue
            fi
            if [ -n "''${app_cmd[$name]:-}" ]; then
              continue
            fi
            apps+=("$name")
            app_cmd["$name"]="$exec"
          done
        done

        if [ "''${#apps[@]}" -eq 0 ]; then
          notify "No applications found"
          return 0
        fi

        choice="$(printf '%s\n' "''${apps[@]}" | sort | ask "Run outside the VPN")" || return 0
        # an empty pick would be an invalid array subscript, not a missing key
        if [ -z "$choice" ]; then
          return 0
        fi
        cmdline="''${app_cmd[$choice]:-}"
        if [ -z "$cmdline" ]; then
          return 0
        fi
        read -r -a cmd <<<"$cmdline"
        run_outside "''${cmd[@]}"
      }

      split_menu() {
        local choice
        local -a opts=(
          "🧩  Launch an app outside the VPN…"
          "🖥️  Launch a terminal outside the VPN"
          "📋  Show excluded processes"
          "🧹  Stop excluding all processes"
        )

        choice="$(printf '%s\n' "''${opts[@]}" | ask "Split tunnelling")" || return 0
        case "$choice" in
          *"Launch an app"*) launch_outside ;;
          *"Launch a terminal"*) run_outside kitty ;;
          *"Show excluded"*) mullvad split-tunnel list | show "Excluded processes" ;;
          *"Stop excluding"*)
            mullvad split-tunnel clear >/dev/null
            notify "Split tunnelling cleared"
            ;;
        esac
      }

      # Country and city entries off "mullvad relay list", which prints
      # "Sweden (se)" / "\tGothenburg (got) @ ..." / "\t\tse-got-wg-001 (...)".
      location_menu() {
        local list options display args choice
        local -a locations=() parts=()
        local -A location_args=()

        list="$(mullvad relay list 2>/dev/null)" || {
          notify "Could not read the relay list"
          return 0
        }

        options="$(awk '
          /hosted by/ { next }
          /^[^[:space:]]/ {
            if (match($0, /\([a-z][a-z]\)[[:space:]]*$/)) {
              cc = substr($0, RSTART + 1, 2)
              country = substr($0, 1, RSTART - 1)
              sub(/[[:space:]]+$/, "", country)
              print country "\t" cc
            }
            next
          }
          match($0, /\([a-z][a-z][a-z]\)/) {
            city = substr($0, 1, RSTART - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", city)
            print "    " city ", " country "\t" cc " " substr($0, RSTART + 1, 3)
          }
        ' <<<"$list")"

        locations+=("🌍  Any location (fastest)")
        location_args["🌍  Any location (fastest)"]="any"
        locations+=("📡  A specific server…")
        location_args["📡  A specific server…"]="__server"

        while IFS=$'\t' read -r display args; do
          if [ -z "$display" ] || [ -z "$args" ]; then
            continue
          fi
          locations+=("$display")
          location_args["$display"]="$args"
        done <<<"$options"

        choice="$(printf '%s\n' "''${locations[@]}" | ask "Location")" || return 0
        if [ -z "$choice" ]; then
          return 0
        fi
        args="''${location_args[$choice]:-}"
        if [ -z "$args" ]; then
          return 0
        fi

        if [ "$args" = "__server" ]; then
          choice="$(grep -oE '[a-z]{2}-[a-z]{3}-(wg|ovpn)-[0-9]+' <<<"$list" | sort -u | ask "Server")" || return 0
          if [ -z "$choice" ]; then
            return 0
          fi
          args="$choice"
        fi

        read -r -a parts <<<"$args"
        if mullvad relay set location "''${parts[@]}" >/dev/null; then
          # city entries carry the menu's indent, which a notification doesn't want
          notify "Location: ''${choice#    }"
        else
          notify "Could not set the location"
        fi
        refresh
      }

      anti_censorship_menu() {
        local modes choice
        # the daemon's own list of modes, so this survives version bumps
        modes="$(mullvad anti-censorship set mode --help 2>/dev/null \
                 | sed -n 's/.*possible values: //p' | tr -d ']' | tr ',' '\n' | tr -d ' ')" || modes=""
        if [ -z "$modes" ]; then
          modes="$(printf '%s\n' auto off wireguard-port udp2tcp shadowsocks quic lwo)"
        fi

        choice="$(printf '%s\n' "$modes" | grep -v '^$' | ask "Anti-censorship mode")" || return 0
        if [ -z "$choice" ]; then
          return 0
        fi
        mullvad anti-censorship set mode "$choice" >/dev/null
        notify "Anti-censorship mode: $choice"
        refresh
      }

      # One toggle flips one blocker, but the CLI takes the whole set at once,
      # so the others have to be passed back in unchanged.
      dns_menu() {
        local dns_raw choice label value i
        local -a items=() args=()
        local -A states=()
        local -a labels=(
          "Block ads"
          "Block trackers"
          "Block malware"
          "Block adult content"
          "Block gambling"
          "Block social media"
        )
        local -a flags=(
          --block-ads
          --block-trackers
          --block-malware
          --block-adult-content
          --block-gambling
          --block-social-media
        )

        dns_raw="$(mullvad dns get 2>/dev/null)" || return 0

        for i in "''${!labels[@]}"; do
          value="$(value_of "''${labels[$i]}" <<<"$dns_raw")"
          states["''${labels[$i]}"]="''${value:-off}"
          items+=("''${labels[$i]}: ''${value:-off}")
        done

        choice="$(printf '%s\n' "''${items[@]}" | ask "DNS content blockers")" || return 0
        if [ -z "$choice" ]; then
          return 0
        fi
        label="''${choice%%:*}"

        for i in "''${!labels[@]}"; do
          value="''${states[''${labels[$i]}]}"
          if [ "''${labels[$i]}" = "$label" ]; then
            value="$(opposite "$value")"
          fi
          if [ "$value" = "on" ]; then
            args+=("''${flags[$i]}")
          fi
        done

        # this also drops custom DNS servers, which is what the GUI does too
        mullvad dns set default "''${args[@]}" >/dev/null
        notify "DNS blockers updated"
      }

      main_menu() {
        local status_raw relay_raw tunnel_raw
        local state location multihop daita quantum ipv6
        local lockdown autoconnect lan censorship choice
        local -a entries=()
        local -A keys=()

        add() {
          entries+=("$2")
          keys["$2"]="$1"
        }

        while :; do
          status_raw="$(mullvad status -v 2>/dev/null)" || status_raw=""
          if [ -z "$status_raw" ]; then
            notify "Daemon is not responding"
            return 1
          fi
          relay_raw="$(mullvad relay get 2>/dev/null)" || relay_raw=""
          tunnel_raw="$(mullvad tunnel get 2>/dev/null)" || tunnel_raw=""
          lockdown="$(mullvad lockdown-mode get 2>/dev/null | awk '{print $NF}')" || lockdown="?"
          autoconnect="$(mullvad auto-connect get 2>/dev/null | awk '{print $NF}')" || autoconnect="?"
          lan="$(mullvad lan get 2>/dev/null | awk '{print $NF}')" || lan="?"
          censorship="$(mullvad anti-censorship get 2>/dev/null | value_of mode)" || censorship="?"

          state="$(awk 'NR == 1 {print $1}' <<<"$status_raw")"
          location="$(value_of Location <<<"$relay_raw")"
          multihop="$(value_of "Multihop state" <<<"$relay_raw")"
          daita="$(value_of DAITA <<<"$tunnel_raw")"
          quantum="$(value_of "Quantum resistance" <<<"$tunnel_raw")"
          ipv6="$(value_of IPv6 <<<"$tunnel_raw")"

          entries=()
          keys=()

          case "$state" in
            Connected* | Connecting* | Blocked*) add disconnect "🔓  Disconnect" ;;
            *) add connect "🛡️  Connect" ;;
          esac
          add reconnect "🔄  Reconnect"
          add location "🌍  Location: ''${location:-any}"
          add split "🧩  Split tunnelling (apps outside the VPN)…"
          add lockdown "🔒  Lockdown mode: $lockdown"
          add autoconnect "⚡  Auto-connect: $autoconnect"
          add lan "🏠  Local network sharing: $lan"
          add daita "🕵️  DAITA: ''${daita:-?}"
          add quantum "🔐  Quantum-resistant tunnel: ''${quantum:-?}"
          add multihop "🔗  Multihop: ''${multihop:-?}"
          add ipv6 "🌐  IPv6 in the tunnel: ''${ipv6:-?}"
          add censorship "🚧  Anti-censorship: ''${censorship:-?}"
          add dns "🛑  DNS content blockers…"
          add details "📋  Connection details"
          add account "👤  Account and devices"
          add update "♻️  Update the relay list"
          if command -v mullvad-vpn >/dev/null; then
            add gui "🖥️  Open the Mullvad app"
          fi
          add quit "✖  Close"

          choice="$(printf '%s\n' "''${entries[@]}" | ask "Mullvad")" || return 0
          if [ -z "$choice" ]; then
            return 0
          fi

          # connection actions close the menu, settings keep it open so the new
          # value is visible
          case "''${keys[$choice]:-quit}" in
            connect)
              mullvad connect >/dev/null
              notify "Connecting"
              refresh
              return 0
              ;;
            disconnect)
              mullvad disconnect >/dev/null
              notify "Disconnecting"
              refresh
              return 0
              ;;
            reconnect)
              mullvad reconnect >/dev/null
              notify "Reconnecting"
              refresh
              return 0
              ;;
            gui)
              setsid -f mullvad-vpn >/dev/null 2>&1
              return 0
              ;;
            location) location_menu ;;
            split) split_menu ;;
            dns) dns_menu ;;
            censorship) anti_censorship_menu ;;
            lockdown)
              mullvad lockdown-mode set "$(opposite "$lockdown")" >/dev/null
              refresh
              ;;
            autoconnect) mullvad auto-connect set "$(opposite "$autoconnect")" >/dev/null ;;
            lan)
              if [ "$lan" = "allow" ]; then
                mullvad lan set block >/dev/null
              else
                mullvad lan set allow >/dev/null
              fi
              ;;
            daita) mullvad tunnel set daita "$(opposite "$daita")" >/dev/null ;;
            quantum) mullvad tunnel set quantum-resistant "$(opposite "$quantum")" >/dev/null ;;
            multihop) mullvad relay set multihop "$(opposite "$multihop")" >/dev/null ;;
            ipv6) mullvad tunnel set ipv6 "$(opposite "$ipv6")" >/dev/null ;;
            details)
              {
                mullvad status -v
                echo
                mullvad relay get
                echo
                mullvad tunnel get
              } 2>&1 | show "Connection details"
              ;;
            account) mullvad account get 2>&1 | show "Account" ;;
            update)
              mullvad relay update >/dev/null
              notify "Relay list updated"
              ;;
            *) return 0 ;;
          esac
        done
      }

      main_menu
    '';
  };
in {
  config = lib.mkIf mullvadCfg.enable {
    home.packages = [
      waybarMullvad
      mullvadToggle
      mullvadMenu
    ];
  };
}
