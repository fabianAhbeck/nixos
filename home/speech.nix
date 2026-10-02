# Text to speech, all local: SUPER+A reads the highlighted text aloud with
# Piper (a small neural TTS that runs faster than real time on this CPU);
# pressing it again stops. A proof of concept -- the same script could later
# call a TTS service instead of running piper here.
{ pkgs, ... }:
let
  # Official Piper voices: https://huggingface.co/rhasspy/piper-voices.
  # Piper looks for <voice>.onnx.json next to the model, so both go in one
  # directory.
  voiceUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium";
  voice = pkgs.linkFarm "piper-voice-en_US-lessac-medium" [
    {
      name = "en_US-lessac-medium.onnx";
      path = pkgs.fetchurl {
        url = "${voiceUrl}/en_US-lessac-medium.onnx";
        hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
      };
    }
    {
      name = "en_US-lessac-medium.onnx.json";
      path = pkgs.fetchurl {
        url = "${voiceUrl}/en_US-lessac-medium.onnx.json";
        hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
      };
    }
  ];

  speak-selection = pkgs.writeShellApplication {
    name = "speak-selection";
    runtimeInputs = with pkgs; [
      piper-tts
      pipewire # pw-cat
      wl-clipboard
      libnotify
      util-linux # setsid
    ];
    runtimeEnv = {
      VOICE = "${voice}/en_US-lessac-medium.onnx";
      RATE = "22050"; # audio.sample_rate in the voice's .onnx.json
    };
    text = builtins.readFile ./scripts/speak-selection.sh;
  };
in
{
  home.packages = [ speak-selection ];
}
