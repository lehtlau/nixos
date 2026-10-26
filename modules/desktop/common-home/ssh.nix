{
  osConfig,
  myOptions,
  lib,
  pkgs,
  ...
}: let
  hostName = osConfig.networking.hostName;
  sshConfig = pkgs.writeText "ssh-config" ''
    Host forgejo
        HostName ${myOptions.server.lanIp}
        User forgejo
        Port 2222
        IdentitiesOnly yes
        IdentityFile ~/.ssh/${hostName}

    Host home
        HostName ${myOptions.server.lanIp}
        User ${osConfig.my.user.name}
        IdentitiesOnly yes
        IdentityFile ~/.ssh/${hostName}

    Host jupiter
        HostName 192.168.50.4
        User ${osConfig.my.user.name}
        IdentitiesOnly yes
        IdentityFile ~/.ssh/${hostName}

    Host laptop
        HostName 192.168.50.2
        User ${osConfig.my.user.name}
        IdentitiesOnly yes
        IdentityFile ~/.ssh/${hostName}

    Host *
        IdentityFile ~/.ssh/${hostName}

  '';
in {
  home.activation.installSshConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    run install -d -m 700 "$HOME/.ssh"
    if [[ -v DRY_RUN ]]; then
      run install -m 600 ${sshConfig} "$HOME/.ssh/config"
    else
      sshConfigTmp=$(mktemp "$HOME/.ssh/config.XXXXXX")
      install -m 600 ${sshConfig} "$sshConfigTmp"
      mv -fT "$sshConfigTmp" "$HOME/.ssh/config"
    fi
  '';
}
