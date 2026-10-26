{myOptions, ...}: {
  services.homepage-dashboard = {
    enable = true;
    allowedHosts = "home.${myOptions.server.domain},${myOptions.server.lanIp}:8082,10.88.0.1:8082";

    # Keep DNS links by default; switch to LAN URLs when opened by LAN IP.
    # Observe rendering updates because Homepage mounts service cards dynamically.
    customJS = ''
      (() => {
        const lanIp = ${builtins.toJSON myOptions.server.lanIp};
        const domain = ${builtins.toJSON myOptions.server.domain};
        if (window.location.hostname !== lanIp) return;

        const ports = { media: 8096, photos: 2283, git: 3000, vpn: 51821, minecraft: 8090 };
        const links = new Map(Object.entries(ports).map(([name, port]) => [
          'https://' + name + '.' + domain,
          'http://' + lanIp + ':' + port
        ]));

        function updateLinks() {
          document.querySelectorAll('a[href]').forEach((anchor) => {
            const href = anchor.getAttribute('href');
            const replacement = links.get(href) || links.get(href.replace(/\/$/, ""));
            if (replacement) anchor.setAttribute('href', replacement);
          });
        }

        const observer = new MutationObserver(updateLinks);
        observer.observe(document.documentElement, {
          childList: true, subtree: true, attributes: true, attributeFilter: ['href']
        });
        updateLinks();
      })();
    '';

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
          units = "metric";
          cputemp = true;
          uptime = true;
          network = true;
          diskIO = true;
          label = "System resources";
          refresh = 100000;
        };
      }
      {
        resources = {
          label = "Media";
          disk = "/mnt/media";
          units = "metric";
          diskUnits = "GB";
          refresh = 100000;
        };
      }
    ];
    services = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              icon = "jellyfin.png";
              href = "https://media.${myOptions.server.domain}";
              description = "Media server";
            };
          }
          {
            "Immich" = {
              icon = "immich.png";
              href = "https://photos.${myOptions.server.domain}";
              description = "Photo and video backup";
            };
          }
        ];
      }
      {
        "Utilities" = [
          {
            "WG easy" = {
              icon = "wireguard.png";
              href = "https://vpn.${myOptions.server.domain}";
              description = "Wireguard VPN server";
            };
          }
        ];
      }
      {
        "Games" = [
          {
            "Minecraft" = {
              icon = "minecraft.png";
              href = "https://minecraft.${myOptions.server.domain}";
              description = "Minecraft server (click to start/stop)";
              widget = {
                type = "customapi";
                url = "http://127.0.0.1:8090/api/units/minecraft-server.service";
                refreshInterval = 10000;
                display = "block";
                mappings = [
                  {
                    field = "status";
                    label = "Status";
                    format = "text";
                  }
                  {
                    field = "uptime";
                    label = "Uptime";
                    format = "text";
                  }
                ];
              };
            };
          }
        ];
      }
      {
        "Development" = [
          {
            "Forgejo" = {
              icon = "forgejo.png";
              href = "https://git.${myOptions.server.domain}";
              description = "Git server";
            };
          }
        ];
      }
    ];
  };
}
