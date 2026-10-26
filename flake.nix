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

    hermes-agent.url = "github:NousResearch/hermes-agent";

    orca = {
      url = "file+https://github.com/stablyai/orca/releases/latest/download/orca-linux.AppImage";
      flake = false;
    };

    duckstation = {
      url = "file+https://github.com/stenzek/duckstation/releases/latest/download/DuckStation-x64.AppImage";
      flake = false;
    };

    hypr-monitors = {
      url = "git+https://github.com/lehtlau/hypr-monitors.git";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-podman-fix,
    home-manager,
    catppuccin,
    hypr-monitors,
    hermes-agent,
    orca,
    duckstation,
    ...
  }: let
    system = "x86_64-linux";

    root = self.outPath;

    myOptions = import ./options.nix;
    theme = import ./modules/desktop/hyprland/theme.nix;

    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;

      # Pulled in transitively by a VS Code extension's build (nodejs pnpm
      # packaging); not an exposed service, just a build tool.
      config.permittedInsecurePackages = ["pnpm-10.34.0"];
    };

    # Unity Hub patched to include the unstable ncurses library at runtime.
    # broken package - https://github.com/NixOS/nixpkgs/issues/561247
    unityhub-patched = pkgs-unstable.unityhub.overrideAttrs (old: {
      nativeBuildInputs =
        (old.nativeBuildInputs or [])
        ++ [pkgs-unstable.makeWrapper];

      postInstall =
        (old.postInstall or "")
        + ''
          wrapProgram $out/opt/unityhub/unityhub \
            --prefix LD_LIBRARY_PATH : "${pkgs-unstable.ncurses}/lib"
        '';
    });

    podman-5-8-6 = (import nixpkgs-podman-fix {inherit system;}).podman;
    mkNixosSystem = {hostName}:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit
            root
            myOptions
            theme
            pkgs-unstable
            unityhub-patched
            catppuccin
            hypr-monitors
            podman-5-8-6
            hermes-agent
            orca
            duckstation
            ;
        };

        modules = [
          ({lib, ...}: {
            options.my.user = {
              name = lib.mkOption {
                type = lib.types.str;
                example = "user";
              };

              email = lib.mkOption {
                type = lib.types.str;
                example = "user@example.com";
              };

              keys = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                example = ["ssh-ed25519 ASSDF... John@doe.com"];
                default = [];
              };

              hashedPassword = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "$y$j9T$...";
                description = "Password hash for the user. Ends up in the nix store, prefer hashedPasswordFile.";
              };

              hashedPasswordFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "/etc/nixos-secrets/<user>.hash";
                description = "Path to a file on the machine holding the password hash. Never read at build time.";
              };
            };

            options.my.enableSsh = lib.mkOption {
              type = lib.types.bool;
              default = builtins.elem hostName (myOptions.sshHosts or []);
              description = "Enable the OpenSSH server. True for the hosts listed in sshHosts in options.nix, overridable per host.";
            };

            options.my.sddm = {
              autologin = lib.mkEnableOption "SDDM autologin";

              defaultSession = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "plasma.desktop | hyprland.desktop";
              };
            };
          })

          ./hosts/${hostName}/configuration.nix

          {
            nixpkgs.config.allowUnfree = true;

            # Pulled in transitively by a VS Code extension's build (nodejs pnpm
            # packaging); not an exposed service, just a build tool.
            nixpkgs.config.permittedInsecurePackages = ["pnpm-10.34.0"];
          }

          home-manager.nixosModules.home-manager

          {
            home-manager.extraSpecialArgs = {inherit myOptions;};
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
        "kde-desktop"
        "mini-ai-server"
      ]
    );
  in {
    nixosConfigurations = hostConfigs;
  };
}
