Engine_HiChord : CroneEngine {

  var <synths;
  var <reverbSynth;
  var <fxBus;
  var voiceGroup, fxGroup, drumGroup;
  var reverb_mix, gain_val, drum_gain;

  alloc {
    synths = Dictionary.new;
    reverb_mix = 0.2;
    gain_val = 0.5;
    drum_gain = 0.7;

    voiceGroup = Group.new(Crone.server.defaultGroup, \addToHead);
    drumGroup  = Group.after(voiceGroup);
    fxGroup    = Group.after(drumGroup);

    fxBus = Bus.audio(Crone.server, 2);

    // ---- CHORD VOICE (polyphonic synth) ----
    SynthDef(\hichord_voice, {
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

    // ---- DRUM: KICK ----
    // Synthesized analog kick: sine body with pitch sweep + click transient
    // vary: pitch, decay, click amount, drive
    SynthDef(\drum_kick, {
      | out=0, amp=0.8, pan=0,
        freq=52, click=0.7, decay=0.35, drive=1.2, tone=0.6 |
      var body, clickSig, env, clickEnv, pitchEnv, sig;

      // Pitch envelope: fast sweep from high to fundamental
      pitchEnv = EnvGen.ar(Env.perc(0.001, 0.07), 1) * freq * 3;
      body = SinOsc.ar(freq + pitchEnv);

      // Body envelope
      env = EnvGen.ar(Env.perc(0.005, decay, 1, -6), 1, doneAction: 2);

      // Click/transient (noise burst)
      clickEnv = EnvGen.ar(Env.perc(0.001, 0.012), 1);
      clickSig = HPF.ar(WhiteNoise.ar, 800) * clickEnv * click;

      sig = (body * env * tone) + clickSig;
      // Soft clipping for drive/warmth
      sig = (sig * drive).tanh;
      sig = Pan2.ar(sig * amp, pan);
      Out.ar(out, sig);
    }).add;

    // ---- DRUM: SNARE ----
    // Body (pitched) + noise (top) + optional ring
    // vary: tone balance, decay, pitch, noise color
    SynthDef(\drum_snare, {
      | out=0, amp=0.6, pan=0,
        freq=185, decay=0.18, noiseAmt=0.65, ring=0.4, hpFreq=1200 |
      var body, noise, bodyEnv, noiseEnv, ringEnv, sig;

      // Tonal body
      bodyEnv = EnvGen.ar(Env.perc(0.001, decay * 0.6, 1, -4), 1);
      body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.6, 0, 0.3);
      body = body * bodyEnv * (1 - noiseAmt);

      // Noise top (snare wires)
      noiseEnv = EnvGen.ar(Env.perc(0.002, decay, 1, -3), 1, doneAction: 2);
      noise = HPF.ar(WhiteNoise.ar, hpFreq);
      noise = BPF.ar(noise, 4200, 0.8) + (noise * 0.3);
      noise = noise * noiseEnv * noiseAmt;

      // Ring/resonance
      ringEnv = EnvGen.ar(Env.perc(0.001, decay * 1.5, 1, -5), 1);
      sig = body + noise + (SinOsc.ar(freq * 2.8) * ringEnv * ring * 0.15);

      sig = Pan2.ar(sig * amp, pan);
      Out.ar(out, sig);
    }).add;

    // ---- DRUM: HI-HAT (closed & open) ----
    // Square wave cluster + noise through bandpass, variable decay for open/closed
    SynthDef(\drum_hat, {
      | out=0, amp=0.4, pan=0,
        decay=0.06, hpFreq=6000, tone=0.5, open=0 |
      var metallic, noise, env, sig, decayTime;

      // Longer decay for open hat
      decayTime = Select.kr(open, [decay, decay * 6]);

      env = EnvGen.ar(Env.perc(0.001, decayTime, 1, -8), 1, doneAction: 2);

      // Metallic component: detuned square waves (classic 808 hat recipe)
      metallic = Pulse.ar(
        [205.35, 304.41, 369.64, 522.73, 540.54, 800.0] * (1 + (tone * 0.15)),
        {rrand(0.3, 0.7)}!6
      ).sum * 0.15;
      metallic = HPF.ar(metallic, 8000);

      // Noise component
      noise = HPF.ar(WhiteNoise.ar, hpFreq);

      sig = (metallic * tone) + (noise * (1 - tone * 0.5));
      sig = BPF.ar(sig, 10000, 0.5) + (sig * 0.3);
      sig = sig * env;
      sig = Pan2.ar(sig * amp, pan);
      Out.ar(out, sig);
    }).add;

    // ---- DRUM: PERCUSSION (clap / cowbell / rim) ----
    // Multi-tap noise for clap, pitched for cowbell
    SynthDef(\drum_perc, {
      | out=0, amp=0.5, pan=0,
        freq=800, decay=0.15, tone=0.5, spread=0.02, mode=0 |
      var sig, env;

      sig = Select.ar(mode.clip(0,1), [
        // mode 0: clap (multi-tap filtered noise)
        {
          var n, e;
          e = Mix.fill(4, { |i|
            EnvGen.ar(Env.perc(0.001, 0.008), TDelay.kr(Impulse.kr(0), i * spread))
          });
          n = BPF.ar(WhiteNoise.ar, 1200 + (tone * 2000), 0.6) * e;
          n = n + (BPF.ar(WhiteNoise.ar, 2600, 0.4) *
            EnvGen.ar(Env.perc(0.001, decay), 1));
          n
        }.value,
        // mode 1: cowbell (two pitched tones)
        {
          var e = EnvGen.ar(Env.perc(0.001, decay * 0.8, 1, -5), 1);
          (Pulse.ar(freq, 0.5) + Pulse.ar(freq * 1.5, 0.5)) * 0.2 * e
        }.value
      ]);

      env = EnvGen.ar(Env.perc(0.001, decay * 1.5), 1, doneAction: 2);
      sig = sig * env;
      sig = Pan2.ar(sig * amp, pan);
      Out.ar(out, sig);
    }).add;

    // ---- REVERB (shared by chords and drums) ----
    SynthDef(\hichord_reverb, {
      | in=0, out=0, mix=0.2 |
      var sig, wet;
      sig = In.ar(in, 2);
      wet = FreeVerb2.ar(sig[0], sig[1], 1.0, 0.7, 0.5);
      Out.ar(out, XFade2.ar(sig, wet, mix * 2 - 1));
    }).add;

    Crone.server.sync;

    reverbSynth = Synth(\hichord_reverb,
      [\in, fxBus.index, \out, context.out_b.index, \mix, reverb_mix],
      target: fxGroup);

    // ==== CHORD COMMANDS ====

    this.addCommand(\noteOn, "if", { |msg|
      var note = msg[1].asInteger;
      var vel  = msg[2].asFloat;
      synths[note] !? { |v| v.set(\gate, 0) };
      synths[note] = Synth(\hichord_voice, [
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

    this.addCommand(\noteKillAll, "", {
      synths.do({ |v| v.set(\gate, 0) });
      synths = Dictionary.new;
    });

    // ==== DRUM COMMANDS ====
    // Each drum command takes velocity + variation parameters
    // so every hit can sound slightly different (timbral humanization)

    // drumKick: vel(0-1), pitch_var(-1 to 1), decay_var(-1 to 1), click_var(-1 to 1)
    this.addCommand(\drumKick, "ffff", { |msg|
      var vel = msg[1].asFloat.clip(0, 1);
      var pitchVar = msg[2].asFloat;   // -1..1 mapped to freq variation
      var decayVar = msg[3].asFloat;   // -1..1 mapped to decay variation
      var clickVar = msg[4].asFloat;   // -1..1 mapped to click amount

      Synth(\drum_kick, [
        \out,   context.out_b.index,
        \amp,   vel * drum_gain,
        \pan,   rrand(-0.05, 0.05),
        \freq,  52 + (pitchVar * 8) + rrand(-1.5, 1.5),
        \click, (0.7 + (clickVar * 0.3)).clip(0, 1),
        \decay, (0.35 + (decayVar * 0.12)).clip(0.08, 0.6),
        \drive, 1.2 + rrand(-0.1, 0.2),
        \tone,  0.6 + rrand(-0.05, 0.05)
      ], target: drumGroup);
    });

    // drumSnare: vel, pitch_var, decay_var, noise_var
    this.addCommand(\drumSnare, "ffff", { |msg|
      var vel = msg[1].asFloat.clip(0, 1);
      var pitchVar = msg[2].asFloat;
      var decayVar = msg[3].asFloat;
      var noiseVar = msg[4].asFloat;

      Synth(\drum_snare, [
        \out,      context.out_b.index,
        \amp,      vel * drum_gain,
        \pan,      rrand(-0.15, 0.15),
        \freq,     185 + (pitchVar * 20) + rrand(-4, 4),
        \decay,    (0.18 + (decayVar * 0.06)).clip(0.04, 0.4),
        \noiseAmt, (0.65 + (noiseVar * 0.2)).clip(0.2, 0.95),
        \ring,     0.4 + rrand(-0.1, 0.1),
        \hpFreq,   1200 + rrand(-200, 200)
      ], target: drumGroup);
    });

    // drumHat: vel, decay_var, tone_var, open(0 or 1)
    this.addCommand(\drumHat, "fffi", { |msg|
      var vel = msg[1].asFloat.clip(0, 1);
      var decayVar = msg[2].asFloat;
      var toneVar = msg[3].asFloat;
      var open = msg[4].asInteger.clip(0, 1);

      Synth(\drum_hat, [
        \out,    context.out_b.index,
        \amp,    vel * drum_gain * 0.7,
        \pan,    rrand(-0.2, 0.2),
        \decay,  (0.06 + (decayVar * 0.03)).clip(0.02, 0.2),
        \hpFreq, 6000 + rrand(-500, 500),
        \tone,   (0.5 + (toneVar * 0.2)).clip(0.1, 0.9),
        \open,   open
      ], target: drumGroup);
    });

    // drumPerc: vel, decay_var, tone_var, mode(0=clap, 1=cowbell)
    this.addCommand(\drumPerc, "fffi", { |msg|
      var vel = msg[1].asFloat.clip(0, 1);
      var decayVar = msg[2].asFloat;
      var toneVar = msg[3].asFloat;
      var mode = msg[4].asInteger.clip(0, 1);

      Synth(\drum_perc, [
        \out,    context.out_b.index,
        \amp,    vel * drum_gain * 0.6,
        \pan,    rrand(-0.25, 0.25),
        \freq,   800 + rrand(-30, 30),
        \decay,  (0.15 + (decayVar * 0.06)).clip(0.04, 0.3),
        \tone,   (0.5 + (toneVar * 0.15)).clip(0.1, 0.9),
        \spread, 0.02 + rrand(-0.005, 0.005),
        \mode,   mode
      ], target: drumGroup);
    });

    // ==== SYNTH PARAMETER COMMANDS ====

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
    this.addCommand(\drumGain, "f", { |msg|
      drum_gain = msg[1].asFloat.clip(0.0, 1.0);
    });
    this.addCommand(\waveform, "i", { |msg|
      synths.do({ |v| v.set(\waveform, msg[1].asInteger.clip(0, 3)) });
    });
    this.addCommand(\reverb,   "f", { |msg|
      reverb_mix = msg[1].asFloat.clip(0, 1);
      reverbSynth.set(\mix, reverb_mix);
    });

    // Stub commands for compatibility
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
    drumGroup   !? { drumGroup.free };
    fxGroup     !? { fxGroup.free };
  }
}
