_: {
  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0755 root root -"
  ];

  virtualisation.oci-containers.containers.minecraft-server = {
    serviceName = "minecraft-server";

    image = "itzg/minecraft-server:stable";
    autoStart = false;

    environment = {
      ALLOW_CHEATS = "false";
      EULA = "TRUE";
      SERVER_NAME = "Maailma";
      TZ = "Europe/Helsinki";
      VERSION = "LATEST";
      MEMORY = "8G";
      HARDCORE = "true";
      DIFFICULTY = "3";
      WHITELIST = "Late_007";
    };

    volumes = [
      "/var/lib/minecraft:/data" # Persistent data directory on host
    ];

    ports = ["25565:25565"];
  };
}
# sudo systemctl start minecraft-server.service
# sudo systemctl stop minecraft-server.service

