-- hichord.lua  v5.0 — Sunday Service + Drums Edition
-- Norns port of HiChord (hichord.shop) firmware 2.6.9
-- Grid = physical HiChord device replica (16×8)
-- Norns screen Page A = traditional param/menu display
-- Norns screen Page B = animated HiChord OLED replica
-- Page C = SUNDAY SERVICE gospel-hip-hop automation
-- Page D = DRUMS humanized sequencer
-- OP-XY MIDI: strum timing mapped to CC 20 (attack)

engine.name = "SundayService"

local ControlSpec = require "controlspec"
local tab = require "tabutil"
local gospel = require "hichord/lib/gospel"
local drums = require "hichord/lib/drums"

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
local screen_clock_id = nil

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

  -- Sunday Service gospel automation
  gospel_mode = false,     -- true = Page C active, gospel engine running
  gospel_state = nil,      -- initialized in init()
  gospel_clock_id = nil,
  gospel_page = false,     -- show gospel display (Page C)

  -- Drums
  drums_page = false,      -- show drums display (Page D)
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
      engine.noteOn(n, vel / 127)
      state.engine_notes[n] = true

      if midi_out then
        pcall(function() midi_out:note_on(n, vel, state.midi_channel) end)
      end
      opxy_note_on(n, vel)

      if state.sustain_held then
        state.sustained_notes[n] = true
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
        engine.noteOn(n, vel / 127)
        state.engine_notes[n] = true

        if midi_out then
          pcall(function() midi_out:note_on(n, vel, state.midi_channel) end)
        end
        opxy_note_on(n, vel)

        if state.sustain_held then
          state.sustained_notes[n] = true
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

----------------------------------------------------------------------
-- SUNDAY SERVICE: gospel voice playback via engine + MIDI
----------------------------------------------------------------------
local function gospel_voice_on(note, voice_type, vel)
  -- Use SundayService engine voiceOn: note, velocity, voiceType, pan
  local pan = gospel.VOICE_PAN[voice_type] or 0
  engine.voiceOn(note, vel, voice_type, pan)
  state.engine_notes[note * 10 + voice_type] = true

  -- Also send MIDI with voice-type-specific channel offsets
  if midi_out then
    local ch = math.min(16, state.midi_channel + voice_type)
    pcall(function() midi_out:note_on(note, math.floor(vel * 127), ch) end)
  end
  opxy_note_on(note, math.floor(vel * 100))
end

local function gospel_voice_off(note, voice_type)
  local key = note * 10 + voice_type
  if state.engine_notes[key] then
    engine.voiceOff(note, voice_type)
    state.engine_notes[key] = nil
  end
  if midi_out then
    local ch = math.min(16, state.midi_channel + voice_type)
    pcall(function() midi_out:note_off(note, 0, ch) end)
  end
  opxy_note_off(note)
end

local function gospel_all_off()
  engine.allVoicesOff()
  state.engine_notes = {}
  all_notes_off()
end

-- Start the Sunday Service automation clock
local function gospel_start()
  if state.gospel_clock_id then return end
  state.gospel_mode = true
  gospel.start(state.gospel_state)

  state.gospel_clock_id = clock.run(function()
    while state.gospel_mode do
      local result = gospel.tick(state.gospel_state)

      -- Process note-offs
      for _, v in ipairs(result.notes_off) do
        gospel_voice_off(v.note, v.voice)
      end

      -- Process note-ons with humanized timing
      local humanize = state.gospel_state.humanize
      for i, v in ipairs(result.notes_on) do
        if humanize > 0 and i > 1 then
          -- Subtle timing offset for human feel
          clock.sleep((math.random() * 0.03) * humanize)
        end
        gospel_voice_on(v.note, v.voice, v.vel)
      end

      -- Wait one beat
      clock.sync(1)
    end
  end)
end

local function gospel_stop()
  state.gospel_mode = false
  local offs = gospel.stop(state.gospel_state)
  for _, v in ipairs(offs) do
    gospel_voice_off(v.note, v.voice)
  end
  gospel_all_off()
  if state.gospel_clock_id then
    clock.cancel(state.gospel_clock_id)
    state.gospel_clock_id = nil
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

  -- Row 7: Sunday Service controls
  -- col 1 = gospel start/stop, col 2 = build, col 3-10 = progression select
  -- col 11-12 = call/response mode
  g:led(1, 7, state.gospel_mode and 15 or 4)
  g:led(2, 7, (state.gospel_state and state.gospel_state.building) and 12 or 4)
  if state.gospel_state then
    for i, name in ipairs(gospel.PROGRESSION_NAMES) do
      if i <= 8 then
        local bright = (name == state.gospel_state.progression_name) and 15 or 5
        g:led(i + 2, 7, bright)
      end
    end
    -- Call/response modes
    for i = 1, math.min(4, #gospel.CALL_RESPONSE_NAMES) do
      local bright = (gospel.CALL_RESPONSE_NAMES[i] == state.gospel_state.call_response_mode) and 12 or 3
      g:led(i + 12, 7, bright)
    end
  end

  -- Row 8: intensity (columns 1-12 = intensity meter/control), col 13-16 = key select
  if state.gospel_state then
    local int_level = math.floor(state.gospel_state.intensity * 12)
    for col = 1, 12 do
      g:led(col, 8, col <= int_level and 10 or 2)
    end
    for i, gk in ipairs(gospel.GOSPEL_KEYS) do
      if i <= 4 then
        local bright = (gk.root == state.gospel_state.key_root) and 15 or 5
        g:led(i + 12, 8, bright)
      end
    end
  end

  g:refresh()
end

function redraw()
  screen.clear()
  screen.aa(0)
  
  if state.gospel_page then
    -- PAGE C: SUNDAY SERVICE gospel automation display
    local gs = state.gospel_state

    -- Header
    screen.level(15)
    screen.move(0, 8)
    screen.text("SUNDAY SERVICE")
    screen.level(gs.active and 15 or 4)
    screen.move(100, 8)
    screen.text(gs.active and "LIVE" or "STOP")

    -- Current chord (large)
    if gs.display_chord_name ~= "" then
      screen.level(15)
      screen.font_size(16)
      screen.move(64, 26)
      screen.text_center(gs.display_chord_name)
      screen.font_size(8)
    end

    -- Progression name
    screen.level(6)
    screen.move(0, 34)
    screen.text(gs.progression_name)
    screen.move(70, 34)
    screen.text("step " .. gs.progression_step)

    -- Voice count and intensity bar
    screen.level(5)
    screen.move(0, 42)
    screen.text("voices: " .. gs.display_voice_count)

    -- Intensity bar
    screen.level(3)
    screen.rect(55, 37, 60, 5)
    screen.stroke()
    screen.level(12)
    screen.rect(55, 37, math.floor(60 * gs.intensity), 5)
    screen.fill()
    if gs.building then
      screen.level(15)
      screen.move(117, 42)
      screen.text("BUILD")
    end

    -- Call/response indicator
    screen.level(gs.call_response_phase == "call" and 12 or 5)
    screen.move(0, 50)
    screen.text("CALL")
    screen.level(gs.call_response_phase == "respond" and 12 or 5)
    screen.move(30, 50)
    screen.text("RESP")
    screen.level(4)
    screen.move(60, 50)
    screen.text(gs.call_response_mode)

    -- Next chords suggestion
    local suggestions = gospel.suggest_next(gs)
    screen.level(4)
    screen.move(0, 58)
    screen.text("next:")
    screen.level(8)
    for i, s in ipairs(suggestions) do
      if i <= 3 then
        screen.move(28 + (i-1) * 35, 58)
        screen.text(s.name)
      end
    end

    -- Key display
    local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    screen.level(6)
    screen.move(110, 58)
    screen.text("K:" .. NOTES[gs.key_root])

    -- Beat pulse
    local pulse = math.floor(8 + state.beat_phase * 7)
    screen.level(pulse)
    screen.circle(124, 4, 2)
    screen.fill()

  elseif state.drums_page then
    -- PAGE D: DRUMS humanized sequencer
    local pattern_data = drums.get_pattern_display()
    local step = drums.get_step()
    local running = drums.is_running()

    screen.level(15)
    screen.move(0, 8)
    screen.text("DRUMS")
    screen.level(running and 15 or 4)
    screen.move(36, 8)
    screen.text(running and "PLAY" or "STOP")
    screen.level(10)
    screen.move(64, 8)
    screen.text(drums.get_preset_name())

    if pattern_data then
      local voices = {"kick", "snare", "hat", "perc"}
      local labels = {"K", "S", "H", "P"}
      local row_y = 14
      for v = 1, 4 do
        local y = row_y + (v - 1) * 12
        local pat = pattern_data[voices[v]]
        local vel = pattern_data[voices[v] .. "_vel"]
        local muted = drums.is_muted(v)
        screen.level(muted and 2 or 8)
        screen.move(0, y + 8)
        screen.text(labels[v])
        for s = 1, 16 do
          local x = 10 + (s - 1) * 7
          local is_current = (s == step and running)
          if pat[s] == 1 then
            local v_level = math.floor((vel[s] / 127) * 12) + 3
            if muted then v_level = 2 end
            screen.level(is_current and 15 or v_level)
            screen.rect(x, y, 6, 9)
            screen.fill()
            if vel[s] < 50 and not muted then
              screen.level(0)
              screen.rect(x + 1, y + 1, 4, 7)
              screen.fill()
              screen.level(is_current and 15 or v_level)
              screen.rect(x + 2, y + 3, 2, 3)
              screen.fill()
            end
          else
            screen.level(is_current and 6 or 1)
            screen.rect(x, y, 6, 9)
            screen.stroke()
          end
        end
      end
    end

    screen.level(5)
    screen.move(0, 62)
    screen.text("GRV:" .. drums.get_humanize())
    screen.move(35, 62)
    screen.text("GHO:" .. drums.get_ghost_density())
    screen.move(72, 62)
    screen.text("FEL:" .. drums.get_feel())
    screen.move(104, 62)
    screen.text("JIT:" .. drums.get_jitter())

  elseif state.page_a then
    screen.level(15)
    screen.move(0, 10)
    screen.text("HICHORD v5.0")
    
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
  if n == 2 and z == 1 then
    if state.gospel_page then
      if state.gospel_mode then gospel_stop() else gospel_start() end
    elseif state.drums_page then
      drums.toggle()
    else
      state.chord_type = (state.chord_type % 4) + 1
    end
  elseif n == 3 and z == 1 then
    if state.gospel_page then
      if state.gospel_state.building then
        gospel.release_build(state.gospel_state)
      else
        gospel.trigger_build(state.gospel_state, 1.0, 0.05)
      end
    elseif state.drums_page then
      drums.next_preset()
    else
      state.octave = math.min(7, state.octave + 1)
    end
  end
  grid_redraw()
  redraw()
end

local PAGE_NAMES = {"A: PARAMS", "B: OLED", "C: SUNDAY SERVICE", "D: DRUMS"}
local current_page_idx = 1  -- 1=A, 2=B, 3=C(gospel), 4=D(drums)

local function set_page(idx)
  current_page_idx = idx
  state.page_a = (idx == 1)
  state.gospel_page = (idx == 3)
  state.drums_page = (idx == 4)
end

function enc(n, d)
  if n == 1 then
    -- E1: cycle pages (A -> B -> C -> D -> A)
    local new_idx = ((current_page_idx - 1 + d) % 4) + 1
    set_page(new_idx)
    state.popup_param = "PAGE"
    state.popup_val = PAGE_NAMES[current_page_idx]
    state.popup_time = 10
  elseif state.drums_page then
    -- Drums page: E2/E3
    if n == 2 then
      local idx = drums.get_preset_idx() + d
      local num = #drums.PRESET_ORDER
      idx = ((idx - 1) % num) + 1
      drums.set_preset(idx)
      state.popup_param = "GROOVE"
      state.popup_val = drums.get_preset_name()
      state.popup_time = 8
    elseif n == 3 then
      drums.set_humanize(drums.get_humanize() + d)
      state.popup_param = "GROOVE AMT"
      state.popup_val = drums.get_humanize() .. "%"
      state.popup_time = 8
    end
  elseif state.gospel_page then
    -- Gospel mode: E2/E3
    local gs = state.gospel_state
    if n == 2 then
      -- E2: cycle through progressions
      local names = gospel.PROGRESSION_NAMES
      local cur_idx = 1
      for i, name in ipairs(names) do
        if name == gs.progression_name then cur_idx = i end
      end
      cur_idx = ((cur_idx - 1 + d) % #names) + 1
      gs.progression_name = names[cur_idx]
      gs.progression_step = 1
      gs.beat_counter = 0
      state.popup_param = "PROG"
      state.popup_val = gs.progression_name
      state.popup_time = 12
    elseif n == 3 then
      -- E3: manual intensity
      gs.intensity = math.max(0, math.min(1.0, gs.intensity + d * 0.05))
      gs.target_intensity = gs.intensity
      state.popup_param = "INTENSITY"
      state.popup_val = math.floor(gs.intensity * 100) .. "%"
      state.popup_time = 8
    end
  else
    -- Standard mode: E2/E3
    if n == 2 then
      state.root_note = ((state.root_note - 1 + d) % 12) + 1
      state.popup_param = "ROOT"
      state.popup_val = NOTES[state.root_note]
      state.popup_time = 8
    elseif n == 3 then
      state.chord_type = util.clamp(state.chord_type + d, 1, #CHORD_SHAPES)
      state.popup_param = "CHORD"
      state.popup_val = CHORD_SHAPES[state.chord_type].name
      state.popup_time = 8
    end
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
  elseif y == 7 and z == 1 then
    -- Sunday Service row
    local gs = state.gospel_state
    if x == 1 then
      -- Start/stop gospel automation
      if state.gospel_mode then
        gospel_stop()
      else
        state.gospel_page = true
        state.page_a = false
        gospel_start()
      end
    elseif x == 2 then
      -- Build toggle
      if gs.building then
        gospel.release_build(gs)
      else
        gospel.trigger_build(gs, 1.0, 0.05)
      end
    elseif x >= 3 and x <= 10 then
      -- Progression select (cols 3-10)
      local idx = x - 2
      if idx <= #gospel.PROGRESSION_NAMES then
        local was_playing = state.gospel_mode
        if was_playing then gospel_stop() end
        gs.progression_name = gospel.PROGRESSION_NAMES[idx]
        gs.progression_step = 1
        gs.beat_counter = 0
        if was_playing then gospel_start() end
      end
    elseif x >= 13 and x <= 16 then
      -- Call/response mode (cols 13-16)
      local idx = x - 12
      if idx <= #gospel.CALL_RESPONSE_NAMES then
        gs.call_response_mode = gospel.CALL_RESPONSE_NAMES[idx]
        gs.call_response_beat = 0
        gs.call_response_phase = "call"
      end
    end
  elseif y == 8 and z == 1 then
    -- Intensity / key row
    local gs = state.gospel_state
    if x >= 1 and x <= 12 then
      -- Set intensity directly (1-12 → 0.08-1.0)
      gs.intensity = x / 12
      gs.target_intensity = gs.intensity
    elseif x >= 13 and x <= 16 then
      -- Gospel key select
      local idx = x - 12
      if idx <= #gospel.GOSPEL_KEYS then
        gs.key_root = gospel.GOSPEL_KEYS[idx].root
      end
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
      for note_num, _ in pairs(state.sustained_notes) do
        engine.noteOff(note_num)
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
  -- Initialize drum module
  drums.add_params()
  drums.set_midi_out(midi_out)

  for slot = 1, 7 do
    state.chord_slots[slot].notes = build_chord(
      state.chord_slots[slot].root,
      state.chord_slots[slot].type or 3,
      state.octave
    )
  end

  -- Initialize Sunday Service gospel automation
  state.gospel_state = gospel.new_state()

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

  -- Sunday Service parameters
  params:add_separator("SUNDAY SERVICE")

  params:add_option("gospel_progression", "Progression",
    gospel.PROGRESSION_NAMES, 1)
  params:set_action("gospel_progression", function(val)
    state.gospel_state.progression_name = gospel.PROGRESSION_NAMES[val]
    state.gospel_state.progression_step = 1
    state.gospel_state.beat_counter = 0
  end)

  params:add_option("gospel_key", "Gospel Key",
    {"C", "Db", "Eb", "F", "Ab", "Bb"}, 3)
  params:set_action("gospel_key", function(val)
    state.gospel_state.key_root = gospel.GOSPEL_KEYS[val].root
  end)

  params:add_control("gospel_intensity", "Intensity",
    ControlSpec.new(0, 100, "lin", 1, 50, "%"))
  params:set_action("gospel_intensity", function(val)
    state.gospel_state.intensity = val / 100
    state.gospel_state.target_intensity = val / 100
  end)

  params:add_control("gospel_humanize", "Humanize",
    ControlSpec.new(0, 100, "lin", 1, 30, "%"))
  params:set_action("gospel_humanize", function(val)
    state.gospel_state.humanize = val / 100
  end)

  params:add_option("gospel_call_response", "Call/Response",
    gospel.CALL_RESPONSE_NAMES, 1)
  params:set_action("gospel_call_response", function(val)
    state.gospel_state.call_response_mode = gospel.CALL_RESPONSE_NAMES[val]
  end)

  params:add_option("gospel_sub", "Sub Bass", {"off", "on"}, 2)
  params:set_action("gospel_sub", function(val)
    state.gospel_state.sub_enabled = (val == 2)
  end)

  params:add_option("gospel_auto_advance", "Auto Advance", {"off", "on"}, 2)
  params:set_action("gospel_auto_advance", function(val)
    state.gospel_state.auto_advance = (val == 2)
  end)

  screen_clock_id = clock.run(function()
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
  drums.cleanup()
  if state.gospel_mode then gospel_stop() end
  all_notes_off()
  if screen_clock_id then clock.cancel(screen_clock_id) end
end
