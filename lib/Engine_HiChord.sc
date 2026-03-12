-- Engine_HiChord.sc
-- SuperCollider engine for HiChord Norns port
-- Faithful to HiChord firmware v2.6.9 synthesis spec:
--   12-oscillator (6 stereo pairs), analog/FM/sample engines,
--   ADSR envelope, Moog filter, chorus, flanger, reverb, delay

Engine_HiChord : CroneEngine {

  var <synths;
  var <group;
  var <fxGroup;
  var <dryBus, <fxBus;
  var <chorusSynth, <flangerSynth, <reverbSynth, <delaySynth;
  var params;

  alloc {
    group   = Group.new(target: server);
    fxGroup = Group.new(target: group, addAction: \addToTail);

    dryBus = Bus.audio(server, 2);
    fxBus  = Bus.audio(server, 2);

    // ── VOICE SYNTH ──────────────────────────────────────────────────────────
    SynthDef(\hichord_voice, {
      | out=0, dry=0,
        freq=440, amp=0.4, pan=0,
        attack=0.01, decay=0.1, sustain=0.7, release=1.0,
        cutoff=2000, res=0.2, gain=1.0,
        waveform=0,
        detune=0.3,
        fmRatio=2.0, fmIndex=3.0,
        gate=1, glide=0 |

      var sig, env, filt, lagged_freq;

      lagged_freq = freq.lag(glide * 0.3);

      env = EnvGen.kr(
        Env.adsr(attack, decay, sustain, release),
        gate, doneAction: 2
      );

      // ── SYNTHESIS ENGINES ──────────────────────────────────────────
      sig = Select.ar(waveform, [
        // 0: SAW — dual detuned saws (12-osc style)
        Mix([
          Saw.ar(lagged_freq * (1 + LFNoise2.kr(0.1).range(-0.002,0.002) + (detune*0.006))),
          Saw.ar(lagged_freq * (1 - detune*0.006)),
          Saw.ar(lagged_freq * 2 * (1 + detune*0.003)) * 0.25
        ]) * 0.4,

        // 1: SINE
        SinOsc.ar(lagged_freq),

        // 2: SQUARE (pulse with slight PWM)
        Pulse.ar(lagged_freq, LFNoise1.kr(0.3).range(0.45, 0.55)),

        // 3: TRIANGLE
        LFTri.ar(lagged_freq),

        // 4: FM EPIANO (Rhodes-style 2-op)
        (SinOsc.ar(lagged_freq + SinOsc.ar(lagged_freq * fmRatio) * lagged_freq * fmIndex * 0.5)
          + SinOsc.ar(lagged_freq * 2, 0, 0.3)),

        // 5: FM HX7 (DX7-style metallic)
        SinOsc.ar(lagged_freq + SinOsc.ar(lagged_freq * fmRatio, 0, lagged_freq * fmIndex)),

        // 6: FM BELL
        SinOsc.ar(lagged_freq
          + SinOsc.ar(lagged_freq * 3.5, 0, lagged_freq * fmIndex * 0.7)
          * EnvGen.kr(Env.perc(0.001, 2.0), gate)),

        // 7: JUNO PAD — layered saws + sub + slight detune
        Mix([
          Saw.ar(lagged_freq * (1 + detune*0.01)),
          Saw.ar(lagged_freq * (1 - detune*0.01)),
          SinOsc.ar(lagged_freq * 0.5) * 0.5,   // sub oct
          Pulse.ar(lagged_freq, 0.5) * 0.15
        ]) * 0.3,

        // 8: STRINGS — ensemble (multiple detuned saws)
        Mix(Array.fill(6, { |i|
          var d = (i-3) * detune * 0.003;
          Saw.ar(lagged_freq * (1 + d))
        })) * 0.2,
      ]);

      // ── ENVELOPE ──────────────────────────────────────────────────
      sig = sig * env * gain;

      // ── FILTER (Moog-style lowpass) ────────────────────────────────
      filt = MoogFF.ar(sig, cutoff.lag(0.02).clip(20, 20000), res.clip(0,3.8));

      // ── STEREO + AMP ───────────────────────────────────────────────
      filt = Pan2.ar(filt, pan) * amp;

      Out.ar(out,  filt);       // dry out (goes to FX chain)
    }).add(server);

    // ── FX SYNTHS ────────────────────────────────────────────────────────────

    // CHORUS (Juno-style: 0.5Hz LFO, L/R slightly different rates)
    SynthDef(\hichord_chorus, {
      | in=0, out=0, mix=0.5 |
      var sig, wet_l, wet_r;
      sig = In.ar(in, 2);
      wet_l = DelayC.ar(sig[0], 0.05, LFNoise1.kr(0.50).range(0.005, 0.025));
      wet_r = DelayC.ar(sig[1], 0.05, LFNoise1.kr(0.52).range(0.005, 0.025));
      Out.ar(out, (sig * (1-mix)) + [wet_l, wet_r] * mix);
    }).add(server);

    // FLANGER (LFO-modulated comb, stereo, with feedback)
    SynthDef(\hichord_flanger, {
      | in=0, out=0, rate=0.3, depth=0.003, feedback=0.5, mix=0.5 |
      var sig, lfo_l, lfo_r, wet;
      sig   = In.ar(in, 2);
      lfo_l = LFNoise1.kr(rate).range(0.0001, depth);
      lfo_r = LFNoise1.kr(rate * 1.07).range(0.0001, depth);
      wet   = [
        DelayC.ar(sig[0] + LocalIn.ar(1)*feedback, 0.05, lfo_l),
        DelayC.ar(sig[1] + LocalIn.ar(1)*feedback, 0.05, lfo_r)
      ];
      LocalOut.ar(wet * feedback);
      Out.ar(out, (sig * (1-mix)) + (wet * mix));
    }).add(server);

    // REVERB
    SynthDef(\hichord_reverb, {
      | in=0, out=0, mix=0.3, room=0.7, damp=0.5 |
      var sig, wet;
      sig = In.ar(in, 2);
      wet = FreeVerb2.ar(sig[0], sig[1], mix, room, damp);
      Out.ar(out, sig * (1-mix) + wet * mix);
    }).add(server);

    // DELAY (tempo-synced comb)
    SynthDef(\hichord_delay, {
      | in=0, out=0, deltime=0.25, feedback=0.35, mix=0.25 |
      var sig, wet;
      sig = In.ar(in, 2);
      wet = CombC.ar(sig, 2.0, deltime, deltime * feedback * 8) * mix;
      Out.ar(out, sig + wet);
    }).add(server);

    server.sync;

    // Boot FX chain: dry → chorus → flanger → reverb → delay → out
    chorusSynth  = Synth(\hichord_chorus,  [\in, dryBus, \out, fxBus, \mix, 0], fxGroup);
    flangerSynth = Synth(\hichord_flanger, [\in, fxBus,  \out, fxBus, \mix, 0], fxGroup);
    reverbSynth  = Synth(\hichord_reverb,  [\in, fxBus,  \out, 0,     \mix, 0.3], fxGroup);
    delaySynth   = Synth(\hichord_delay,   [\in, fxBus,  \out, 0,     \mix, 0], fxGroup);

    // Parameter store
    params = Dictionary[
      \amp       -> 0.4,
      \attack    -> 0.01,
      \decay     -> 0.1,
      \sustain   -> 0.7,
      \release   -> 1.0,
      \cutoff    -> 2000,
      \res       -> 0.2,
      \gain      -> 0.8,
      \waveform  -> 0,
      \detune    -> 0.3,
      \fmRatio   -> 2.0,
      \fmIndex   -> 3.0,
      \glide     -> 0,
      \pan_spread-> 0.7,
    ];

    synths = Dictionary.new;

    // ── COMMANDS ─────────────────────────────────────────────────────────────
    this.addCommand(\noteOn, "if", { |msg|
      var midiNote = msg[1].asInteger;
      var amp      = msg[2].asFloat;
      var freq     = midiNote.midicps;
      // pan: spread voices across stereo field
      var pan  = rrand(-1*params[\pan_spread], params[\pan_spread]);
      var s;
      // release old note at same pitch if any
      if (synths[midiNote] != nil) {
        synths[midiNote].set(\gate, 0);
      };
      s = Synth(\hichord_voice, [
        \out,      dryBus,
        \freq,     freq,
        \amp,      amp,
        \pan,      pan,
        \attack,   params[\attack],
        \decay,    params[\decay],
        \sustain,  params[\sustain],
        \release,  params[\release],
        \cutoff,   params[\cutoff],
        \res,      params[\res],
        \gain,     params[\gain],
        \waveform, params[\waveform],
        \detune,   params[\detune],
        \fmRatio,  params[\fmRatio],
        \fmIndex,  params[\fmIndex],
        \glide,    params[\glide],
        \gate,     1
      ], target: group);
      synths[midiNote] = s;
    });

    this.addCommand(\noteOff, "i", { |msg|
      var midiNote = msg[1].asInteger;
      if (synths[midiNote] != nil) {
        synths[midiNote].set(\gate, 0);
        synths[midiNote] = nil;
      };
    });

    this.addCommand(\allNotesOff, "", {
      synths.do({ |s| s.set(\gate, 0) });
      synths = Dictionary.new;
    });

    // Envelope
    this.addCommand(\attack,  "f", { |msg| params[\attack]  = msg[1]; });
    this.addCommand(\decay,   "f", { |msg| params[\decay]   = msg[1]; });
    this.addCommand(\sustain, "f", { |msg| params[\sustain] = msg[1]; });
    this.addCommand(\release, "f", { |msg| params[\release] = msg[1]; });

    // Filter & gain
    this.addCommand(\cutoff,  "f", { |msg| params[\cutoff]  = msg[1]; });
    this.addCommand(\res,     "f", { |msg| params[\res]     = msg[1]; });
    this.addCommand(\gain,    "f", { |msg| params[\gain]    = msg[1]; });

    // Oscillator
    this.addCommand(\waveform,"i", { |msg| params[\waveform] = msg[1]; });
    this.addCommand(\detune,  "f", { |msg| params[\detune]   = msg[1]; });
    this.addCommand(\fmRatio, "f", { |msg| params[\fmRatio]  = msg[1]; });
    this.addCommand(\fmIndex, "f", { |msg| params[\fmIndex]  = msg[1]; });
    this.addCommand(\glide,   "f", { |msg| params[\glide]    = msg[1]; });

    // Effects
    this.addCommand(\fxSet, "si", { |msg|
      var name = msg[1].asSymbol;
      var val  = msg[2].asInteger;
      case
        { name == \reverb  } { reverbSynth.set(\mix, val * 0.35)  }
        { name == \chorus  } { chorusSynth.set(\mix, val * 0.6)   }
        { name == \flanger } { flangerSynth.set(\mix, val * 0.5)  }
        { name == \delay   } { delaySynth.set(\mix, val * 0.3)    }
        { name == \stereo  } { params[\pan_spread] = val * 0.7    };
    });

    this.addCommand(\deltime, "f", { |msg| delaySynth.set(\deltime, msg[1]); });
    this.addCommand(\revmix,  "f", { |msg| reverbSynth.set(\mix, msg[1]);   });
  }

  free {
    synths.do({ |s| s.free });
    chorusSynth.free;
    flangerSynth.free;
    reverbSynth.free;
    delaySynth.free;
    dryBus.free;
    fxBus.free;
    fxGroup.free;
    group.free;
  }
}
