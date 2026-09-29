{
  description = "yoink";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Pinned to the last commit before podman 5.8.6 -> 5.8.7, which shipped a
    # buildah copier regression that rejects copies crossing in-container
    # absolute symlinks (e.g. Debian/Ubuntu's /var/run -> /run). That breaks
    # every Forgejo Actions job at actions/checkout. Remove once upstream
    # ships a fixed release (tracking containers/buildah#7129).
    nixpkgs-podman-fix.url = "github:nixos/nixpkgs/8f5d16d9258bf925d810fb595b95c1d8ac3cf104";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix/c1dc9a10164c6ff987fb70570bd9ba58f192b8bf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-podman-fix,
    home-manager,
    catppuccin,
    ...
  }: let
    system = "x86_64-linux";
    theme = import ./modules/desktop/hyprland/theme.nix;
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    podman-5-8-6 = (import nixpkgs-podman-fix {inherit system;}).podman;

    mkNixosSystem = {hostName}:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            theme
            pkgs-unstable
            catppuccin
            podman-5-8-6
            ;
        };
        modules = [
          ({lib, ...}: {
            options.my.user = {
              name = lib.mkOption {
                type = lib.types.str;
                example = "John Doe";
              };

              email = lib.mkOption {
                type = lib.types.str;
                example = "John.Doe@mail.net";
              };
              keys = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                example = ["ssh-ed25519 ASSDF... John@doe.com"];
                default = [];
              };
            };

            options.my.sddm = {
              autologin = lib.mkEnableOption "SDDM autologin";

              defaultSession = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "plasma.desktop | hyprland.desktop";
                description = "Default SDDM session.";
              };
            };
          })
          ./hosts/${hostName}/configuration.nix
          {
            nixpkgs.config.allowUnfree = true;
          }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };

    hostConfigs = builtins.listToAttrs (
      map
      (hostName: {
        name = hostName;
        value = mkNixosSystem {inherit hostName;};
      })
      [
        "laptop"
        "gmk"
        "server"
        "jupiter"
      ]
    );
  in {
    nixosConfigurations = hostConfigs;
  };
}
