# pulsewire
_: {
  # Sound via Pipewire (modern replacement for PulseAudio)
  services.pulseaudio.enable = false; # Disable old audio system
  security.rtkit.enable = true; # Real-time scheduling for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true; # ALSA compatibility
    alsa.support32Bit = true; # 32-bit app support
    pulse.enable = true; # PulseAudio compatibility
  };
}
