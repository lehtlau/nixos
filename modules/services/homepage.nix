_: {
  services.homepage-dashboard = {
    enable = true;
    allowedHosts = "192.168.50.197:8082,10.88.0.1:8082";

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
              href = "http://192.168.50.197:8096";
              description = "Media server";
            };
          }
        ];
      }
      {
        "Utilities" = [
          {
            "WG easy" = {
              icon = "wireguard.png";
              href = "http://192.168.50.197:51821";
              description = "Wireguard VPN server";
            };
          }
          {
            "Nginx Proxy Manager" = {
              icon = "nginx.png";
              href = "http://192.168.50.197:81";
              description = "Nginx Proxy Manager";
            };
          }
        ];
      }
      {
        "Games" = [
          {
            "Minecraft" = {
              icon = "minecraft.png";
              href = "http://192.168.50.197:8090";
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
              href = "http://192.168.50.197:3000";
              description = "Git server";
            };
          }
        ];
      }
    ];
  };
}
