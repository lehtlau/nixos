{pkgs-unstable, ...}: {
  # Firefox Configuration
  programs.firefox = {
    enable = true;
    package = pkgs-unstable.firefox;
    configPath = ".mozilla/firefox"; # pin the pre-26.05 default; new default is under XDG_CONFIG_HOME

    profiles.default = {
      isDefault = true;
      settings = {
        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";

        # Privacy and security settings to match Brave's defaults
        "privacy.trackingprotection.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.cryptomining.enabled" = true;
        "privacy.trackingprotection.fingerprinting.enabled" = true;

        # Disable telemetry to match Brave's privacy focus
        "datareporting.healthreport.uploadEnabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;

        # Set DuckDuckGo as default search engine
        "browser.search.defaultenginename" = "google";
        "browser.urlbar.placeholderName" = "google";

        # Performance optimizations
        "browser.sessionstore.interval" = 15000;
        "browser.cache.disk.enable" = false;
        "browser.cache.memory.enable" = true;
        "browser.cache.memory.capacity" = 204800;
      };

      search = {
        default = "google";
        force = true;
      };

      extensions = {
        force = true; # Acknowledge that this will override all previous extensions settings
      };

      bookmarks = {
        force = true;
        settings = [
          {
            name = "Toolbar";
            toolbar = true;
            bookmarks = [
              {
                name = "";
                url = "https://youtube.com";
              }
              {
                name = "";
                url = "https://mail.google.com/mail/u/0/#inbox";
              }
              {
                name = "";
                url = "https://www.google.com/maps";
              }
              {
                name = "";
                url = "https://x.com/home";
              }
              {
                name = "";
                url = "https://mail.proton.me";
              }
              {
                name = "";
                url = "https://claude.ai/new";
              }
              {
                name = "";
                url = "http://192.168.50.197:8082/#/";
              }
            ];
          }
          {
            toolbar = true;
            bookmarks = [
              {
                name = "📁";

                bookmarks = [
                  {
                    name = "yle areena";
                    tags = [
                      "areena"
                      "yle"
                    ];
                    keyword = "yle";
                    url = "https://areena.yle.fi/tv";
                  }
                  {
                    name = "router";
                    tags = [
                      "modem"
                      "router"
                    ];
                    keyword = "router";
                    url = "http://www.asusrouter.com/Main_Login.asp";
                  }
                  {
                    name = "reittiopas";
                    tags = [
                      "waltti"
                    ];
                    keyword = "waltti";
                    url = "https://reittiopas.osl.fi/??";
                  }
                  {
                    name = "nixos.dev";
                    tags = [
                      "nix"
                      "nixos"
                    ];
                    keyword = "nix.dev";
                    url = "https://nix.dev/index.html";
                  }
                  {
                    name = "nixos options";
                    tags = [
                      "nix"
                      "nixos"
                    ];
                    keyword = "nix";
                    url = "https://search.nixos.org/";
                  }
                ];
              }
            ];
          }
        ];
      };
    };

    policies = {
      "FirefoxHome" = {
        "Search" = false;
        "TopSites" = false;
        "SponsoredTopSites" = false;
      };
      "Homepage" = {
        "StartPage" = "none";
      };
      "DisableFirefoxAccounts" = false;

      "FirefoxSuggest" = {
        "WebSuggestions" = false;
        "SponsoredSuggestions" = false;
        "ImproveSuggest" = false;
      };

      "GenerativeAI" = {
        "Enabled" = false;
        "Chatbot" = false;
      };

      "SearchEngines" = {
        "Default" = "google"; # ddg
        "PreventInstalls" = false;
      };

      # Privacy-focused policy settings to match Brave
      "DisableTelemetry" = true;
      "DisableFirefoxStudies" = true;
      "DisablePocket" = true;

      # Security settings
      "DisablePasswordReveal" = true;
      "PasswordManagerEnabled" = false;

      # Extension management
      "ExtensionSettings" = {
        "uBlock0@raymondhill.net" = {
          "install_url" = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          "installation_mode" = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

  # Brave Browser Configuration
  # Create a wrapper script that launches Brave with dark mode flags
  home.packages = [
    pkgs-unstable.brave-origin
    pkgs-unstable.brave
  ];
}
