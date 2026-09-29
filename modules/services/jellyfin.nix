{pkgs, ...}: {
  # 1. enable vaapi on OS-level
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
      intel-compute-runtime-legacy1
      #intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      #vpl-gpu-rt # QSV on 11th gen or newer
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Optionally, set the environment variable

  services.jellyfin = {
    enable = true;
    hardwareAcceleration = {
      device = "/dev/dri/renderD128";
      enable = true;
      type = "qsv";
    };
  };
}
