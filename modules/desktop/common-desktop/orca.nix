{
  pkgs,
  orca,
  ...
}: let
  pname = "orca";
  version = "latest";
  src = orca.outPath;

  appimageContents = pkgs.appimageTools.extractType2 {inherit pname version src;};
in {
  networking.firewall.allowedTCPPorts = [6768];

  environment.systemPackages = [
    (pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      extraInstallCommands = ''
        install -Dm444 ${appimageContents}/orca-ide.desktop $out/share/applications/${pname}.desktop
        install -Dm444 ${appimageContents}/orca-ide.png $out/share/icons/hicolor/512x512/apps/${pname}.png
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=${pname}' \
          --replace-fail 'Icon=orca-ide' 'Icon=${pname}'
      '';
    })
  ];
}
