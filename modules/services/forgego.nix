_: {
  services.forgejo = {
    enable = true;
    database.type = "sqlite3";
    # Enable support for Git Large File Storage
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = "192.168.50.197";
        ROOT_URL = "http://192.168.50.197:3000/";
        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = "0.0.0.0";

        SSH_LISTEN_PORT = 2222; # internal port Forgejo's own daemon binds to
        SSH_PORT = 2222; # port advertised in clone URLs (usually same as above)
        DISABLE_SSH = false;
      };
      "repository.pull-request" = {
        DEFAULT_MERGE_STYLE = "squash";
      };
      # server = {
      #   DOMAIN = "git.example.com";
      #   # You need to specify this to remove the port from URLs in the web UI.
      #   ROOT_URL = "https://${srv.DOMAIN}/";
      #   HTTP_PORT = 3000;
      # };
      # You can temporarily allow registration to create an admin user.
      service.DISABLE_REGISTRATION = true;
      # Add support for actions, based on act: https://github.com/nektos/act
      # actions = {
      #   ENABLED = true;
      #   DEFAULT_ACTIONS_URL = "github";
      # };
      # Sending emails is completely optional
      # You can send a test email from the web UI at:
      # Profile Picture > Site Administration > Configuration >  Mailer Configuration
      # mailer = {
      #   ENABLED = true;
      #   SMTP_ADDR = "mail.example.com";
      #   FROM = "noreply@${srv.DOMAIN}";
      #   USER = "noreply@${srv.DOMAIN}";
      # };
    };
    # secrets = {
    #   mailer.PASSWD = config.age.secrets.forgejo-mailer-password.path;
    # };
  };
}
