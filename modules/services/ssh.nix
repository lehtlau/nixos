{
  config,
  myOptions,
  ...
}: {
  services.openssh = {
    enable = config.my.enableSsh;
    openFirewall = true;
    settings = {
      PasswordAuthentication = myOptions.sshPasswordLogin or false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [config.my.user.name];
      MaxAuthTries = 3;
      PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
    };
  };
}
