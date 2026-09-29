{osConfig, ...}: let
  hostName = osConfig.networking.hostName;
in {
  home.file.".ssh/config".text = ''
    Host forgejo
        HostName 192.168.50.197
        User forgejo
        Port 2222
        IdentitiesOnly yes
        IdentityFile ~/.ssh/${hostName}


    Host home
        HostName 192.168.50.197
        User ${osConfig.my.user.name}
        IdentitiesOnly yes
        IdentityFile ~/.ssh/${hostName}

    Host *
        IdentityFile ~/.ssh/${hostName}

  '';
}
