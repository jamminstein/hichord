Engine_HeyChord : CroneEngine {

  var <synths;
  var <reverbSynth;
  var <fxBus;
  var voiceGroup, fxGroup;
  var reverb_mix, gain_val;

  alloc {
    synths = Dictionary.new;
    reverb_mix = 0.2;
    gain_val = 0.5;

    voiceGroup = Group.new(Crone.server.defaultGroup, \addToHead);
    fxGroup    = Group.after(voiceGroup);

    fxBus = Bus.audio(Crone.server, 2);

    SynthDef(\heychord_voice, {
      | out=0, freq=440, amp=0.5, pan=0,
        attack=0.01, decay=0.1, sustain=0.7, release=0.8,
        cutoff=3000, res=0.15, waveform=0, gate=1 |

      var sig, env;
      env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction:2);
      sig = Select.ar(waveform.clip(0,3), [
        Saw.ar(freq) + Saw.ar(freq * 1.005) * 0.5,
        SinOsc.ar(freq),
        Pulse.ar(freq, 0.5),
        LFTri.ar(freq)
      ]);
      sig = RLPF.ar(sig, cutoff.clip(80, 18000), res.clip(0.01, 0.99));
      sig = Pan2.ar(sig * env * amp, pan);
      Out.ar(out, sig);
    }).add;

    SynthDef(\heychord_reverb, {
      | in=0, out=0, mix=0.2 |
      var sig, wet;
      sig = In.ar(in, 2);
      wet = FreeVerb2.ar(sig[0], sig[1], 1.0, 0.7, 0.5);
      Out.ar(out, XFade2.ar(sig, wet, mix * 2 - 1));
    }).add;

    Crone.server.sync;

    reverbSynth = Synth(\heychord_reverb,
      [\in, fxBus.index, \out, context.out_b.index, \mix, reverb_mix],
      target: fxGroup);

    this.addCommand(\noteOn, "if", { |msg|
      var note = msg[1].asInteger;
      var vel  = msg[2].asFloat;
      synths[note] !? { |v| v.set(\gate, 0) };
      synths[note] = Synth(\heychord_voice, [
        \out,  fxBus.index,
        \freq, note.midicps,
        \amp,  vel * gain_val,
        \pan,  rrand(-0.4, 0.4),
        \gate, 1
      ], target: voiceGroup);
    });

    this.addCommand(\noteOff, "i", { |msg|
      var note = msg[1].asInteger;
      synths[note] !? { |v| v.set(\gate, 0); synths[note] = nil };
    });

    this.addCommand(\allNotesOff, "", {
      synths.do({ |v| v.set(\gate, 0) });
      synths = Dictionary.new;
    });

    this.addCommand(\attack,   "f", { |msg|
      synths.do({ |v| v.set(\attack,  msg[1].asFloat.clip(0.001, 4.0)) });
    });
    this.addCommand(\decay,    "f", { |msg|
      synths.do({ |v| v.set(\decay,   msg[1].asFloat.clip(0.001, 4.0)) });
    });
    this.addCommand(\sustain,  "f", { |msg|
      synths.do({ |v| v.set(\sustain, msg[1].asFloat.clip(0.0, 1.0)) });
    });
    this.addCommand(\release,  "f", { |msg|
      synths.do({ |v| v.set(\release, msg[1].asFloat.clip(0.01, 8.0)) });
    });
    this.addCommand(\cutoff,   "f", { |msg|
      synths.do({ |v| v.set(\cutoff,  msg[1].asFloat.clip(80, 18000)) });
    });
    this.addCommand(\res,      "f", { |msg|
      synths.do({ |v| v.set(\res,     msg[1].asFloat.clip(0.01, 0.99)) });
    });
    this.addCommand(\gain,     "f", { |msg|
      gain_val = msg[1].asFloat.clip(0.0, 1.0);
    });
    this.addCommand(\waveform, "i", { |msg|
      synths.do({ |v| v.set(\waveform, msg[1].asInteger.clip(0, 3)) });
    });
    this.addCommand(\reverb,   "f", { |msg|
      reverb_mix = msg[1].asFloat.clip(0, 1);
      reverbSynth.set(\mix, reverb_mix);
    });

    this.addCommand(\detune,   "f", {});
    this.addCommand(\fmRatio,  "f", {});
    this.addCommand(\fmIndex,  "f", {});
    this.addCommand(\glide,    "f", {});
    this.addCommand(\chorus,   "f", {});
    this.addCommand(\delay,    "f", {});
    this.addCommand(\deltime,  "f", {});
    this.addCommand(\fxSet,    "sf", {});
  }

  free {
    synths.do({ |v| v !? { v.free } });
    reverbSynth !? { reverbSynth.free };
    fxBus       !? { fxBus.free };
    voiceGroup  !? { voiceGroup.free };
    fxGroup     !? { fxGroup.free };
  }
}
