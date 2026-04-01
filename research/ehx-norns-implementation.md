# Electro-Harmonix Effects on Monome Norns: Research & Implementation Guide

## Table of Contents

1. [Available EHX Source Code & Algorithms](#1-available-ehx-source-code--algorithms)
2. [Norns Platform Capabilities & Constraints](#2-norns-platform-capabilities--constraints)
3. [Implementation Feasibility by Pedal](#3-implementation-feasibility-by-pedal)
4. [Recommended Implementation Approaches](#4-recommended-implementation-approaches)
5. [Integration with HiChord](#5-integration-with-hichord)
6. [Reference Links](#6-reference-links)

---

## 1. Available EHX Source Code & Algorithms

EHX has **never released any official open-source code**. They rely on trade secret and copyright protection. However, the community has produced significant resources:

### Analog Pedals (Circuit-Level Documentation Available)

#### Big Muff Pi
- **Algorithm understanding: Excellent**
- 4 analog stages: Input Booster → Clipping Stage → Passive Tone Control → Output Booster
- Full circuit analysis available from ElectroSmash and Coda Effects
- All major variants documented (Triangle, Ram's Head, Green Russian, Op-Amp)
- **Available code:**
  - `hazza-music/EHX-Big-Muff-Pi-Emulation` — MATLAB DSP emulation
  - `damskaggep/WaveNetVA` — Pre-trained WaveNet neural model of Big Muff
  - `clevelandmusicco/open-source-pedals` — Open hardware PCB ("The Why")
  - `Circle-Circuits/motherboard` — KiCad PCB for any Big Muff variant

#### Small Stone Phaser (EH4800)
- **Algorithm understanding: Excellent**
- 4-stage JFET all-pass filter phaser, designed by David Cockerell
- **Available code:**
  - `NaviCisco/StoneMistress` — C++/JUCE VST3/AU plugin (4 IIR all-pass filters)
  - `DiffAPF/EHX-SmallStone` — ML-based model (Python, DAFx 2024 paper), includes pretrained checkpoints

#### Electric Mistress
- **Algorithm understanding: Good**
- BBD-based flanger, original used SAD1024a chip, later MN3007
- Original designed by David Cockerell; Deluxe version by Howard Davis
- **Available code:**
  - `NaviCisco/StoneMistress` — Includes chorus component inspired by Stereo Electric Mistress
  - Schematics available from Tonepad

#### Memory Man / Deluxe Memory Man
- **Algorithm understanding: Moderate**
- BBD delay (MN3005/MN3007) with modulation, designed by Howard Davis
- No direct open-source emulation, but generic BBD delay implementations exist
- ElectroSmash has MN3007 BBD chip analysis

### Digital/DSP Pedals (Proprietary, Limited Understanding)

#### POG / HOG (Polyphonic Octave Generator)
- **Algorithm understanding: Speculative**
- Runs on Freescale DSP56364 chip
- Sean Costello (Valhalla DSP) analysis: likely FFT/wavelet or multi-band pitch shifting
- No public firmware reverse engineering exists

#### Freeze / SuperEgo
- **Algorithm understanding: Speculative**
- Runs at 24-bit / 66 kHz
- Designed by David Cockerell with anti-transient-click provision
- Likely spectral/FFT-based freeze (not granular)
- No open-source implementation

#### 9-Series (B9, C9, Key9, Mel9, Synth9, String9, Bass9)
- **Algorithm understanding: Minimal**
- All share the same PCB and Analog Devices DSP chip
- Firmware on swappable EEPROM
- `pruttelherrie/Ehx9-All` — STM32 hardware mod to combine all 9-series firmware images
- DSP algorithms remain completely opaque

#### Pitch Fork
- **Algorithm understanding: None**
- No public code, analysis, or documentation

#### EH400 Mini-Synthesizer / Random Tone Generator
- `Skidlz/EH400-Mini-Synth` — Hardware recreation
- `volksamt/RTG1` — Arduino clone of Random Tone Generator

### Neural Network / ML Frameworks (Train Your Own)

These can be trained on recordings of *any* EHX pedal:
- `GuitarML/PedalNetRT` — WaveNet-based real-time pedal emulation (PyTorch)
- `GuitarML/GuitarLSTM` — LSTM-based amp/pedal emulation (Keras)
- `GuitarML/NeuralPi` — Raspberry Pi guitar pedal using neural networks

---

## 2. Norns Platform Capabilities & Constraints

### Hardware

| Parameter | Value |
|---|---|
| CPU | RPi CM3+ — Quad-core ARM Cortex-A53 @ 1.2 GHz |
| RAM | 1 GB |
| Sample Rate | 48 kHz (crystal-clocked, fixed) |
| Bit Depth | 24-bit DAC (CS4270); softcut buffers 16-bit |
| JACK Latency | ~8 ms (128 frames × 3 periods / 48 kHz) |
| SC Server Latency | 50 ms (scheduling, not audio throughput) |
| Audio I/O | Stereo in (1/4"), stereo out (1/4"), headphone out |
| Input Impedance | 10k ohm (line level — see note below) |
| Screen | 128×64 monochrome OLED |

**Important for guitar use:** Norns input impedance is 10k ohm (line level), not the ~1M ohm a guitar expects. A buffer/preamp or DI box between guitar and Norns is recommended for proper impedance matching.

### Software Architecture

Three processes:
- **matron** — Lua scripting engine (UI, controls, MIDI, grid, params)
- **crone** — C++ audio system (mixer, softcut, JACK routing)
- **SuperCollider** — Synthesis/DSP engines (scsynth)

### DSP Options

1. **SuperCollider Engines** — Full synthesis language, ~700+ UGens, runs as CroneEngine
2. **Softcut** — 6-voice sample manipulation (variable-rate, filters, overdub), Lua-controlled
3. **Pure Data** — Via community projects (Orac/Sidekick)
4. **Faust / RNBO** — Experimental community support

### Existing Pedal-Style Scripts

- **Pedalboard** (21echoes) — 23 chainable stereo effects including delay, reverb, overdrive, distortion, chorus, flanger, phaser, tremolo, auto-wah, pitch shifter, compressor, amp sim, ring mod, and more
- **Tapedeck** — 12-stage tape emulation
- **Twins** — Granular + effects (reverb, delay, chorus, shimmer, EQ)
- **Splnkr** — Amplitude/frequency tracking with 16 bandpass filters
- **R** — Fully modular audio engine (arbitrary module patching from Lua)

---

## 3. Implementation Feasibility by Pedal

### Tier 1: Highly Feasible (Well-Documented, CPU-Friendly)

#### Big Muff Pi
- **Approach:** Waveshaping + passive tone filter emulation in SuperCollider
- **DSP recipe:**
  1. Input gain stage (soft clipping)
  2. Two cascaded clipping stages with asymmetric diode models (`tanh` or lookup table)
  3. Passive tone control: parallel LP/HP with blendable crossover (~1 kHz)
  4. Output gain stage
- **CPU cost:** Very low — simple nonlinear waveshaping + filters
- **Variant support:** Swap component values to model Triangle, Ram's Head, Green Russian, Op-Amp versions
- **Reference:** ElectroSmash analysis provides exact component values and transfer functions

#### Small Stone Phaser
- **Approach:** 4 cascaded all-pass filters with LFO modulation
- **DSP recipe:**
  1. 4× second-order IIR all-pass filters
  2. LFO modulates filter coefficients (triangle or sine wave)
  3. Mix wet/dry for notch depth
  4. "Color" switch feeds output back to input (resonant mode)
- **CPU cost:** Very low — 4 biquad filters + 1 LFO
- **Reference:** StoneMistress JUCE source provides exact filter coefficients

#### Electric Mistress (Flanger)
- **Approach:** Short modulated delay line + feedback
- **DSP recipe:**
  1. Delay line (0.5–10 ms range)
  2. LFO modulates delay time (triangle wave, ~0.1–5 Hz)
  3. Feedback path with gain control
  4. Mix wet/dry (flanger mode vs. chorus mode)
  5. Optional: model BBD clock artifacts for analog character
- **CPU cost:** Low — delay line + LFO + mixing

#### Random Tone Generator
- **Approach:** Direct port of Arduino code
- **DSP recipe:** Random oscillator triggering, simple enough to implement in Lua + basic SC engine
- **CPU cost:** Minimal

### Tier 2: Feasible with Effort (Partially Documented)

#### Memory Man (Analog Delay)
- **Approach:** BBD delay emulation in SuperCollider
- **DSP recipe:**
  1. Anti-aliasing input filter (LP ~10 kHz, models BBD bandwidth)
  2. Delay line with modulation (chorus/vibrato mode)
  3. Feedback path with LP filter (models BBD degradation per repeat)
  4. Optional: quantize delay buffer to model BBD discrete sampling
  5. Output reconstruction filter
- **CPU cost:** Moderate — delay line + multiple filters + modulation
- **Note:** Softcut could handle the core delay, but BBD character emulation needs SC

#### Freeze (Spectral Freeze)
- **Approach:** FFT-based spectral freeze in SuperCollider
- **DSP recipe:**
  1. Continuous FFT analysis of input (PV_RecordBuf or similar)
  2. On trigger: capture and hold current FFT frame
  3. Continuous IFFT resynthesis of held frame (PV_PlayBuf → IFFT)
  4. Crossfade/envelope between live and frozen signal
  5. Anti-transient provision: gate pluck transients before capture
- **CPU cost:** Moderate-high — real-time FFT/IFFT
- **SuperCollider advantage:** Built-in PV (Phase Vocoder) UGens are ideal for this:
  - `FFT`, `IFFT`, `PV_RecordBuf`, `PV_PlayBuf`, `PV_Freeze`, `PV_MagFreeze`
  - `PV_Freeze` is literally a spectral freeze UGen already in SC

#### SuperEgo (Extended Freeze with Layers)
- **Approach:** Extension of Freeze with layering and effects
- **DSP recipe:**
  1. Same spectral freeze core as above
  2. Add: layer mode (accumulate multiple frozen frames)
  3. Add: auto mode (envelope follower triggers freeze)
  4. Post-freeze effects chain (filter, modulation)
- **CPU cost:** High — multiple FFT streams + effects

### Tier 3: Challenging but Possible (Algorithm Guesswork Required)

#### POG (Polyphonic Octave Generator)
- **Approach A:** FFT-based pitch shifting
  - Use SuperCollider's `PV_BinShift` to shift spectrum by octaves
  - Mix sub-octave (-1 oct), dry, octave (+1 oct)
  - Pro: Polyphonic, clean. Con: FFT latency, potential artifacts
- **Approach B:** Multi-band pitch shifting
  - Split signal into frequency bands
  - Per-band pitch detection + pitch shifting
  - Pro: Lower latency. Con: More complex, crossover artifacts
- **Approach C:** `PitchShift` UGen with fixed ratios
  - `PitchShift.ar(in, pitchRatio: 0.5)` for sub-octave
  - `PitchShift.ar(in, pitchRatio: 2.0)` for octave up
  - Pro: Simple. Con: Not truly polyphonic, artifacts on chords
- **CPU cost:** Moderate to high depending on approach
- **Recommendation:** Start with Approach A (FFT), as SC's PV UGens handle this well

#### HOG (Harmonic Octave Generator)
- Same as POG but with more intervals (5ths, 3rds, etc.) and expression pedal morphing
- **CPU cost:** Very high — multiple pitch-shifted streams
- May push Norns CPU limits

### Tier 4: Very Challenging (Opaque Algorithms)

#### 9-Series (B9 Organ, C9 Organ, Key9, Mel9, Synth9, etc.)
- These are complex resynthesis engines that transform guitar into other instruments
- Likely involve: pitch detection → resynthesis using instrument-specific models
- **Possible approach on Norns:**
  1. Pitch tracking (`Pitch.kr` UGen)
  2. Amplitude envelope follower
  3. Drive a synth voice tuned to detected pitch with appropriate timbre
  4. For organ: additive synthesis with drawbar-style harmonics
  5. For mellotron: sample playback triggered by pitch
- **CPU cost:** High — real-time pitch tracking + synthesis
- **Limitation:** Won't match EHX quality for polyphonic input; monophonic tracking is more realistic on Norns

#### Pitch Fork
- Polyphonic pitch shifting with expression control
- Similar challenges to POG but with arbitrary intervals
- **CPU cost:** High

---

## 4. Recommended Implementation Approaches

### SuperCollider Engine Architecture

A modular EHX engine for Norns could look like:

```supercollider
Engine_EHX : CroneEngine {
    var <synths;
    var <busses;

    alloc {
        // === BIG MUFF ===
        SynthDef(\bigmuff, { |in_bus, out_bus, gain=0.7, tone=0.5, sustain=0.8|
            var sig = In.ar(in_bus, 2);
            // Input boost
            sig = sig * (1 + (sustain * 20));
            // Clipping stages (tanh soft clip models silicon diodes)
            sig = (sig * 4).tanh;
            sig = (sig * 4).tanh;
            // Passive tone control (parallel LP/HP blend)
            var lp = LPF.ar(sig, 1000);
            var hp = HPF.ar(sig, 1000);
            sig = (lp * (1 - tone)) + (hp * tone);
            // Output
            sig = sig * gain;
            Out.ar(out_bus, sig);
        }).add;

        // === SMALL STONE ===
        SynthDef(\smallstone, { |in_bus, out_bus, rate=0.5, depth=1, color=0|
            var sig = In.ar(in_bus, 2);
            var lfo = SinOsc.kr(rate).range(200, 4000);
            // 4 cascaded all-pass filters
            sig = AllpassL.ar(sig, 0.01, lfo.reciprocal, 0);
            sig = AllpassL.ar(sig, 0.01, (lfo * 1.3).reciprocal, 0);
            sig = AllpassL.ar(sig, 0.01, (lfo * 1.7).reciprocal, 0);
            sig = AllpassL.ar(sig, 0.01, (lfo * 2.1).reciprocal, 0);
            // Color switch adds feedback resonance
            // (simplified — real impl would use LocalIn/LocalOut)
            Out.ar(out_bus, sig);
        }).add;

        // === FREEZE ===
        SynthDef(\freeze, { |in_bus, out_bus, freeze_gate=0, mix=0.5|
            var sig = In.ar(in_bus, 2);
            var chain = FFT(LocalBuf(2048), sig);
            chain = PV_MagFreeze(chain, freeze_gate);
            var frozen = IFFT(chain);
            sig = (sig * (1 - mix)) + (frozen * mix);
            Out.ar(out_bus, sig);
        }).add;

        // ... more effects ...
    }
}
```

### Lua Control Layer

```lua
-- In hichord.lua or a dedicated ehx.lua module
engine.name = "EHX"

function init()
  params:add_group("EHX_EFFECTS", "EHX Effects", 10)

  params:add_control("bigmuff_gain", "Big Muff Gain",
    controlspec.new(0, 1, 'lin', 0.01, 0.7))
  params:set_action("bigmuff_gain", function(v) engine.bigmuff_gain(v) end)

  params:add_control("bigmuff_tone", "Big Muff Tone",
    controlspec.new(0, 1, 'lin', 0.01, 0.5))
  params:set_action("bigmuff_tone", function(v) engine.bigmuff_tone(v) end)

  -- Freeze trigger mapped to grid or key
  params:add_binary("freeze_trigger", "Freeze", "toggle", 0)
  params:set_action("freeze_trigger", function(v) engine.freeze_gate(v) end)
end
```

### Priority Implementation Order

1. **Big Muff Pi** — Simplest, best documented, lowest CPU, iconic tone
2. **Small Stone Phaser** — Simple DSP, well-documented coefficients
3. **Electric Mistress** — Simple delay-based flanger
4. **Freeze** — SC has built-in PV_MagFreeze, surprisingly easy
5. **Memory Man** — Moderate complexity, could leverage softcut for delay core
6. **POG** — FFT pitch shifting, moderate-high CPU
7. **9-Series approximations** — Pitch tracking + resynthesis, highest complexity

---

## 5. Integration with HiChord

HiChord already runs two SuperCollider engines (`Engine_HiChord.sc` and `Engine_Congregation.sc`). Integration options:

### Option A: Separate EHX Script
- Standalone Norns script with its own `Engine_EHX.sc`
- Run independently from HiChord
- Pro: No risk to existing HiChord stability
- Con: Can't use both simultaneously (Norns runs one script at a time)

### Option B: Extend HiChord Engine
- Add EHX effects as insert/send effects within the existing HiChord or Congregation engine
- Route HiChord's synth output through EHX effect SynthDefs
- Pro: Integrated workflow — chord output goes through Big Muff/phaser/etc.
- Con: Increased CPU load, more complex engine code

### Option C: Use Pedalboard as Reference
- The existing Pedalboard script (21echoes) already implements 23 effects on Norns
- Study its architecture for effect chaining patterns
- Potentially borrow its effect implementations and adapt for HiChord integration

### Recommended: Start with Option A, migrate to Option B

Build a standalone `ehx-effects` script first to validate DSP performance on Norns hardware. Once stable, integrate the proven effects into HiChord's engine as optional insert effects on the chord output path.

---

## 6. Reference Links

### EHX Circuit Analysis
- [ElectroSmash: Big Muff Pi Analysis](https://www.electrosmash.com/big-muff-pi-analysis)
- [Coda Effects: Big Muff Circuit Analysis](https://www.coda-effects.com/p/big-muff-circuit-analysis.html)
- [BigMuffPage.com: Schematics & Variants](https://www.bigmuffpage.com/Big_Muff_Pi_versions_schematics_part1.html)
- [ElectroSmash: MN3007 BBD Analysis](https://www.electrosmash.com/mn3007-bucket-brigade-devices)

### EHX-Related Code Repositories
- [NaviCisco/StoneMistress](https://github.com/NaviCisco/StoneMistress) — Small Stone + Electric Mistress JUCE plugin
- [DiffAPF/EHX-SmallStone](https://github.com/DiffAPF/EHX-SmallStone) — ML-based Small Stone model
- [hazza-music/EHX-Big-Muff-Pi-Emulation](https://github.com/hazza-music/EHX-Big-Muff-Pi-Emulation) — MATLAB Big Muff
- [damskaggep/WaveNetVA](https://github.com/damskaggep/WaveNetVA) — WaveNet with Big Muff model
- [pruttelherrie/Ehx9-All](https://github.com/pruttelherrie/Ehx9-All) — 9-series EEPROM combiner
- [volksamt/RTG1](https://github.com/volksamt/RTG1) — Arduino Random Tone Generator clone
- [clevelandmusicco/open-source-pedals](https://github.com/clevelandmusicco/open-source-pedals) — Big Muff PCB

### ML Frameworks for Pedal Emulation
- [GuitarML/PedalNetRT](https://github.com/GuitarML/PedalNetRT) — WaveNet real-time pedal emulation
- [GuitarML/GuitarLSTM](https://github.com/GuitarML/GuitarLSTM) — LSTM pedal emulation
- [GuitarML/NeuralPi](https://github.com/GuitarML/NeuralPi) — Raspberry Pi neural pedal

### Norns Development
- [Norns Documentation](https://monome.org/docs/norns/)
- [Norns Engine Study 1-3](https://monome.org/docs/norns/engine-study-1/)
- [Pedalboard Script](https://github.com/21echoes/pedalboard) — 23-effect reference implementation
- [Norns Community Scripts](https://norns.community/)
- [Lines Forum](https://llllllll.co) — Norns community

### Legal Context
- [EHX Blog: Mooer Firmware Piracy Case](https://www.ehx.com/blog/chinese-pirates-of-electro-harmonix-software-walk-the-plank/)
- [Official EHX Plugins (MixWave)](https://www.ehx.com/plugins/)
