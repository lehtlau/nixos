# environment.nix - User environment variables and shell configuration
_: {
  # Set session variables for user applications
  home.sessionVariables = {
    # Wayland compatibility (moved from system environment.nix for user context)
    MOZ_ENABLE_WAYLAND = "1"; # Firefox uses Wayland
    NIXOS_OZONE_WL = "1"; # Chromium/Electron use Wayland
  };
}
