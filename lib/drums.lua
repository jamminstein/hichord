-- lib/drums.lua
-- Humanized drum sequencer for HiChord
-- Groove templates, ghost notes, micro-timing, probability

local drums = {}

-- GM MIDI drum map
drums.MIDI_KICK = 36
drums.MIDI_SNARE = 38
drums.MIDI_RIMSHOT = 37
drums.MIDI_HAT_CLOSED = 42
drums.MIDI_HAT_OPEN = 46
drums.MIDI_PERC1 = 39   -- clap
drums.MIDI_PERC2 = 56   -- cowbell

-- Voice names for display/params
drums.VOICE_NAMES = {"kick", "snare", "hat", "perc"}
drums.VOICE_MIDI = {
  drums.MIDI_KICK,
  drums.MIDI_SNARE,
  drums.MIDI_HAT_CLOSED,
  drums.MIDI_PERC1,
}

------------------------------------------------------------------------
-- GROOVE PRESETS
-- Each preset defines per-voice: pattern, velocity, timing offset (ms),
-- probability (0-100), and an open-hat mask for the hat voice.
-- All arrays are 16 steps = one bar of 16th notes.
------------------------------------------------------------------------

drums.PRESETS = {}

-- 1. FUNK (James Brown / Clyde Stubblefield)
-- Syncopated kick, snare on 2 & 4 with heavy ghost notes,
-- driving hats with accent wave
drums.PRESETS["funk"] = {
  name = "Funk",
  -- kick: 1, &-of-2, 4, e-of-4
  kick_pattern =  {1,0,0,0, 0,0,1,0, 0,0,0,0, 1,1,0,0},
  kick_vel =      {120,0,0,0, 0,0,95,0, 0,0,0,0, 110,80,0,0},
  kick_timing =   {0,0,0,0, 0,0,3,0, 0,0,0,0, 0,-4,0,0},
  kick_prob =     {100,0,0,0, 0,0,100,0, 0,0,0,0, 100,85,0,0},

  -- snare: ghost-CRACK-ghost pattern
  snare_pattern = {0,0,0,1, 1,0,1,0, 0,1,0,1, 1,0,0,1},
  snare_vel =     {0,0,0,28, 127,0,25,0, 0,30,0,25, 127,0,0,32},
  snare_timing =  {0,0,0,5, 2,0,-3,0, 0,4,0,-2, 3,0,0,6},
  snare_prob =    {0,0,0,70, 100,0,65,0, 0,75,0,60, 100,0,0,70},

  -- hat: steady 16ths with accent wave
  hat_pattern =   {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat_vel =       {100,40,70,35, 95,38,72,30, 100,42,68,38, 90,35,75,32},
  hat_timing =    {0,-5,3,-4, 0,-6,4,-3, 0,-5,3,-5, 0,-4,4,-3},
  hat_prob =      {100,92,95,82, 100,88,95,78, 100,90,95,85, 100,88,95,80},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0},

  -- perc: sparse clap accents
  perc_pattern =  {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  perc_vel =      {0,0,0,0, 90,0,0,0, 0,0,0,0, 85,0,0,0},
  perc_timing =   {0,0,0,0, -2,0,0,0, 0,0,0,0, -1,0,0,0},
  perc_prob =     {0,0,0,0, 40,0,0,0, 0,0,0,0, 35,0,0,0},
}

-- 2. BRAZILIAN FUNK (Marcio Barker / funk carioca)
-- Forward-leaning hats, dense ghost notes, syncopated partido-alto kick,
-- heavy snare ghosts creating rolling texture
drums.PRESETS["brazilian"] = {
  name = "Brazilian Funk",
  -- kick: partido alto influenced - offbeat syncopation
  kick_pattern =  {1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,1},
  kick_vel =      {115,0,0,90, 0,0,100,0, 0,85,0,0, 110,0,0,75},
  kick_timing =   {0,0,0,-3, 0,0,2,0, 0,-2,0,0, 0,0,0,-4},
  kick_prob =     {100,0,0,90, 0,0,100,0, 0,88,0,0, 100,0,0,80},

  -- snare: dense ghost note texture with accents on 2 and 4
  snare_pattern = {0,1,1,1, 1,1,1,1, 0,1,1,1, 1,1,1,1},
  snare_vel =     {0,22,30,25, 127,20,28,22, 0,25,32,20, 127,22,30,28},
  snare_timing =  {0,3,-2,4, 0,5,-3,2, 0,4,-2,5, 2,3,-4,3},
  snare_prob =    {0,72,80,68, 100,65,75,62, 0,70,78,65, 100,68,72,70},

  -- hat: 16ths, forward-leaning (negative offsets = pushing ahead)
  hat_pattern =   {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat_vel =       {95,45,75,40, 100,42,78,38, 95,48,72,42, 98,40,76,36},
  hat_timing =    {-2,-7,-1,-6, -2,-8,-1,-5, -2,-6,-1,-7, -2,-7,-1,-5},
  hat_prob =      {100,90,96,85, 100,88,95,82, 100,92,96,86, 100,88,95,84},
  hat_open =      {0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,0,1},

  -- perc: tamborim-like pattern (asymmetric grouping 3+3+3+3+4)
  perc_pattern =  {1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0},
  perc_vel =      {90,0,0,75,0,0,80,0, 0,70,0,0, 85,0,0,0},
  perc_timing =   {0,0,0,-3, 0,0,-2,0, 0,-4,0,0, -1,0,0,0},
  perc_prob =     {95,0,0,85, 0,0,90,0, 0,82,0,0, 88,0,0,0},
}

-- 3. HIP-HOP (J Dilla / laid back)
-- Behind-the-beat feel, heavy kick, sparse hats, big swing
drums.PRESETS["hiphop"] = {
  name = "Hip-Hop",
  -- kick: heavy, slightly late
  kick_pattern =  {1,0,0,0, 0,0,0,0, 1,0,1,0, 0,0,0,0},
  kick_vel =      {127,0,0,0, 0,0,0,0, 110,0,95,0, 0,0,0,0},
  kick_timing =   {4,0,0,0, 0,0,0,0, 8,0,5,0, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,0,0, 100,0,90,0, 0,0,0,0},

  -- snare: 2 and 4, consistently late (the pocket)
  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 120,0,0,0, 0,0,0,0, 115,0,0,0},
  snare_timing =  {0,0,0,0, 12,0,0,0, 0,0,0,0, 15,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 100,0,0,0},

  -- hat: 8th notes with heavy swing (big timing offsets on upbeats)
  hat_pattern =   {1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0},
  hat_vel =       {90,0,55,0, 85,0,50,0, 88,0,52,0, 82,0,48,0},
  hat_timing =    {0,0,18,0, 2,0,22,0, 0,0,20,0, 3,0,25,0},
  hat_prob =      {100,0,95,0, 100,0,92,0, 100,0,95,0, 100,0,90,0},
  hat_open =      {0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,0,0},

  -- perc: off
  perc_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
}

-- 4. STRAIGHT (reference / minimal humanization)
-- Basic rock pattern, very light timing offsets
drums.PRESETS["straight"] = {
  name = "Straight",
  kick_pattern =  {1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0},
  kick_vel =      {110,0,0,0, 0,0,0,0, 105,0,0,0, 0,0,0,0},
  kick_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,0,0, 100,0,0,0, 0,0,0,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 110,0,0,0, 0,0,0,0, 108,0,0,0},
  snare_timing =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 100,0,0,0},

  hat_pattern =   {1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0},
  hat_vel =       {90,0,60,0, 88,0,58,0, 90,0,60,0, 85,0,55,0},
  hat_timing =    {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  hat_prob =      {100,0,100,0, 100,0,100,0, 100,0,100,0, 100,0,100,0},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  perc_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
}

-- Preset order for cycling
drums.PRESET_ORDER = {"funk", "brazilian", "hiphop", "straight"}

------------------------------------------------------------------------
-- SEQUENCER STATE
------------------------------------------------------------------------

local seq = {
  running = false,
  step = 1,           -- current 16th note (1-16)
  preset_idx = 1,     -- index into PRESET_ORDER
  humanize = 80,      -- 0-100: how much groove template is applied
  jitter = 30,        -- 0-100: random timing variation on top of template
  ghost_density = 80, -- 0-100: probability multiplier for ghost notes
  feel = 100,         -- 0-100: velocity dynamics depth
  midi_out = nil,
  midi_channel = 10,  -- standard GM drum channel
  mute = {false, false, false, false}, -- per-voice mutes
}

------------------------------------------------------------------------
-- HUMANIZATION ENGINE
------------------------------------------------------------------------

-- Attempt gaussian-ish distribution using central limit theorem
-- Returns value roughly in range [-1, 1] with bell curve distribution
local function gaussian_random()
  return (math.random() + math.random() + math.random() - 1.5) / 1.5
end

-- Apply humanized timing offset for a given step and voice
-- Returns offset in seconds
local function get_timing_offset(base_offset_ms, step)
  -- Scale template offset by humanize amount
  local template_ms = base_offset_ms * (seq.humanize / 100)
  -- Add random jitter scaled by jitter param
  local jitter_ms = gaussian_random() * (seq.jitter / 100) * 10 -- max +-10ms jitter
  local total_ms = template_ms + jitter_ms
  -- Clamp to reasonable range (-30ms to +30ms)
  total_ms = math.max(-30, math.min(30, total_ms))
  return total_ms / 1000 -- convert to seconds
end

-- Apply humanized velocity
-- base_vel: the template velocity for this step
-- Returns MIDI velocity 1-127
local function get_humanized_velocity(base_vel)
  if base_vel <= 0 then return 0 end
  -- Scale dynamics by feel parameter
  -- At feel=0, all velocities converge to 80 (flat dynamics)
  -- At feel=100, full template dynamics
  local flat_vel = 80
  local vel = flat_vel + (base_vel - flat_vel) * (seq.feel / 100)
  -- Add small random variation (proportional to velocity - ghost notes vary less)
  local variation = gaussian_random() * 8
  vel = math.floor(vel + variation)
  return math.max(1, math.min(127, vel))
end

-- Check if a ghost note should fire based on density parameter
-- Ghost notes = velocity < 50 in the template
local function should_play_ghost(template_vel, probability)
  if template_vel >= 50 then
    -- Accent/main hit: always use base probability
    return math.random(100) <= probability
  else
    -- Ghost note: scale probability by ghost_density
    local adjusted_prob = probability * (seq.ghost_density / 100)
    return math.random(100) <= adjusted_prob
  end
end

------------------------------------------------------------------------
-- MIDI OUTPUT
------------------------------------------------------------------------

local function send_drum_midi(midi_note, velocity)
  if not seq.midi_out then return end
  if velocity <= 0 then return end
  pcall(function()
    seq.midi_out:note_on(midi_note, velocity, seq.midi_channel)
  end)
  -- Schedule note off after short duration (drums are triggers)
  clock.run(function()
    clock.sleep(0.05)
    pcall(function()
      seq.midi_out:note_off(midi_note, 0, seq.midi_channel)
    end)
  end)
end

------------------------------------------------------------------------
-- ENGINE OUTPUT (synthesized drums via SuperCollider)
-- Each hit gets random timbral variation parameters
------------------------------------------------------------------------

local function send_drum_engine(voice_name, velocity, is_open_hat)
  if velocity <= 0 then return end
  local vel_float = velocity / 127

  -- Random per-hit variation values (-1 to 1 range)
  local var1 = gaussian_random()
  local var2 = gaussian_random()
  local var3 = gaussian_random()

  if voice_name == "kick" then
    engine.drumKick(vel_float, var1, var2, var3)
  elseif voice_name == "snare" then
    engine.drumSnare(vel_float, var1, var2, var3)
  elseif voice_name == "hat" then
    local open = (is_open_hat and 1) or 0
    engine.drumHat(vel_float, var1, var2, open)
  elseif voice_name == "perc" then
    engine.drumPerc(vel_float, var1, var2, 0)
  end
end

------------------------------------------------------------------------
-- STEP TRIGGER
-- Called for each voice at each step. Handles timing offset via
-- clock.sleep before triggering, so each voice runs in its own coroutine.
------------------------------------------------------------------------

local function trigger_voice(voice_name, midi_note, step, preset)
  local pattern = preset[voice_name .. "_pattern"]
  local vel_template = preset[voice_name .. "_vel"]
  local timing_template = preset[voice_name .. "_timing"]
  local prob_template = preset[voice_name .. "_prob"]

  if not pattern or pattern[step] == 0 then return end

  local base_vel = vel_template[step] or 0
  local base_timing = timing_template[step] or 0
  local probability = prob_template[step] or 100

  -- Check probability (ghost-aware)
  if not should_play_ghost(base_vel, probability) then return end

  -- Calculate humanized values
  local timing_offset = get_timing_offset(base_timing, step)
  local velocity = get_humanized_velocity(base_vel)

  -- For hat voice, check open hat
  local is_open_hat = false
  if voice_name == "hat" and preset.hat_open and preset.hat_open[step] == 1 then
    is_open_hat = true
    midi_note = drums.MIDI_HAT_OPEN
  end

  -- Schedule with timing offset
  clock.run(function()
    if timing_offset > 0 then
      clock.sleep(timing_offset)
    end
    -- Fire both engine synth and MIDI
    send_drum_engine(voice_name, velocity, is_open_hat)
    send_drum_midi(midi_note, velocity)
  end)
end

------------------------------------------------------------------------
-- MAIN SEQUENCER CLOCK
------------------------------------------------------------------------

local seq_clock_id = nil

local function seq_tick()
  local preset_key = drums.PRESET_ORDER[seq.preset_idx]
  local preset = drums.PRESETS[preset_key]
  if not preset then return end

  local step = seq.step

  -- Trigger each voice (each in its own timing coroutine)
  if not seq.mute[1] then
    trigger_voice("kick", drums.MIDI_KICK, step, preset)
  end
  if not seq.mute[2] then
    trigger_voice("snare", drums.MIDI_SNARE, step, preset)
  end
  if not seq.mute[3] then
    trigger_voice("hat", drums.MIDI_HAT_CLOSED, step, preset)
  end
  if not seq.mute[4] then
    trigger_voice("perc", drums.MIDI_PERC1, step, preset)
  end

  -- Advance step
  seq.step = (seq.step % 16) + 1
end

------------------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------------------

function drums.start()
  if seq.running then return end
  seq.running = true
  seq.step = 1
  seq_clock_id = clock.run(function()
    while seq.running do
      seq_tick()
      clock.sync(1/4) -- sync to 16th notes (1 beat = 4 sixteenths)
    end
  end)
end

function drums.stop()
  seq.running = false
  if seq_clock_id then
    clock.cancel(seq_clock_id)
    seq_clock_id = nil
  end
  -- All notes off on drum channel
  if seq.midi_out then
    pcall(function()
      seq.midi_out:cc(123, 0, seq.midi_channel)
    end)
  end
end

function drums.toggle()
  if seq.running then
    drums.stop()
  else
    drums.start()
  end
end

function drums.is_running()
  return seq.running
end

function drums.get_step()
  return seq.step
end

function drums.get_preset_name()
  local key = drums.PRESET_ORDER[seq.preset_idx]
  local preset = drums.PRESETS[key]
  return preset and preset.name or "?"
end

function drums.get_preset_idx()
  return seq.preset_idx
end

function drums.set_preset(idx)
  seq.preset_idx = util.clamp(idx, 1, #drums.PRESET_ORDER)
end

function drums.next_preset()
  seq.preset_idx = (seq.preset_idx % #drums.PRESET_ORDER) + 1
end

function drums.set_humanize(val)
  seq.humanize = util.clamp(val, 0, 100)
end

function drums.get_humanize()
  return seq.humanize
end

function drums.set_jitter(val)
  seq.jitter = util.clamp(val, 0, 100)
end

function drums.get_jitter()
  return seq.jitter
end

function drums.set_ghost_density(val)
  seq.ghost_density = util.clamp(val, 0, 100)
end

function drums.get_ghost_density()
  return seq.ghost_density
end

function drums.set_feel(val)
  seq.feel = util.clamp(val, 0, 100)
end

function drums.get_feel()
  return seq.feel
end

function drums.set_midi_out(m)
  seq.midi_out = m
end

function drums.set_midi_channel(ch)
  seq.midi_channel = util.clamp(ch, 1, 16)
end

function drums.get_midi_channel()
  return seq.midi_channel
end

function drums.toggle_mute(voice_idx)
  if voice_idx >= 1 and voice_idx <= 4 then
    seq.mute[voice_idx] = not seq.mute[voice_idx]
  end
end

function drums.is_muted(voice_idx)
  return seq.mute[voice_idx] or false
end

-- Get current pattern data for grid/screen display
-- Returns table of {kick={}, snare={}, hat={}, perc={}} with step data
function drums.get_pattern_display()
  local key = drums.PRESET_ORDER[seq.preset_idx]
  local preset = drums.PRESETS[key]
  if not preset then return nil end
  return {
    kick = preset.kick_pattern,
    snare = preset.snare_pattern,
    hat = preset.hat_pattern,
    perc = preset.perc_pattern,
    kick_vel = preset.kick_vel,
    snare_vel = preset.snare_vel,
    hat_vel = preset.hat_vel,
    perc_vel = preset.perc_vel,
  }
end

------------------------------------------------------------------------
-- PARAMS (call from init)
------------------------------------------------------------------------

function drums.add_params()
  params:add_separator("DRUMS")

  params:add_option("drum_preset", "Drum Groove", {"Funk", "Brazilian Funk", "Hip-Hop", "Straight"}, 2)
  params:set_action("drum_preset", function(val)
    drums.set_preset(val)
  end)

  params:add_control("drum_humanize", "Groove Amount",
    controlspec.new(0, 100, "lin", 1, 80, "%"))
  params:set_action("drum_humanize", function(val)
    drums.set_humanize(val)
  end)

  params:add_control("drum_jitter", "Timing Jitter",
    controlspec.new(0, 100, "lin", 1, 30, "%"))
  params:set_action("drum_jitter", function(val)
    drums.set_jitter(val)
  end)

  params:add_control("drum_ghost_density", "Ghost Density",
    controlspec.new(0, 100, "lin", 1, 80, "%"))
  params:set_action("drum_ghost_density", function(val)
    drums.set_ghost_density(val)
  end)

  params:add_control("drum_feel", "Velocity Feel",
    controlspec.new(0, 100, "lin", 1, 100, "%"))
  params:set_action("drum_feel", function(val)
    drums.set_feel(val)
  end)

  params:add_number("drum_midi_ch", "Drum MIDI Ch", 1, 16, 10)
  params:set_action("drum_midi_ch", function(val)
    drums.set_midi_channel(val)
  end)
end

------------------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------------------

function drums.cleanup()
  drums.stop()
end

return drums
