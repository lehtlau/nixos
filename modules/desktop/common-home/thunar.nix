_: {
  home.file.".local/share/xfce4/helpers/kitty.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Encoding=UTF-8
    Type=X-XFCE-Helper
    X-XFCE-Category=TerminalEmulator
    Name=Kitty
    TryExec=kitty
    Icon=utilities-terminal
    Exec=kitty
    X-XFCE-CommandsWithParameter=kitty %s
  '';

  xdg.configFile."xfce4/helpers.rc".text = ''
    TerminalEmulator=kitty
  '';
}
