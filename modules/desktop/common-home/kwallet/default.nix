{
  lib,
  pkgs,
  ...
}: let
  # KWallet's backend headers are private. Use headers from the matching
  # source release and link the packaged backend without modifying it.
  initializer = pkgs.stdenv.mkDerivation {
    pname = "kwallet-init";
    inherit (pkgs.kdePackages.kwallet) version src;
    nativeBuildInputs = [pkgs.pkg-config];
    buildInputs = with pkgs.kdePackages; [qtbase kwallet pkgs.gpgmepp];
    dontWrapQtApps = true;
    buildPhase = ''
      runHook preBuild
      printf '#define KWALLETBACKEND_EXPORT\n' > kwalletbackend_export.h
      $CXX -std=c++17 -fPIC -DHAVE_GPGMEPP \
        -I. -Isrc/runtime/kwalletbackend \
        -I${lib.getDev pkgs.kdePackages.kwallet}/include/KF6/KWallet \
        $(pkg-config --cflags Qt6Widgets) \
        ${./init.cpp} -o kwallet-init \
        ${pkgs.kdePackages.kwallet}/lib/libKF6WalletBackend.so.6 \
        $(pkg-config --libs Qt6Widgets) -lgpgmepp
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 kwallet-init "$out/bin/kwallet-init"
      runHook postInstall
    '';
  };
in {
  home.packages = [pkgs.kdePackages.kwalletmanager];

  # Activate KWallet when a Secret Service client connects before a KDE app.
  xdg.dataFile."dbus-1/services/org.freedesktop.secrets.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.secrets
    Exec=${pkgs.kdePackages.kwallet}/bin/ksecretd
  '';

  home.activation.initializeKWallet = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${initializer}/bin/kwallet-init
  '';

  xdg.configFile."kwalletrc".text = ''
    [Wallet]
    Enabled=true
    First Use=false
    Default Wallet=kdewallet
    Local Wallet=kdewallet
    Use One Wallet=true
    Use GPG=false
    Prompt on Open=false
    Leave Open=true
    Close When Idle=false
    Close on Screensaver=false
    Launch Manager=false

    [org.freedesktop.secrets]
    apiEnabled=true
  '';
}
