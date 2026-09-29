{
  osConfig,
  lib,
  ...
}: let
  hostname = osConfig.networking.hostName;
  #pci_dev=0:0d:00.0 rx6800 # 0000:c4:00.0 igpu z13
  gpu =
    if hostname == "jupiter"
    then "0000:c4:00.0"
    else "0:0d:00.0";
in {
  # Show hud: Alt_L+X
  # Toggle logging: Alt_O
  # Toggle fps limit: Alt_L+F (0,30,60,90,120)

  home.file.".config/MangoHud/MangoHud.conf" = lib.mkIf osConfig.programs.steam.enable {
    text = ''
      #MangoHud.conf
      legacy_layout=false
      no_display
      toggle_hud=Alt_L+X
      toggle_logging=Alt_O

      fps_limit_method=late
      #offset=0

      output_folder=~/Documents
      log_duration=30
      autostart_log=0
      log_interval=100

      background_alpha=0.6
      round_corners=0
      background_alpha=0.6
      background_color=000000

      font_size=32
      text_color=FFFFFF
      position=top-left
      pci_dev=${gpu}
      table_columns=3
      gpu_text=GPU
      gpu_stats
      gpu_core_clock
      gpu_mem_clock
      gpu_temp
      gpu_power
      gpu_color=2E9762
      cpu_text=CPU
      cpu_stats

      cpu_mhz
      cpu_temp
      cpu_color=2E97CB
      vram
      vram_color=AD64C1
      ram
      ram_color=C26693
      battery
      battery_color=00FF00
      fps
      frame_timing
      frametime_color=00FF00

      toggle_fps_limit=Alt_L+F
      fps_limit=0,30,40,45,60,90,120
      show_fps_limit
    '';
  };
}
