-- hichord.lua  v3.0 with OP-XY MIDI
-- Norns port of HiChord (hichord.shop) firmware 2.6.9
-- Grid = physical HiChord device replica (16×8)
-- Norns screen Page A = traditional param/menu display
-- Norns screen Page B = animated HiChord OLED replica
-- OP-XY MIDI: strum timing mapped to CC 20 (attack)

engine.name = "MollyThePoly"
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"

local ControlSpec = require "controlspec"
local tab = require "tabutil"

-- OP-XY MIDI helpers
local opxy_out = nil
local function opxy_note_on(note, vel)
  if opxy_out and params:get("opxy_enabled") == 2 then
    opxy_out:note_on(note, vel, params:get("opxy_channel"))
  end
end
local function opxy_note_off(note)
  if opxy_out and params:get("opxy_enabled") == 2 then
    opxy_out:note_off(note, 0, params:get("opxy_channel"))
  end
end
local function opxy_cc(cc, val)
  if opxy_out and params:get("opxy_enabled") == 2 then
    opxy_out:cc(cc, math.floor(util.clamp(val, 0, 127)), params:get("opxy_channel"))
  end
end

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
  beat_phase = 0,
  popup_param = nil,
  popup_val = nil,
  popup_time = 0,

  -- active chord slot (1-7) for visualization
  active_slot = 1,
  chord_slots = {
    {root=1, type=3, notes={}},
    {root=5, type=3, notes={}},
    {root=8, type=3, notes={}},
    {root=10, type=2, notes={}},
    {root=1, type=2, notes={}},
    {root=5, type=2, notes={}},
    {root=8, type=2, notes={}},
  },

  loop_recording = false,
  loop_playing = false,
  loop_position = 0,
  loop_length = 16,

  waveform_type = 1,
  adsr_a = 10, adsr_d = 20, adsr_s = 80, adsr_r = 30,
  midi_channel = 1,
  strum_flash_time = 0,

  sustain_held = false,
  sustained_notes = {},

  strum_delay = 20,
  strum_direction = 1,

  last_triggered_chord_name = "",
  chord_display_time = 0,

  velocity_mode = 1,
  velocity_base = 100,
  grid_buttons_held = 0,
  
  engine_notes = {},
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

local function suggest_next_chord(current_root, current_type)
  if not current_root or current_root < 1 or current_root > 12 then
    current_root = 1
  end
  
  local sugg_map = {
    [1] = {
      {root=5, type=3},
      {root=8, type=3},
      {root=10, type=2},
    },
    [5] = {
      {root=12, type=3},
      {root=1, type=3},
      {root=8, type=3},
    },
    [8] = {
      {root=1, type=3},
      {root=5, type=3},
      {root=8, type=2},
    },
    [10] = {
      {root=1, type=3},
      {root=5, type=3},
      {root=8, type=3},
    },
  }
  
  return sugg_map[current_root] or {
    {root=5, type=3}, {root=8, type=3}
  }
end

local function get_velocity(base_vel)
  if state.velocity_mode == 2 then
    return math.max(1, math.min(127, base_vel + math.random(-15, 15)))
  elseif state.velocity_mode == 3 then
    local extra = state.grid_buttons_held * 5
    return math.max(1, math.min(127, base_vel + extra))
  else
    return util.clamp(base_vel, 0, 127)
  end
end

local function play_chord_with_strum(notes, velocity)
  local num_notes = #notes
  if num_notes == 0 then return end

  local base_vel = velocity or state.velocity_base
  base_vel = util.clamp(base_vel, 0, 127)

  local play_notes = notes
  if state.strum_direction == 2 then
    play_notes = {}
    for i = num_notes, 1, -1 do
      table.insert(play_notes, notes[i])
    end
  elseif state.strum_direction == 3 then
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
      opxy_note_on(n, vel)
      
      if state.sustain_held then
        state.sustained_notes[n] = engine_id
      end
    end
    -- Map strum timing to CC 20 (attack): no strum = fast attack
    opxy_cc(20, 127)
  else
    local delay_ms = state.strum_delay
    local delay_sec = delay_ms / 1000

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
        opxy_note_on(n, vel)
        
        if state.sustain_held then
          state.sustained_notes[n] = engine_id
        end
        if idx < num_notes then
          clock.sleep(delay_sec)
        end
      end
    end)
    
    -- Map strum timing to CC 20 (attack): slower strum = longer attack
    local attack_cc = math.floor((state.strum_delay / 100) * 127)
    opxy_cc(20, attack_cc)
  end
end

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

local function play_chord(root_idx, type_idx, octave_num, vel)
  local notes = build_chord(root_idx, type_idx, octave_num)
  play_chord_with_strum(notes, vel or state.velocity_base)
  state.last_chord_root = root_idx
  state.last_chord_type = type_idx
  state.suggested_chords = suggest_next_chord(root_idx, type_idx)
  state.suggestion_display_time = 30

  local chord_quality = CHORD_SHAPES[type_idx].name
  state.last_triggered_chord_name = NOTES[root_idx] .. chord_quality
  state.chord_display_time = 40
end

local function all_notes_off()
  engine.noteKillAll()
  if midi_out then
    for ch = 1, 16 do
      pcall(function() midi_out:cc(123, 0, ch) end)
    end
  end
  if opxy_out and params:get("opxy_enabled") == 2 then
    for ch=1,16 do opxy_out:cc(123, 0, ch) end
  end
end

local function grid_redraw()
  if not g.device then return end
  if not g or not g.cols or g.cols == 0 then return end
  g:all(0)

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

  g:led(1, 2, state.octave > 2 and 8 or 2)
  g:led(2, 2, state.octave < 7 and 8 or 2)
  for col = 3, 12 do
    g:led(col, 2, 2)
  end

  for col = 1, 4 do
    for row = 3, 5 do
      local brightness = (col == state.chord_type and row == 3) and 15 or 4
      g:led(col, row, brightness)
    end
  end

  g:led(1, 6, state.strum_time > 0 and 10 or 2)
  g:led(2, 6, 2)
  
  g:refresh()
end

function redraw()
  screen.clear()
  screen.aa(1)
  
  if state.page_a then
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
    
    -- OP-XY status
    screen.level(5)
    screen.move(60, 34)
    if params:get("opxy_enabled") == 2 then
      screen.text("OP-XY: CH" .. params:get("opxy_channel"))
    else
      screen.text("OP-XY: OFF")
    end
  else
    -- PAGE B: animated display
    screen.level(4)
    screen.move(2, 7)
    screen.text("HICHORD")
    
    screen.level(12)
    screen.move(64, 8)
    screen.text_center(NOTES[state.root_note] .. CHORD_SHAPES[state.chord_type].name)
    
    local pulse_brightness = math.floor(8 + state.beat_phase * 7)
    screen.level(pulse_brightness)
    screen.circle(124, 4, 1.5)
    screen.fill()
    
    local slot_width = 15
    local slot_height = 12
    local slot_y = 12
    local slot_x_start = 5
    
    for slot = 1, 7 do
      local x = slot_x_start + (slot - 1) * (slot_width + 2)
      local chord = state.chord_slots[slot]
      
      local is_active = (slot == state.active_slot)
      local is_adjacent = (math.abs(slot - state.active_slot) == 1)
      local brightness = is_active and 15 or (is_adjacent and 8 or 4)
      
      screen.level(brightness)
      screen.rect(x, slot_y, slot_width, slot_height)
      screen.stroke()
      
      if is_active and state.strum_flash_time > 0 then
        screen.level(15)
        screen.rect(x - 1, slot_y - 1, slot_width + 2, slot_height + 2)
        screen.stroke()
      end
      
      screen.level(brightness)
      screen.move(x + slot_width/2, slot_y + 8)
      screen.text_center(NOTES[chord.root])
    end
    
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
    
    if state.suggestion_display_time > 0 and #state.suggested_chords > 0 then
      local sugg = state.suggested_chords[1]
      screen.level(4)
      screen.move(122, 32)
      screen.text_center("↓")
      screen.move(122, 40)
      screen.text_center(NOTES[sugg.root])
    end
    
    if state.loop_recording or state.loop_playing then
      screen.level(state.loop_recording and 10 or 8)
      local bar_y = 44
      local bar_width = 120
      local bar_x = 5
      
      screen.level(2)
      screen.rect(bar_x, bar_y, bar_width, 4)
      screen.fill()
      
      screen.level(state.loop_recording and 15 or 12)
      local progress_width = bar_width * state.loop_position
      screen.rect(bar_x, bar_y, progress_width, 4)
      screen.fill()
      
      screen.level(8)
      screen.move(bar_x + bar_width + 5, bar_y + 3)
      screen.text(state.loop_recording and "REC" or "PLAY")
    end
    
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

function key(n, z)
  if n == 1 then
    k1_held = (z == 1)
    return
  elseif n == 2 and z == 1 then
    if k1_held then
      state.page_a = not state.page_a
    else
      state.chord_type = (state.chord_type % 4) + 1
    end
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
      state.grid_buttons_held = state.grid_buttons_held + 1
      play_chord(state.root_note, state.chord_type, state.octave)
    end
  elseif y >= 3 and y <= 5 and z == 0 then
    if x <= 4 then
      state.grid_buttons_held = math.max(0, state.grid_buttons_held - 1)
    end
  end
  grid_redraw()
  redraw()
end

function midi.event(data)
  local msg = midi.to_msg(data)

  if msg.type == "cc" and msg.cc == 64 then
    if msg.val >= 64 then
      state.sustain_held = true
      state.sustained_notes = {}
    else
      state.sustain_held = false
      for note_num, engine_id in pairs(state.sustained_notes) do
        engine.noteOff(engine_id)
        if midi_out then
          pcall(function() midi_out:note_off(note_num, 0, state.midi_channel) end)
        end
        opxy_note_off(note_num)
      end
      state.sustained_notes = {}
    end
  end
end

function init()
  -- MollyThePoly sound params
  MollyThePoly.add_params()
  -- Warm chord preset
  params:set("osc_wave_shape", 0.3)
  params:set("lp_filter_cutoff", 2000)
  params:set("lp_filter_resonance", 0.15)
  params:set("env_2_attack", 0.01)
  params:set("env_2_decay", 0.8)
  params:set("env_2_sustain", 0.6)
  params:set("env_2_release", 1.0)

  for slot = 1, 7 do
    state.chord_slots[slot].notes = build_chord(
      state.chord_slots[slot].root,
      state.chord_slots[slot].type or 3,
      state.octave
    )
  end

  params:add_separator("OP-XY")
  params:add_option("opxy_enabled", "OP-XY output", {"off", "on"}, 1)
  params:add_number("opxy_device", "OP-XY MIDI device", 1, 4, 1)
  params:add_number("opxy_channel", "OP-XY channel", 1, 8, 1)
  params:set_action("opxy_device", function(v) opxy_out = midi.connect(v) end)

  params:add_control("strum_delay", "Strum Delay", ControlSpec.new(0, 80, "lin", 1, 20, "ms"))
  params:set_action("strum_delay", function(val)
    state.strum_delay = val
  end)

  params:add_option("strum_direction", "Strum Direction", {"up", "down", "random"}, 1)
  params:set_action("strum_direction", function(val)
    state.strum_direction = val
  end)

  params:add_option("velocity_mode", "Velocity Mode", {"fixed", "random", "dynamic"}, 1)
  params:set_action("velocity_mode", function(val)
    state.velocity_mode = val
  end)

  params:add_control("velocity_base", "Velocity Base", ControlSpec.new(1, 127, "lin", 1, 100, ""))
  params:set_action("velocity_base", function(val)
    state.velocity_base = val
  end)

  clock.run(function()
    while true do
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

      if state.chord_display_time > 0 then
        state.chord_display_time = state.chord_display_time - 1
      end

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
