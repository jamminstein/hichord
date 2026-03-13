-- hichord.lua  v3.0
-- Norns port of HiChord (hichord.shop) firmware 2.6.9
-- Grid = physical HiChord device replica (16×8)
-- Norns screen Page A = traditional param/menu display
-- Norns screen Page B = animated HiChord OLED replica
--
-- ══════════════════════════════════════════════════════════════
--  GRID LAYOUT  (16 cols × 8 rows)  mirrors HiChord hardware
-- ══════════════════════════════════════════════════════════════
--
--   Col:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
-- Row 1: [──────── KEY SELECTOR  C C# D D# E F F# G G# A A# B ────]
-- Row 2: [──────── SCALE / MODE label row (dim indicators) ─────────]
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
-- ══════════════════════════════════════════════════════════════
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

engine.name = "PolyPerc"

local ControlSpec = require "controlspec"
local tab = require "tabutil"

-- ═══════════════════════════════════════════════════════════════════
--  STATE & SETUP
-- ═══════════════════════════════════════════════════════════════════

local g = grid.connect()
local midi_out = nil

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
}

local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local CHORD_SHAPES = {
  {name="MAJ",   intervals={0,4,7}},
  {name="MIN",   intervals={0,3,7}},
  {name="DOM7",  intervals={0,4,7,10}},
  {name="MIN7",  intervals={0,3,7,10}},
}

-- ═══════════════════════════════════════════════════════════════════
--  NEW: CHORD SUGGESTION ENGINE
-- ═══════════════════════════════════════════════════════════════════

local function suggest_next_chord(current_root, current_type)
  -- Music theory: common progressions in diatonic harmony
  -- Returns up to 3 suggested {root, type} pairs
  
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

-- ═══════════════════════════════════════════════════════════════════
--  NEW: STRUM TIMING HELPER
-- ═══════════════════════════════════════════════════════════════════

local function play_chord_with_strum(notes, velocity)
  if state.strum_time <= 0 then
    -- No strum: play all notes together
    for _, n in ipairs(notes) do
      engine.noteOn(n, velocity or 100)
      if midi_out then
        pcall(function() midi_out:note_on(n, velocity or 100, 1) end)
      end
    end
  else
    -- Strum effect: play notes with incremental delays
    local num_notes = #notes
    if num_notes == 0 then return end
    
    local delay_ms = state.strum_time / num_notes
    local delay_sec = delay_ms / 1000
    
    clock.run(function()
      for _, n in ipairs(notes) do
        engine.noteOn(n, velocity or 100)
        if midi_out then
          pcall(function() midi_out:note_on(n, velocity or 100, 1) end)
        end
        if _ < num_notes then
          clock.sleep(delay_sec)
        end
      end
    end)
  end
end

-- ═══════════════════════════════════════════════════════════════════
--  CHORD GENERATION
-- ═══════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════
--  AUDIO ENGINE CONTROL
-- ═══════════════════════════════════════════════════════════════════

local function play_chord(root_idx, type_idx, octave_num, vel)
  local notes = build_chord(root_idx, type_idx, octave_num)
  play_chord_with_strum(notes, vel or 100)
  state.last_chord_root = root_idx
  state.last_chord_type = type_idx
  state.suggested_chords = suggest_next_chord(root_idx, type_idx)
  state.suggestion_display_time = 30
end

local function all_notes_off()
  engine.allOff()
  if midi_out then
    for ch = 1, 16 do
      pcall(function() midi_out:cc(123, 0, ch) end)
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════
--  GRID REDRAW
-- ═══════════════════════════════════════════════════════════════════

local function grid_redraw()
  if not g or not g.cols or g.cols == 0 then return end
  g:all(0)

  -- Row 1: chromatic keyboard
  local white_keys = {1, 3, 5, 6, 8, 10, 12}
  for col = 1, 12 do
    local is_white = tab.contains(white_keys, col)
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

-- ═══════════════════════════════════════════════════════════════════
--  SCREEN REDRAW
-- ═══════════════════════════════════════════════════════════════════

function redraw()
  screen.clear()
  screen.aa(0)
  
  if state.page_a then
    -- Page A: traditional menu
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
    -- Page B: visualization
    screen.level(15)
    screen.move(64, 10)
    screen.text_center("HICHORD")
    
    screen.level(12)
    screen.move(64, 24)
    screen.text_center(NOTES[state.root_note] .. CHORD_SHAPES[state.chord_type].name)
    
    screen.level(8)
    screen.move(64, 40)
    screen.text_center("Octave " .. state.octave)
    
    if state.strum_time > 0 then
      screen.level(10)
      screen.move(64, 54)
      screen.text_center("Strum " .. state.strum_time .. "ms")
    end
  end

  screen.update()
end

-- ═══════════════════════════════════════════════════════════════════
--  NORNS INPUT
-- ═══════════════════════════════════════════════════════════════════

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
  elseif n == 2 then
    state.chord_type = math.max(1, math.min(4, state.chord_type + d))
  elseif n == 3 then
    state.strum_time = math.max(0, math.min(100, state.strum_time + d))
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
      state.chord_type = x
      play_chord(state.root_note, state.chord_type, state.octave, 100)
    end
  end
  grid_redraw()
  redraw()
end

-- ═══════════════════════════════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════════════════════════════

function init()
  clock.run(function()
    while true do
      if state.suggestion_display_time > 0 then
        state.suggestion_display_time = state.suggestion_display_time - 1
      end
      redraw()
      grid_redraw()
      clock.sleep(0.05)
    end
  end)
  
  redraw()
  grid_redraw()
end

function cleanup()
  all_notes_off()
  clock.cancel_all()
end
