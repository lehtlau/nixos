{
  lib,
  myOptions,
  ...
}: let
  domain = myOptions.server.domain;
  backends = {
    photos = 2283;
    media = 8096;
    git = 3000;
    home = 8082;
    minecraft = 8090;
    vpn = 51821;
  };
in {
  # A single wildcard avoids competing DuckDNS TXT challenges.
  security.acme = {
    acceptTerms = true;
    defaults.email = myOptions.user.email;
    certs.${domain} = {
      domain = "*.${domain}";
      dnsProvider = "duckdns";
      dnsResolver = "1.1.1.1:53";
      credentialFiles.DUCKDNS_TOKEN_FILE = "/etc/nixos-secrets/duckdns-token";
      group = "caddy";
      reloadServices = ["caddy.service"];
    };
  };

  services.caddy = {
    enable = true;
    openFirewall = false; # LAN/VPN access is defined in firewall/server.nix.
    virtualHosts = lib.mapAttrs' (name: port:
      lib.nameValuePair "${name}.${domain}" {
        useACMEHost = domain;
        extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
      })
    backends;
  };
}
