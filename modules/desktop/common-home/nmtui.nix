{pkgs, ...}: let
  # Use the terminal's Catppuccin palette: default is its Mocha base,
  # white is text, magenta is mauve, and black is a dark surface.
  colors = pkgs.writeText "nmtui-catppuccin-colors" ''
    root=white,default
    roottext=white,default
    window=white,default
    border=magenta,default
    shadow=black,black
    title=magenta,default
    label=white,default
    textbox=white,default
    acttextbox=black,magenta
    entry=white,black
    disentry=gray,black
    listbox=white,default
    actlistbox=white,black
    sellistbox=black,cyan
    actsellistbox=black,magenta
    # Newt uses button (not actbutton) for focused compact buttons.
    button=black,magenta
    actbutton=black,magenta
    compactbutton=magenta,default
    checkbox=white,default
    actcheckbox=black,magenta
    helpline=gray,default
    emptyscale=,black
    fullscale=,magenta
  '';
  # nmtui sets these extra color pairs after Newt initializes its palette.
  nmtColors = pkgs.writeText "nmtui-catppuccin-extra-colors" ''
    plainLabel=white,default
    badLabel=red,default
    disabledButton=gray,default
    textboxWithBackground=white,black
  '';
in {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "nmtui";
      text = ''
        # Scope Newt's palette to nmtui, leaving other TUI applications alone.
        unset NEWT_COLORS NMT_NEWT_COLORS
        export NEWT_COLORS_FILE=${colors}
        export NMT_NEWT_COLORS_FILE=${nmtColors}
        exec ${pkgs.networkmanager}/bin/nmtui "$@"
      '';
    })
  ];
}
