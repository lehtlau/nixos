_: {
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "3h";
    jails.sshd.settings = {
      backend = "systemd";
      mode = "aggressive";
    };
    ignoreIP = [
      "192.168.50.142"
    ];
  };
}
