{
  config,
  pkgs,
  ...
}: let
  # Match the compositor actually running the session (pkgs-unstable), not the
  # stable hyprctl, so `hyprctl` and Hyprland agree on the IPC format.
  hyprctl = "${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl";
  hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
  loginctl = "${pkgs.systemd}/bin/loginctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  pidof = "${pkgs.procps}/bin/pidof";
in {
  # Suspend after 30 minutes idle, locking through the sleep hook below.
  # Waybar's idle inhibitor pauses the timer while "Awake" is on.
  #
  # Why hypridle rather than a systemd unit ordered before sleep.target: the
  # user systemd manager on this system has no sleep.target at all
  # (LoadState=not-found), so a `WantedBy = ["sleep.target"]` user unit would
  # silently never run. hypridle instead watches logind's PrepareForSleep on
  # the system bus, which fires for suspend, hibernate and hybrid-sleep alike.
  #
  # It also takes a logind *delay* inhibitor, so the machine waits for the lock
  # instead of racing it. That waiting is gated by general:inhibit_sleep, which
  # defaults to 2 ("auto"): auto only upgrades to "wait until the compositor
  # reports the session locked" when before_sleep_cmd mentions `lock-session`
  # and lock_cmd mentions `hyprlock`. Both spellings below are load-bearing --
  # inlining hyprlock into before_sleep_cmd instead would still work, but
  # routing through logind means `loginctl lock-session` from anywhere (the
  # keybind, wlogout, another agent) takes the exact same path.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = "${loginctl} lock-session";
        # the panel comes back off after resume unless it is explicitly poked
        after_sleep_cmd = "${hyprctl} dispatch dpms on";
        # guard against stacking instances when several triggers overlap
        lock_cmd = "${pidof} hyprlock || ${hyprlock}";
        ignore_wayland_inhibit = false;
      };
      listener = [
        {
          timeout = 1800;
          on-timeout = "${systemctl} suspend";
        }
      ];
    };
  };
}
