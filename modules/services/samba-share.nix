{config, ...}: {
  services.samba = {
    enable = true;
    #openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "nix samba";
        "netbios name" = "nix samba";
        "security" = "user";
        "use sendfile" = "yes";
        "min protocol" = "smb2";
        # note: localhost is the ipv6 localhost ::1
        "hosts allow" = "192.168.50.0/24 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      "media" = {
        "path" = "/mnt/media";
        "browseable" = "yes";
        "guest ok" = "yes"; # allow unauthenticated connections
        "read only" = "yes"; # default: guests (and anyone unlisted) get read-only
        "write list" = config.my.user.name; # authenticated user(s) allowed to write # ❯ sudo smbpasswd -a <user>
        "create mask" = "0644";
        "directory mask" = "0755";
      };
      homes = {
        "browseable" = "no"; # don't list other users' homes
        "read only" = "no";
        "valid users" = "%S"; # only the matching user can access their own share
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    #openFirewall = true;
  };
}
