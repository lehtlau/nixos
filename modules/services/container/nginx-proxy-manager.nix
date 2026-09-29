_: {
  systemd.tmpfiles.rules = [
    "d /var/lib/nginx-proxy-manager/data 0755 root root -"
    "d /var/lib/nginx-proxy-manager/letsencrypt 0755 root root -"
  ];

  virtualisation.oci-containers.containers.nginx-proxy-manager = {
    serviceName = "nginx-proxy-manager";

    image = "jc21/nginx-proxy-manager:2.15.1";
    autoStart = true;

    ports = [
      "80:80"
      "443:443"
      "81:81"
      # "21:21"
    ];

    environment = {
      TZ = "Europe/Helsinki";
      # DB_SQLITE_FILE = "/data/database.sqlite";
      # DISABLE_IPV6 = "true";
    };

    volumes = [
      "/var/lib/nginx-proxy-manager/data:/data"
      "/var/lib/nginx-proxy-manager/letsencrypt:/etc/letsencrypt"
    ];

    # extraOptions = [
    #   # Uncomment if you want it on a specific docker network
    #   "--network=proxy-net"
    # ];
  };
}
