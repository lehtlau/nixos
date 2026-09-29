{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    unityhub
    blender
    pixelorama
    krita
    dotnetCorePackages.sdk_10_0 #required by c# vscode extension
    unzip
  ];

  # amd specific
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd # AMD OpenCL via ROCm
    ];
  };
}
