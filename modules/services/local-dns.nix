{myOptions, ...}: {
  # DNS only; keep DHCP on the router and advertise server.lanIp as DNS.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      listen-address = ["127.0.0.1" myOptions.server.lanIp];
      bind-dynamic = true;
      no-resolv = true;
      server = ["8.8.8.8" "8.8.4.4"];
      domain-needed = true;
      bogus-priv = true;
      # Keep AAAA and other queries local too, avoiding public WAN answers.
      # ACME uses a public DNS resolver directly.
      local = "/${myOptions.server.domain}/";
      address = "/${myOptions.server.domain}/${myOptions.server.lanIp}";
      cache-size = 1000;
    };
  };
}
