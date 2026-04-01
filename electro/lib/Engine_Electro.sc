// Engine_Electro: EHX Pedal Emulations for Norns
// 7 chainable effects: Big Muff Pi, Small Stone, Electric Mistress,
// Deluxe Memory Man, Freeze, Micro POG, Pitch Fork
//
// Signal chain: Input -> BigMuff -> SmallStone -> ElectricMistress ->
//               MemoryMan -> Freeze -> MicroPOG -> PitchFork -> Output

Engine_Electro : CroneEngine {
    var <groups;
    var <buses;
    var <synths;
    var <buffers;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        var server = context.server;

        // --- Buses (chain between effects) ---
        buses = Dictionary.new;
        8.do { |i| buses[i] = Bus.audio(server, 2) };
        // bus 0 = input capture output
        // bus 1 = after big muff
        // bus 2 = after small stone
        // bus 3 = after electric mistress
        // bus 4 = after memory man
        // bus 5 = after freeze
        // bus 6 = after micro pog
        // bus 7 = after pitch fork

        // --- Groups (ordered execution) ---
        groups = Dictionary.new;
        groups[\input]   = Group.new(server);
        groups[\muff]    = Group.after(groups[\input]);
        groups[\stone]   = Group.after(groups[\muff]);
        groups[\mistress]= Group.after(groups[\stone]);
        groups[\memory]  = Group.after(groups[\mistress]);
        groups[\freeze]  = Group.after(groups[\memory]);
        groups[\pog]     = Group.after(groups[\freeze]);
        groups[\pitch]   = Group.after(groups[\pog]);
        groups[\output]  = Group.after(groups[\pitch]);

        // --- FFT buffers for Freeze ---
        buffers = Dictionary.new;
        buffers[\fftL] = Buffer.alloc(server, 2048);
        buffers[\fftR] = Buffer.alloc(server, 2048);

        // =============================================
        // INPUT CAPTURE: read hardware in, write to bus 0
        // =============================================
        SynthDef(\electro_input, { |in_bus, out_bus, gain=1.0|
            var sig = In.ar(in_bus, 2) * gain;
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 1. BIG MUFF PI
        // Knobs: Volume, Tone, Sustain
        // =============================================
        SynthDef(\electro_bigmuff, { |in_bus, out_bus, bypass=1,
            volume=0.7, tone=0.5, sustain=0.6|
            var dry, sig, lp, hp;

            dry = In.ar(in_bus, 2);

            // Input boost stage
            sig = dry * (1 + (sustain * 30));

            // First clipping stage (silicon diode pair)
            sig = (sig * 3).tanh;

            // Second clipping stage
            sig = (sig * 3).tanh;

            // Passive tone control: parallel LP + HP with blend
            // Crossover at ~1kHz (Big Muff signature)
            lp = LPF.ar(sig, 1000);
            hp = HPF.ar(sig, 1000);
            sig = (lp * (1 - tone)) + (hp * tone);

            // Slight mid-scoop character
            sig = BPeakEQ.ar(sig, 800, 1.5, -3);

            // Output volume
            sig = sig * volume;
            sig = Limiter.ar(sig, 0.95);

            // Bypass crossfade
            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 2. SMALL STONE PHASER
        // Knobs: Rate. Switches: Color
        // =============================================
        SynthDef(\electro_smallstone, { |in_bus, out_bus, bypass=1,
            rate=0.5, color=0, depth=0.8|
            var dry, sig, lfo, mod, fb;
            var minFreq = 200, maxFreq = 5000;

            dry = In.ar(in_bus, 2);

            // LFO (triangle-ish shape like the original)
            lfo = LFTri.kr(rate).range(0, 1) * depth;

            // Modulation frequency for all-pass filters
            mod = lfo.linexp(0, 1, minFreq, maxFreq);

            // Feedback path for Color switch
            sig = dry + (LocalIn.ar(2) * color * 0.6);

            // 4 cascaded second-order all-pass filters
            // Each stage offset slightly for richer phasing
            sig = AllpassC.ar(sig, 0.01, (1.0 / mod).clip(0, 0.01), 0);
            sig = AllpassC.ar(sig, 0.01, (1.0 / (mod * 1.3)).clip(0, 0.01), 0);
            sig = AllpassC.ar(sig, 0.01, (1.0 / (mod * 1.7)).clip(0, 0.01), 0);
            sig = AllpassC.ar(sig, 0.01, (1.0 / (mod * 2.2)).clip(0, 0.01), 0);

            LocalOut.ar(sig);

            // Mix: wet + dry for the characteristic notches
            sig = (dry + sig) * 0.5;

            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 3. ELECTRIC MISTRESS (Flanger)
        // Knobs: Rate, Range. Switches: Filter Matrix
        // =============================================
        SynthDef(\electro_mistress, { |in_bus, out_bus, bypass=1,
            rate=0.3, range=0.7, filter_matrix=0, feedback=0.7|
            var dry, sig, delayed, lfo, delTime, fb;
            var minDel = 0.0002, maxDel = 0.005; // 0.2ms to 5ms

            dry = In.ar(in_bus, 2);

            // Slow triangle LFO (Electric Mistress has very slow sweep)
            lfo = LFTri.kr(rate).range(0, 1);

            // Range controls the sweep depth
            delTime = lfo.linlin(0, 1, minDel, minDel + ((maxDel - minDel) * range));

            // Feedback with slight filtering (BBD character)
            fb = LocalIn.ar(2);
            fb = LPF.ar(fb, 8000);

            sig = dry + (fb * feedback);

            // Modulated delay line
            delayed = DelayC.ar(sig, 0.01, delTime);

            LocalOut.ar(delayed);

            // Filter Matrix mode: removes dry signal for pure resonant flanger
            sig = Select.ar(filter_matrix,
                [(dry + delayed) * 0.5,  // Normal: dry + wet
                 delayed]                 // Filter Matrix: wet only
            );

            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 4. DELUXE MEMORY MAN (Analog Delay)
        // Knobs: Blend, Feedback, Delay
        // Switches: Chorus/Vibrato
        // =============================================
        SynthDef(\electro_memoryman, { |in_bus, out_bus, bypass=1,
            blend=0.5, fb=0.5, delayTime=0.3, chorus_vibrato=0|
            var dry, sig, delayed, fbSig, modTime, lfo;
            var maxDelay = 1.2;

            dry = In.ar(in_bus, 2);

            // BBD modulation LFO
            lfo = SinOsc.kr(1.0).range(-1, 1);

            // Chorus mode: subtle pitch modulation on delay
            // Vibrato mode: deeper modulation
            modTime = Select.kr(chorus_vibrato, [
                delayTime + (lfo * 0.0008),  // Chorus: ±0.8ms
                delayTime + (lfo * 0.003)    // Vibrato: ±3ms
            ]);
            modTime = modTime.clip(0.001, maxDelay);

            // Feedback with BBD-style low-pass degradation
            fbSig = LocalIn.ar(2);
            fbSig = LPF.ar(fbSig, 4000); // BBD bandwidth limit
            fbSig = LPF.ar(fbSig, 6000); // Gentle rolloff per repeat

            sig = dry + (fbSig * fb);

            // Main delay line
            delayed = DelayC.ar(sig, maxDelay + 0.01, modTime);

            // Slight saturation on feedback path (analog character)
            delayed = (delayed * 1.2).tanh * 0.85;

            LocalOut.ar(delayed);

            // Blend: 0 = full dry, 1 = full wet
            sig = (dry * (1 - blend)) + (delayed * blend);

            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 5. FREEZE
        // Knobs: Effect Level, Speed
        // Switches: Mode (Slow/Fast/Latch), Freeze gate
        // =============================================
        SynthDef(\electro_freeze, { |in_bus, out_bus, bypass=1,
            freeze_gate=0, effect_level=0.8, speed=0.5,
            fftBufL, fftBufR|
            var dry, sigL, sigR, chainL, chainR, frozenL, frozenR, sig;

            dry = In.ar(in_bus, 2);

            // FFT analysis
            chainL = FFT(fftBufL, dry[0], hop: 0.25);
            chainR = FFT(fftBufR, dry[1], hop: 0.25);

            // Spectral freeze (holds magnitudes when gate > 0)
            chainL = PV_MagFreeze(chainL, freeze_gate);
            chainR = PV_MagFreeze(chainR, freeze_gate);

            // Optional spectral blur/smear for evolving texture
            chainL = PV_MagSmear(chainL, (speed * 10).asInteger);
            chainR = PV_MagSmear(chainR, (speed * 10).asInteger);

            frozenL = IFFT(chainL);
            frozenR = IFFT(chainR);

            // Mix dry and frozen
            sig = [
                (dry[0] * (1 - (effect_level * freeze_gate))) + (frozenL * effect_level),
                (dry[1] * (1 - (effect_level * freeze_gate))) + (frozenR * effect_level)
            ];

            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 6. MICRO POG (Polyphonic Octave Generator)
        // Knobs: Dry, Sub Octave, Octave Up
        // =============================================
        SynthDef(\electro_micropog, { |in_bus, out_bus, bypass=1,
            dry_level=1.0, sub_level=0.0, oct_up_level=0.0|
            var dry, sub, octUp, sig;

            dry = In.ar(in_bus, 2);

            // Sub-octave via PitchShift (ratio 0.5 = one octave down)
            sub = PitchShift.ar(dry, 0.1, 0.5, 0.01, 0.01);

            // Octave up via PitchShift (ratio 2.0 = one octave up)
            octUp = PitchShift.ar(dry, 0.05, 2.0, 0.01, 0.01);

            // Mix the three signals
            sig = (dry * dry_level) + (sub * sub_level) + (octUp * oct_up_level);

            // Gentle limiter to prevent clipping from summed signals
            sig = Limiter.ar(sig, 0.95);

            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // 7. PITCH FORK
        // Knobs: Blend, Shift
        // Switches: Latch, Direction (Up/Down/Dual)
        // =============================================
        SynthDef(\electro_pitchfork, { |in_bus, out_bus, bypass=1,
            blend=0.5, shift=12, latch=0, direction=0|
            var dry, shiftedUp, shiftedDown, wet, sig;
            var ratio;

            dry = In.ar(in_bus, 2);

            // Convert semitones to pitch ratio
            ratio = 2.pow(shift / 12.0);

            shiftedUp = PitchShift.ar(dry, 0.08, ratio, 0.01, 0.01);
            shiftedDown = PitchShift.ar(dry, 0.08, ratio.reciprocal, 0.01, 0.01);

            // Direction: 0=up, 1=down, 2=dual
            wet = Select.ar(direction, [
                shiftedUp,                           // Up only
                shiftedDown,                         // Down only
                (shiftedUp + shiftedDown) * 0.5      // Dual
            ]);

            // Blend: 0 = full dry, 1 = full wet
            sig = (dry * (1 - blend)) + (wet * blend);
            sig = Limiter.ar(sig, 0.95);

            sig = Select.ar(bypass, [dry, sig]);
            Out.ar(out_bus, sig);
        }).add;

        // =============================================
        // OUTPUT: send final signal to Norns output
        // =============================================
        SynthDef(\electro_output, { |in_bus, out_bus, gain=1.0|
            var sig = In.ar(in_bus, 2) * gain;
            Out.ar(out_bus, sig);
        }).add;

        server.sync;

        // --- Instantiate the chain ---
        synths = Dictionary.new;

        // Input capture
        synths[\input] = Synth(\electro_input, [
            \in_bus, context.in_b.index,
            \out_bus, buses[0].index
        ], target: groups[\input]);

        // 1. Big Muff Pi
        synths[\muff] = Synth(\electro_bigmuff, [
            \in_bus, buses[0].index,
            \out_bus, buses[1].index,
            \bypass, 1
        ], target: groups[\muff]);

        // 2. Small Stone
        synths[\stone] = Synth(\electro_smallstone, [
            \in_bus, buses[1].index,
            \out_bus, buses[2].index,
            \bypass, 1
        ], target: groups[\stone]);

        // 3. Electric Mistress
        synths[\mistress] = Synth(\electro_mistress, [
            \in_bus, buses[2].index,
            \out_bus, buses[3].index,
            \bypass, 1
        ], target: groups[\mistress]);

        // 4. Memory Man
        synths[\memory] = Synth(\electro_memoryman, [
            \in_bus, buses[3].index,
            \out_bus, buses[4].index,
            \bypass, 1
        ], target: groups[\memory]);

        // 5. Freeze
        synths[\freeze] = Synth(\electro_freeze, [
            \in_bus, buses[4].index,
            \out_bus, buses[5].index,
            \bypass, 1,
            \fftBufL, buffers[\fftL].bufnum,
            \fftBufR, buffers[\fftR].bufnum
        ], target: groups[\freeze]);

        // 6. Micro POG
        synths[\pog] = Synth(\electro_micropog, [
            \in_bus, buses[5].index,
            \out_bus, buses[6].index,
            \bypass, 1
        ], target: groups[\pog]);

        // 7. Pitch Fork
        synths[\pitch] = Synth(\electro_pitchfork, [
            \in_bus, buses[6].index,
            \out_bus, buses[7].index,
            \bypass, 1
        ], target: groups[\pitch]);

        // Output to Norns
        synths[\output] = Synth(\electro_output, [
            \in_bus, buses[7].index,
            \out_bus, context.out_b.index
        ], target: groups[\output]);

        // === COMMANDS ===

        // -- Input --
        this.addCommand("input_gain", "f", { |msg|
            synths[\input].set(\gain, msg[1]);
        });

        // -- Big Muff Pi --
        this.addCommand("muff_bypass", "i", { |msg|
            synths[\muff].set(\bypass, msg[1]);
        });
        this.addCommand("muff_volume", "f", { |msg|
            synths[\muff].set(\volume, msg[1]);
        });
        this.addCommand("muff_tone", "f", { |msg|
            synths[\muff].set(\tone, msg[1]);
        });
        this.addCommand("muff_sustain", "f", { |msg|
            synths[\muff].set(\sustain, msg[1]);
        });

        // -- Small Stone --
        this.addCommand("stone_bypass", "i", { |msg|
            synths[\stone].set(\bypass, msg[1]);
        });
        this.addCommand("stone_rate", "f", { |msg|
            synths[\stone].set(\rate, msg[1]);
        });
        this.addCommand("stone_color", "i", { |msg|
            synths[\stone].set(\color, msg[1]);
        });
        this.addCommand("stone_depth", "f", { |msg|
            synths[\stone].set(\depth, msg[1]);
        });

        // -- Electric Mistress --
        this.addCommand("mistress_bypass", "i", { |msg|
            synths[\mistress].set(\bypass, msg[1]);
        });
        this.addCommand("mistress_rate", "f", { |msg|
            synths[\mistress].set(\rate, msg[1]);
        });
        this.addCommand("mistress_range", "f", { |msg|
            synths[\mistress].set(\range, msg[1]);
        });
        this.addCommand("mistress_filter_matrix", "i", { |msg|
            synths[\mistress].set(\filter_matrix, msg[1]);
        });
        this.addCommand("mistress_feedback", "f", { |msg|
            synths[\mistress].set(\feedback, msg[1]);
        });

        // -- Memory Man --
        this.addCommand("memory_bypass", "i", { |msg|
            synths[\memory].set(\bypass, msg[1]);
        });
        this.addCommand("memory_blend", "f", { |msg|
            synths[\memory].set(\blend, msg[1]);
        });
        this.addCommand("memory_feedback", "f", { |msg|
            synths[\memory].set(\fb, msg[1]);
        });
        this.addCommand("memory_delay", "f", { |msg|
            synths[\memory].set(\delayTime, msg[1]);
        });
        this.addCommand("memory_chorus_vibrato", "i", { |msg|
            synths[\memory].set(\chorus_vibrato, msg[1]);
        });

        // -- Freeze --
        this.addCommand("freeze_bypass", "i", { |msg|
            synths[\freeze].set(\bypass, msg[1]);
        });
        this.addCommand("freeze_gate", "i", { |msg|
            synths[\freeze].set(\freeze_gate, msg[1]);
        });
        this.addCommand("freeze_level", "f", { |msg|
            synths[\freeze].set(\effect_level, msg[1]);
        });
        this.addCommand("freeze_speed", "f", { |msg|
            synths[\freeze].set(\speed, msg[1]);
        });

        // -- Micro POG --
        this.addCommand("pog_bypass", "i", { |msg|
            synths[\pog].set(\bypass, msg[1]);
        });
        this.addCommand("pog_dry", "f", { |msg|
            synths[\pog].set(\dry_level, msg[1]);
        });
        this.addCommand("pog_sub", "f", { |msg|
            synths[\pog].set(\sub_level, msg[1]);
        });
        this.addCommand("pog_oct_up", "f", { |msg|
            synths[\pog].set(\oct_up_level, msg[1]);
        });

        // -- Pitch Fork --
        this.addCommand("pitch_bypass", "i", { |msg|
            synths[\pitch].set(\bypass, msg[1]);
        });
        this.addCommand("pitch_blend", "f", { |msg|
            synths[\pitch].set(\blend, msg[1]);
        });
        this.addCommand("pitch_shift", "f", { |msg|
            synths[\pitch].set(\shift, msg[1]);
        });
        this.addCommand("pitch_latch", "i", { |msg|
            synths[\pitch].set(\latch, msg[1]);
        });
        this.addCommand("pitch_direction", "i", { |msg|
            synths[\pitch].set(\direction, msg[1]);
        });

        // -- Master output --
        this.addCommand("output_gain", "f", { |msg|
            synths[\output].set(\gain, msg[1]);
        });
    }

    free {
        synths.do { |s| s.free };
        groups.do { |g| g.free };
        buses.do { |b| b.free };
        buffers.do { |b| b.free };
    }
}
