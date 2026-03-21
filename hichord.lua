-- hichord.lua  v3.0
-- Norns port of HiChord (hichord.shop) firmware 2.6.9
-- Grid = physical HiChord device replica (16×8)
-- Norns screen Page A = traditional param/menu display
-- Norns screen Page B = animated HiChord OLED replica
--
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  GRID LAYOUT  (16 cols × 8 rows)  mirrors HiChord hardware
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--
--   Col:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
-- Row 1: [──────── KEY SELECTOR  C C# D D# E F F# G G# A A# B ─────]
-- Row 2: [──────── SCALE / MODE label row (dim indicators) ─────]
-- Row 3: [JOY8dir-pad         ] [F1][F2][F3][  ] [CH1 2 3 4 5 6 7 ]
-- Row 4: [JOY8dir-pad         ] [  ][  ][  ][  ] [CH1 2 3 4 5 6 7 ]
-- Row 5: [JOY8dir-pad (3×3)   ] [  ][  ][  ][  ] [CH1 2 3 4 5 6 7 ]
-- Row 6: [OCT─][OCT+][       ] [  ][  ][  ][  ] [CH1 2 3 4 5 6 7 ]
-- Row 7: [LOOP1 cntl         ] [LOOP2 cntl      ] [MODE: 1-7      ]
-- Row 8: [WAVEFORM 1-8       ] [ADSR 1-6        ] [BPM tap / page ]
--
-- Chord Buttons 1-7 span rows 3-6, cols 10-16
-- Joystick 3×3 grid spans rows 3-5, cols 1-3
-- F1/F2/F3 at row 3-5, cols 5-7
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--
-- Norns K1 (short) = toggle Page A ↔ Page B
-- Norns K1 (hold)  = F1 (Settings)
-- Norns K2        = grid page up/down
-- Norns K3        = grid shift
-- Norns E1        = navigate / select
-- Norns E2        = parameter value
-- Norns E3        = secondary parameter
--
-- NEW FEATURES:
-- - Chord suggestion: suggest_next_chord() recommends common next chords
-- - Strum timing: configurable delay between chord note onsets (0-100ms)
-- - Screen redesign: hierarchical brightness zones with visual zones

engine.name = "MollyThePoly"

local ControlSpec = require "controlspec"
local tab = require "tabutil"

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  STATE & SETUP
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

local g = grid.connect()
local midi_out = nil

local function midi_to_hz(note)
  return 440 * 2^((note - 69) / 12)
end

local state = {
  -- chord & voicing
  root_note = 1,  -- 1..12 (C..B)
  octave = 4,
  chord_type = 3,  -- 1=MAJ, 2=MIN, 3=DOM7, 4=MIN7
  extensions = {},

  -- performance
  page_a = true,
  key_held = nil,
  bpm = 120,
  swing = 0,

  -- NEW: strum and suggestions
  strum_time = 0,  -- 0-100ms delay per note
  last_chord_root = 1,
  last_chord_type = 3,
  suggested_chords = {},
  suggestion_display_time = 0,

  -- NEW: screen animation state
  beat_phase = 0,  -- 0-1 for beat pulse animation
  popup_param = nil,  -- current encoder popup parameter
  popup_val = nil,  -- current encoder popup value
  popup_time = 0,  -- countdown for popup display (0.8s = 8 frames @10fps)

  -- active chord slot (1-7) for visualization
  active_slot = 1,
  chord_slots = {
    {root=1, type=3, notes={}},  -- C maj
    {root=5, type=3, notes={}},  -- F maj
    {root=8, type=3, notes={}},  -- G maj
    {root=10, type=2, notes={}}, -- A min
    {root=1, type=2, notes={}},  -- C min
    {root=5, type=2, notes={}},  -- F min
    {root=8, type=2, notes={}},  -- G min
  },

  loop_recording = false,
  loop_playing = false,
  loop_position = 0,  -- 0-1
  loop_length = 16,

  waveform_type = 1,  -- 1-8
  adsr_a = 10, adsr_d = 20, adsr_s = 80, adsr_r = 30,  -- ms
  midi_channel = 1,
  strum_flash_time = 0,  -- animation counter for strum ripple

  -- ENHANCEMENT 1: Sustain pedal MIDI
  sustain_held = false,  -- CC64 >= 64
  sustained_notes = {},  -- table of sustained note numbers

  -- ENHANCEMENT 2: Strum direction param
  strum_delay = 20,  -- 0-80ms delay per note
  strum_direction = 1,  -- 1=up, 2=down, 3=random

  -- ENHANCEMENT 3: Screen chord name display
  last_triggered_chord_name = "",  -- displayed chord name
  chord_display_time = 0,  -- countdown for chord name popup

  -- ENHANCEMENT 4: Velocity sensitivity
  velocity_mode = 1,  -- 1=fixed, 2=random, 3=dynamic
  velocity_base = 100,
  grid_buttons_held = 0,  -- count of simultaneously held grid buttons
  
  -- Engine note tracking for polyphonic release
  engine_notes = {},  -- map of midi_note -> engine_id
  next_engine_id = 1,
}

local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local CHORD_SHAPES = {
  {name="MAJ",   intervals={0,4,7}},
  {name="MIN",   intervals={0,3,7}},
  {name="DOM7",  intervals={0,4,7,10}},
  {name="MIN7",  intervals={0,3,7,10}},
}

local WAVEFORMS = {"sine", "square", "saw", "tri", "noise", "custom1", "custom2", "custom3"}

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  NEW: CHORD SUGGESTION ENGINE
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

local function suggest_next_chord(current_root, current_type)
  -- Music theory: common progressions in diatonic harmony
  -- Returns up to 3 suggested {root, type} pairs
  -- Bounds check on current_root
  if not current_root or current_root < 1 or current_root > 12 then
    current_root = 1
  end
  
  local sugg_map = {
    -- Major chord progressions
    [1] = {  -- C maj
      {root=5, type=3},   -- F major
      {root=8, type=3},   -- G major
      {root=10, type=2},  -- A minor
    },
    [5] = {  -- F maj
      {root=12, type=3},  -- C major (wraps)
      {root=1, type=3},   -- C major
      {root=8, type=3},   -- G major
    },
    [8] = {  -- G maj
      {root=1, type=3},   -- C major
      {root=5, type=3},   -- F major
      {root=8, type=2},   -- G minor
    },
    [10] = { -- A min
      {root=1, type=3},   -- C major
      {root=5, type=3},   -- F major
      {root=8, type=3},   -- G major
    },
  }
  
  return sugg_map[current_root] or {
    {root=5, type=3}, {root=8, type=3}
  }
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  NEW: STRUM TIMING HELPER
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

local function get_velocity(base_vel)
  -- ENHANCEMENT 4: Velocity sensitivity modes
  if state.velocity_mode == 2 then  -- random
    return math.max(1, math.min(127, base_vel + math.random(-15, 15)))
  elseif state.velocity_mode == 3 then  -- dynamic (based on held grid buttons)
    local extra = state.grid_buttons_held * 5
    return math.max(1, math.min(127, base_vel + extra))
  else  -- fixed (mode 1)
    return util.clamp(base_vel, 0, 127)
  end
end

local function play_chord_with_strum(notes, velocity)
  local num_notes = #notes
  if num_notes == 0 then return end

  local base_vel = velocity or state.velocity_base
  base_vel = util.clamp(base_vel, 0, 127)

  -- ENHANCEMENT 2: Strum direction param
  local play_notes = notes
  if state.strum_direction == 2 then  -- down
    play_notes = {}
    for i = num_notes, 1, -1 do
      table.insert(play_notes, notes[i])
    end
  elseif state.strum_direction == 3 then  -- random
    play_notes = {}
    local remaining = {}
    for _, n in ipairs(notes) do table.insert(remaining, n) end
    while #remaining > 0 do
      local idx = math.random(1, #remaining)
      table.insert(play_notes, remaining[idx])
      table.remove(remaining, idx)
    end
  end

  if state.strum_delay <= 0 then
    -- No strum: play all notes together
    for _, n in ipairs(play_notes) do
      local vel = get_velocity(base_vel)
      local freq = midi_to_hz(n)
      local engine_id = state.next_engine_id
      engine.noteOn(engine_id, freq, vel / 127)
      state.engine_notes[n] = engine_id
      state.next_engine_id = state.next_engine_id + 1
      
      if midi_out then
        pcall(function() midi_out:note_on(n, vel, state.midi_channel) end)
      end
      -- ENHANCEMENT 1: Track sustained notes
      if state.sustain_held then
        state.sustained_notes[n] = true
      end
    end
  else
    -- Strum effect: play notes with incremental delays
    local delay_ms = state.strum_delay
    local delay_sec = delay_ms / 1000

    -- Trigger strum animation
    state.strum_flash_time = 3

    clock.run(function()
      for idx, n in ipairs(play_notes) do
        local vel = get_velocity(base_vel)
        local freq = midi_to_hz(n)
        local engine_id = state.next_engine_id
        engine.noteOn(engine_id, freq, vel / 127)
        state.engine_notes[n] = engine_id
        state.next_engine_id = state.next_engine_id + 1
        
        if midi_out then
          pcall(function() midi_out:note_on(n, vel, state.midi_channel) end)
        end
        -- ENHANCEMENT 1: Track sustained notes
        if state.sustain_held then
          state.sustained_notes[n] = true
        end
        if idx < num_notes then
          clock.sleep(delay_sec)
        end
      end
    end)
  end
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  CHORD GENERATION
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

local function build_chord(root_idx, chord_type_idx, octave_num)
  local ct = CHORD_SHAPES[chord_type_idx]
  if not ct then return {} end
  
  local base = (octave_num + 1) * 12 + (root_idx - 1)
  local notes = {}
  
  for _, interval in ipairs(ct.intervals) do
    local n = base + interval
    if n >= 0 and n <= 127 then
      table.insert(notes, n)
    end
  end
  
  return notes
end

local function note_num_to_name(midi_note)
  if midi_note < 0 or midi_note > 127 then return "?" end
  local octave = math.floor(midi_note / 12) - 1
  local pitch = midi_note % 12
  return NOTES[pitch + 1] .. octave
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  AUDIO ENGINE CONTROL
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

local function play_chord(root_idx, type_idx, octave_num, vel)
  local notes = build_chord(root_idx, type_idx, octave_num)
  play_chord_with_strum(notes, vel or state.velocity_base)
  state.last_chord_root = root_idx
  state.last_chord_type = type_idx
  state.suggested_chords = suggest_next_chord(root_idx, type_idx)
  state.suggestion_display_time = 30

  -- ENHANCEMENT 3: Screen chord name display
  local chord_quality = CHORD_SHAPES[type_idx].name
  state.last_triggered_chord_name = NOTES[root_idx] .. chord_quality
  state.chord_display_time = 40  -- display for ~4 seconds at 10fps
end

local function all_notes_off()
  engine.noteOffAll()
  if midi_out then
    for ch = 1, 16 do
      pcall(function() midi_out:cc(123, 0, ch) end)
    end
  end
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  GRID REDRAW
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

local function grid_redraw()
  if not g or not g.cols or g.cols == 0 then return end
  g:all(0)

  -- Row 1: chromatic keyboard
  local white_keys = {1, 3, 5, 6, 8, 10, 12}
  for col = 1, 12 do
    local is_white = false
    for _, wk in ipairs(white_keys) do
      if col == wk then
        is_white = true
        break
      end
    end
    local brightness = (is_white and 6 or 3)
    if col == state.root_note then
      brightness = 15
    end
    g:led(col, 1, brightness)
  end

  -- Row 2: octave controls
  g:led(1, 2, state.octave > 2 and 8 or 2)
  g:led(2, 2, state.octave < 7 and 8 or 2)
  for col = 3, 12 do
    g:led(col, 2, 2)
  end

  -- Rows 3-5: chord type selector
  for col = 1, 4 do
    for row = 3, 5 do
      local brightness = (col == state.chord_type and row == 3) and 15 or 4
      g:led(col, row, brightness)
    end
  end

  -- Rows 6-8: utility and status
  g:led(1, 6, state.strum_time > 0 and 10 or 2)
  g:led(2, 6, 2)
  
  g:refresh()
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  SCREEN REDRAW - NEW DESIGN
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

function redraw()
  screen.clear()
  screen.aa(1)
  
  if state.page_a then
    -- ─ PAGE A: traditional menu ─
    screen.level(15)
    screen.move(0, 10)
    screen.text("HICHORD v3.0")
    
    screen.level(8)
    screen.move(0, 22)
    screen.text(NOTES[state.root_note] .. " " .. CHORD_SHAPES[state.chord_type].name)
    
    screen.level(5)
    screen.move(0, 34)
    screen.text("Oct: " .. state.octave .. "  BPM: " .. state.bpm)
    
    screen.level(5)
    screen.move(0, 46)
    screen.text("Strum: " .. state.strum_time .. "ms")
    
    -- Chord suggestions
    if state.suggestion_display_time > 0 then
      screen.level(12)
      screen.move(0, 58)
      local sugg_text = "Next: "
      for i, sugg in ipairs(state.suggested_chords) do
        if i <= 2 then
          sugg_text = sugg_text .. NOTES[sugg.root] .. " "
        end
      end
      screen.text(sugg_text)
    end
    
  else
    -- ─ PAGE B: animated HiChord OLED replica ─
    
    -- ▐ SECTION 1: STATUS STRIP (y 0-8) ▐
    screen.level(4)
    screen.move(2, 7)
    screen.text("HICHORD")
    
    -- Current chord name at center, large and bright
    screen.level(12)
    screen.move(64, 8)
    screen.text_center(NOTES[state.root_note] .. CHORD_SHAPES[state.chord_type].name)
    
    -- Beat pulse dot at x=124 (right side)
    local pulse_brightness = math.floor(8 + state.beat_phase * 7)
    screen.level(pulse_brightness)
    screen.circle(124, 4, 1.5)
    screen.fill()
    
    -- ▐ SECTION 2: LIVE ZONE (y 9-52) ▐
    -- Show 7 chord slots as horizontal row of blocks
    local slot_width = 15
    local slot_height = 12
    local slot_y = 12
    local slot_x_start = 5
    
    for slot = 1, 7 do
      local x = slot_x_start + (slot - 1) * (slot_width + 2)
      local chord = state.chord_slots[slot]
      
      -- Determine brightness: active=15, adjacent=8, distant=4
      local is_active = (slot == state.active_slot)
      local is_adjacent = (math.abs(slot - state.active_slot) == 1)
      local brightness = is_active and 15 or (is_adjacent and 8 or 4)
      
      screen.level(brightness)
      screen.rect(x, slot_y, slot_width, slot_height)
      screen.stroke()
      
      -- Flash animation if strummed
      if is_active and state.strum_flash_time > 0 then
        screen.level(15)
        screen.rect(x - 1, slot_y - 1, slot_width + 2, slot_height + 2)
        screen.stroke()
      end
      
      -- Label chord in slot
      screen.level(brightness)
      screen.move(x + slot_width/2, slot_y + 8)
      screen.text_center(NOTES[chord.root])
    end
    
    -- Below slots: show active chord's individual notes
    local active_chord = state.chord_slots[state.active_slot]
    local active_notes = build_chord(active_chord.root, active_chord.type or 3, state.octave)
    screen.level(6)
    screen.move(5, 32)
    local note_text = ""
    for i, n in ipairs(active_notes) do
      if i > 1 then note_text = note_text .. " " end
      note_text = note_text .. note_num_to_name(n)
    end
    screen.text(note_text)
    
    -- Chord suggestion: show suggested next chord near active slot
    if state.suggestion_display_time > 0 and #state.suggested_chords > 0 then
      local sugg = state.suggested_chords[1]
      screen.level(4)
      screen.move(122, 32)
      screen.text_center("↓")
      screen.move(122, 40)
      screen.text_center(NOTES[sugg.root])
    end
    
    -- Loop progress bar
    if state.loop_recording or state.loop_playing then
      screen.level(state.loop_recording and 10 or 8)
      local bar_y = 44
      local bar_width = 120
      local bar_x = 5
      
      -- Background bar
      screen.level(2)
      screen.rect(bar_x, bar_y, bar_width, 4)
      screen.fill()
      
      -- Progress indicator
      screen.level(state.loop_recording and 15 or 12)
      local progress_width = bar_width * state.loop_position
      screen.rect(bar_x, bar_y, progress_width, 4)
      screen.fill()
      
      -- Status text
      screen.level(8)
      screen.move(bar_x + bar_width + 5, bar_y + 3)
      screen.text(state.loop_recording and "REC" or "PLAY")
    end
    
    -- ▐ SECTION 3: CONTEXT BAR (y 53-58) ▐
    screen.level(5)
    screen.move(5, 58)
    screen.text(WAVEFORMS[state.waveform_type])
    
    screen.level(4)
    screen.move(40, 58)
    screen.text("A" .. state.adsr_a .. " D" .. state.adsr_d .. " S" .. state.adsr_s .. " R" .. state.adsr_r)
    
    screen.level(6)
    screen.move(100, 58)
    screen.text(state.loop_playing and "LOOP" or (state.loop_recording and "REC" or "---"))
    
    screen.level(4)
    screen.move(122, 58)
    screen.text("CH" .. state.midi_channel)
    
    -- ▐ SECTION 4: TRANSIENT PARAMETER POPUP ▐
    if state.popup_time > 0 and state.popup_param then
      local pop_y = 30
      local pop_x = 64

      screen.level(12)
      screen.move(pop_x, pop_y)
      screen.text_center(state.popup_param)

      screen.level(10)
      screen.move(pop_x, pop_y + 10)
      screen.text_center(tostring(state.popup_val))
    end

    -- ENHANCEMENT 3: Screen chord name display (large centered text)
    if state.chord_display_time > 0 and state.last_triggered_chord_name ~= "" then
      screen.level(15)
      screen.font_size(24)
      screen.move(64, 35)
      screen.text_center(state.last_triggered_chord_name)
      screen.font_size(8)
    end
  end

  screen.update()
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  NORNS INPUT
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

function key(n, z)
  if n == 1 and z == 1 then
    state.page_a = not state.page_a
  elseif n == 2 and z == 1 then
    state.chord_type = (state.chord_type % 4) + 1
  elseif n == 3 and z == 1 then
    state.octave = math.min(7, state.octave + 1)
  end
  grid_redraw()
  redraw()
end

function enc(n, d)
  if n == 1 then
    state.root_note = ((state.root_note - 1 + d) % 12) + 1
    state.popup_param = "ROOT"
    state.popup_val = NOTES[state.root_note]
    state.popup_time = 8
  elseif n == 2 then
    state.chord_type = util.clamp(state.chord_type + d, 1, #CHORD_SHAPES)
    state.popup_param = "CHORD"
    state.popup_val = CHORD_SHAPES[state.chord_type].name
    state.popup_time = 8
  elseif n == 3 then
    state.strum_time = math.max(0, math.min(100, state.strum_time + d))
    state.popup_param = "STRUM"
    state.popup_val = state.strum_time .. "ms"
    state.popup_time = 8
  end
  grid_redraw()
  redraw()
end

function g.key(x, y, z)
  if y == 1 and z == 1 then
    if x >= 1 and x <= 12 then
      state.root_note = x
    end
  elseif y == 2 and z == 1 then
    if x == 1 then state.octave = math.max(2, state.octave - 1)
    elseif x == 2 then state.octave = math.min(7, state.octave + 1)
    end
  elseif y >= 3 and y <= 5 and z == 1 then
    if x <= 4 then
      state.chord_type = util.clamp(x, 1, #CHORD_SHAPES)
      -- ENHANCEMENT 4: Track held grid buttons for dynamic velocity
      state.grid_buttons_held = state.grid_buttons_held + 1
      play_chord(state.root_note, state.chord_type, state.octave)
    end
  elseif y >= 3 and y <= 5 and z == 0 then
    if x <= 4 then
      -- ENHANCEMENT 4: Decrement held button count
      state.grid_buttons_held = math.max(0, state.grid_buttons_held - 1)
    end
  end
  grid_redraw()
  redraw()
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  MIDI EVENT HANDLER
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

function midi.event(data)
  -- ENHANCEMENT 1: Sustain pedal MIDI (CC64)
  local msg = midi.to_msg(data)

  if msg.type == "cc" and msg.cc == 64 then
    if msg.val >= 64 then
      -- Sustain pedal pressed
      state.sustain_held = true
      state.sustained_notes = {}
    else
      -- Sustain pedal released: send note_off for all sustained notes
      state.sustain_held = false
      for note_num, engine_id in pairs(state.sustained_notes) do
        engine.noteOff(engine_id)
        if midi_out then
          pcall(function() midi_out:note_off(note_num, 0, state.midi_channel) end)
        end
      end
      state.sustained_notes = {}
    end
  end
end

-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐
--  INIT
-- ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐

function init()
  -- Initialize chord slots with notes
  for slot = 1, 7 do
    state.chord_slots[slot].notes = build_chord(
      state.chord_slots[slot].root,
      state.chord_slots[slot].type or 3,
      state.octave
    )
  end

  -- ENHANCEMENT 2: Add strum_delay parameter (0-80ms)
  params:add_control("strum_delay", "Strum Delay", ControlSpec.new(0, 80, "lin", 1, 20, "ms"))
  params:set_action("strum_delay", function(val)
    state.strum_delay = val
  end)

  -- ENHANCEMENT 2: Add strum_direction parameter (up/down/random)
  params:add_option("strum_direction", "Strum Direction", {"up", "down", "random"}, 1)
  params:set_action("strum_direction", function(val)
    state.strum_direction = val
  end)

  -- ENHANCEMENT 4: Add velocity_mode parameter (fixed/random/dynamic)
  params:add_option("velocity_mode", "Velocity Mode", {"fixed", "random", "dynamic"}, 1)
  params:set_action("velocity_mode", function(val)
    state.velocity_mode = val
  end)

  -- ENHANCEMENT 4: Add velocity_base parameter (1-127)
  params:add_control("velocity_base", "Velocity Base", ControlSpec.new(1, 127, "lin", 1, 100, ""))
  params:set_action("velocity_base", function(val)
    state.velocity_base = val
  end)

  clock.run(function()
    while true do
      -- Update animations at ~10fps
      state.beat_phase = (state.beat_phase + 0.1) % 1.0

      if state.suggestion_display_time > 0 then
        state.suggestion_display_time = state.suggestion_display_time - 1
      end

      if state.popup_time > 0 then
        state.popup_time = state.popup_time - 1
      end

      if state.strum_flash_time > 0 then
        state.strum_flash_time = state.strum_flash_time - 1
      end

      -- ENHANCEMENT 3: Decrement chord display timer
      if state.chord_display_time > 0 then
        state.chord_display_time = state.chord_display_time - 1
      end

      -- Update loop position
      if state.loop_playing or state.loop_recording then
        state.loop_position = (state.loop_position + 0.05) % 1.0
      end

      redraw()
      grid_redraw()
      clock.sleep(0.1)
    end
  end)

  redraw()
  grid_redraw()
end

function cleanup()
  all_notes_off()
  clock.cancel_all()
end
