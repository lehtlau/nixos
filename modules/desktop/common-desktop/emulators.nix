{
  pkgs,
  pkgs-unstable,
  ...
}: {
  programs.appimage.enable = true;

  environment.systemPackages =
    (with pkgs; [
      #dolphin-emu
      pcsx2
      eden
      rpcs3
      steam-rom-manager

      (
        let
          version = "v0.1-11295";

          src = fetchurl {
            url = "https://github.com/stenzek/duckstation/releases/download/${version}/DuckStation-x64.AppImage";
            hash = "sha256:b35fc76bb3cace5278aff1993593eed3cef21c960c33a5d95aee5251126e87e1";
          };
        in
          writeShellScriptBin "duckstation-qt" ''
            exec ${appimage-run}/bin/appimage-run ${src} "$@"
          ''
      )
    ])
    ++ (with pkgs-unstable; [
      ]);
}
