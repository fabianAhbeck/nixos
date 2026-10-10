# Text to speech, all local: SUPER+A reads the highlighted text aloud with
# Piper (a small neural TTS that runs faster than real time on this CPU);
# pressing it again stops. A proof of concept -- the same script could later
# call a TTS service instead of running piper here.
{ pkgs, ... }:
let
  # Official Piper voices: https://huggingface.co/rhasspy/piper-voices.
  # jenny_dioco (British English, female), picked from a listening test
  # against lessac, ryan, cori, amy, alan, alba, northern_english_male, vctk.
  # Piper looks for <voice>.onnx.json next to the model, so both go in one
  # directory.
  voiceUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/jenny_dioco/medium";
  voice = pkgs.linkFarm "piper-voice-en_GB-jenny_dioco-medium" [
    {
      name = "en_GB-jenny_dioco-medium.onnx";
      path = pkgs.fetchurl {
        url = "${voiceUrl}/en_GB-jenny_dioco-medium.onnx";
        hash = "sha256-RpxjDSCeE53TkqZr9KveSrhjkKAmnB5HtOXXzoFSawE=";
      };
    }
    {
      name = "en_GB-jenny_dioco-medium.onnx.json";
      path = pkgs.fetchurl {
        url = "${voiceUrl}/en_GB-jenny_dioco-medium.onnx.json";
        hash = "sha256-qaepOjF8mjy2Vj436wV9+e8JwGGIqKQ0Gw/LWMulTdQ=";
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
      VOICE = "${voice}/en_GB-jenny_dioco-medium.onnx";
      RATE = "22050"; # audio.sample_rate in the voice's .onnx.json
    };
    text = builtins.readFile ./scripts/speak-selection.sh;
  };
in
{
  home.packages = [ speak-selection ];
}
