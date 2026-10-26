{
  # Hosts that run the OpenSSH server - see my.enableSsh in flake.nix
  sshHosts = [];

  # Server address and base domain for HTTPS sites and local DNS.
  server = {
    lanIp = "192.168.1.100";
    domain = "my_domain.com";
  };

  user = {
    name = "user";
    email = "user@example.com";

    # hashedPassword = "$y$j9T$...";
    keys = [];
  };
}
