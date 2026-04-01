-- ELECTRO
-- EHX Pedal Emulations for Norns
--
-- E1: Switch pedal page
-- E2: Select knob
-- E3: Adjust knob value
-- K2: Toggle switch / cycle mode
-- K3: Bypass on/off
--
-- 7 Pedals:
-- 1. Big Muff Pi
-- 2. Small Stone
-- 3. Electric Mistress
-- 4. Deluxe Memory Man
-- 5. Freeze
-- 6. Micro POG
-- 7. Pitch Fork

engine.name = "Electro"

-- =============================================
-- PEDAL DEFINITIONS
-- Each pedal has: name, knobs, switches, bypass state,
-- engine command mappings
-- =============================================

local pedals = {}
local current_pedal = 1
local selected_knob = 1
local screen_dirty = true
local blink = false
local blink_counter = 0

-- Utility: round to decimal places
local function round(val, dec)
  local mul = 10 ^ (dec or 2)
  return math.floor(val * mul + 0.5) / mul
end

-- Utility: map a 0-1 value to a display range
local function map_val(v, lo, hi)
  return lo + (v * (hi - lo))
end

-- =============================================
-- PEDAL 1: BIG MUFF PI
-- =============================================
pedals[1] = {
  name = "BIG MUFF PI",
  color = 15,
  bypass = false,
  knobs = {
    {name = "VOLUME",  value = 0.7, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "TONE",    value = 0.5, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "SUSTAIN", value = 0.6, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
  },
  switches = {},
  send = function(p)
    engine.muff_bypass(p.bypass and 1 or 0)
    engine.muff_volume(p.knobs[1].value)
    engine.muff_tone(p.knobs[2].value)
    engine.muff_sustain(p.knobs[3].value)
  end
}

-- =============================================
-- PEDAL 2: SMALL STONE
-- =============================================
pedals[2] = {
  name = "SMALL STONE",
  color = 15,
  bypass = false,
  knobs = {
    {name = "RATE",  value = 0.5, min = 0.05, max = 10, fmt = function(v) return round(map_val(v, 0.05, 10), 1) .. "Hz" end},
    {name = "DEPTH", value = 0.8, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
  },
  switches = {
    {name = "COLOR", state = false},
  },
  send = function(p)
    engine.stone_bypass(p.bypass and 1 or 0)
    engine.stone_rate(map_val(p.knobs[1].value, 0.05, 10))
    engine.stone_depth(p.knobs[2].value)
    engine.stone_color(p.switches[1].state and 1 or 0)
  end
}

-- =============================================
-- PEDAL 3: ELECTRIC MISTRESS
-- =============================================
pedals[3] = {
  name = "ELEC MISTRESS",
  color = 15,
  bypass = false,
  knobs = {
    {name = "RATE",     value = 0.3, min = 0.05, max = 5, fmt = function(v) return round(map_val(v, 0.05, 5), 1) .. "Hz" end},
    {name = "RANGE",    value = 0.7, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "FEEDBACK", value = 0.7, min = 0, max = 0.95, fmt = function(v) return math.floor(v * 10) end},
  },
  switches = {
    {name = "FLTR MTX", state = false},
  },
  send = function(p)
    engine.mistress_bypass(p.bypass and 1 or 0)
    engine.mistress_rate(map_val(p.knobs[1].value, 0.05, 5))
    engine.mistress_range(p.knobs[2].value)
    engine.mistress_feedback(map_val(p.knobs[3].value, 0, 0.95))
    engine.mistress_filter_matrix(p.switches[1].state and 1 or 0)
  end
}

-- =============================================
-- PEDAL 4: DELUXE MEMORY MAN
-- =============================================
pedals[4] = {
  name = "MEMORY MAN",
  color = 15,
  bypass = false,
  knobs = {
    {name = "BLEND",    value = 0.5, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "FEEDBACK", value = 0.5, min = 0, max = 0.95, fmt = function(v) return math.floor(v * 10) end},
    {name = "DELAY",    value = 0.3, min = 0.05, max = 1.2, fmt = function(v) return math.floor(map_val(v, 50, 1200)) .. "ms" end},
  },
  switches = {
    {name = "CHO/VIB", state = false, labels = {"CHORUS", "VIBRATO"}},
  },
  send = function(p)
    engine.memory_bypass(p.bypass and 1 or 0)
    engine.memory_blend(p.knobs[1].value)
    engine.memory_feedback(map_val(p.knobs[2].value, 0, 0.95))
    engine.memory_delay(map_val(p.knobs[3].value, 0.05, 1.2))
    engine.memory_chorus_vibrato(p.switches[1].state and 1 or 0)
  end
}

-- =============================================
-- PEDAL 5: FREEZE
-- =============================================
pedals[5] = {
  name = "FREEZE",
  color = 15,
  bypass = false,
  knobs = {
    {name = "LEVEL", value = 0.8, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "SPEED", value = 0.5, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
  },
  switches = {
    {name = "MODE", state = false, labels = {"SLOW", "FAST"}},
    {name = "FREEZE", state = false, momentary = true},
  },
  send = function(p)
    engine.freeze_bypass(p.bypass and 1 or 0)
    engine.freeze_level(p.knobs[1].value)
    engine.freeze_speed(p.knobs[2].value)
    engine.freeze_gate(p.switches[2].state and 1 or 0)
  end
}

-- =============================================
-- PEDAL 6: MICRO POG
-- =============================================
pedals[6] = {
  name = "MICRO POG",
  color = 15,
  bypass = false,
  knobs = {
    {name = "DRY",     value = 1.0, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "SUB OCT", value = 0.0, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "OCT UP",  value = 0.0, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
  },
  switches = {},
  send = function(p)
    engine.pog_bypass(p.bypass and 1 or 0)
    engine.pog_dry(p.knobs[1].value)
    engine.pog_sub(p.knobs[2].value)
    engine.pog_oct_up(p.knobs[3].value)
  end
}

-- =============================================
-- PEDAL 7: PITCH FORK
-- =============================================
pedals[7] = {
  name = "PITCH FORK",
  color = 15,
  bypass = false,
  knobs = {
    {name = "BLEND", value = 0.5, min = 0, max = 1, fmt = function(v) return math.floor(v * 10) end},
    {name = "SHIFT", value = 0.5, min = 0, max = 1,
      fmt = function(v)
        local semi = math.floor(map_val(v, -24, 24) + 0.5)
        if semi > 0 then return "+" .. semi
        else return tostring(semi) end
      end},
  },
  switches = {
    {name = "LATCH", state = false},
    {name = "DIR", state = false, cycle = 3, cycle_val = 0, labels = {"UP", "DOWN", "DUAL"}},
  },
  send = function(p)
    engine.pitch_bypass(p.bypass and 1 or 0)
    engine.pitch_blend(p.knobs[1].value)
    engine.pitch_shift(map_val(p.knobs[2].value, -24, 24))
    engine.pitch_latch(p.switches[1].state and 1 or 0)
    local dir = p.switches[2].cycle_val or 0
    engine.pitch_direction(dir)
  end
}

-- =============================================
-- INIT
-- =============================================
function init()
  -- Set all pedals to bypassed initially (no effect)
  for i = 1, #pedals do
    pedals[i].bypass = false
  end

  -- Add params for all pedals
  params:add_separator("ELECTRO")
  params:add_control("input_gain", "Input Gain",
    controlspec.new(0.1, 4.0, "exp", 0.01, 1.0, ""))
  params:set_action("input_gain", function(v) engine.input_gain(v) end)

  params:add_control("output_gain", "Output Gain",
    controlspec.new(0.1, 4.0, "exp", 0.01, 1.0, ""))
  params:set_action("output_gain", function(v) engine.output_gain(v) end)

  for i, p in ipairs(pedals) do
    params:add_separator(p.name)
    params:add_binary(p.name .. "_bypass", p.name .. " Active", "toggle", 0)
    params:set_action(p.name .. "_bypass", function(v)
      pedals[i].bypass = (v == 1)
      pedals[i].send(pedals[i])
      screen_dirty = true
    end)
    for j, k in ipairs(p.knobs) do
      local pid = p.name .. "_" .. k.name
      params:add_control(pid, p.name .. " " .. k.name,
        controlspec.new(0, 1, "lin", 0.01, k.value, ""))
      params:set_action(pid, function(v)
        pedals[i].knobs[j].value = v
        pedals[i].send(pedals[i])
        screen_dirty = true
      end)
    end
  end

  -- Send initial state to engine
  clock.run(function()
    clock.sleep(0.5) -- wait for engine to load
    for _, p in ipairs(pedals) do
      p.send(p)
    end
  end)

  -- Screen refresh clock
  clock.run(function()
    while true do
      clock.sleep(1/15)
      blink_counter = blink_counter + 1
      if blink_counter >= 8 then
        blink = not blink
        blink_counter = 0
      end
      if screen_dirty then
        redraw()
        screen_dirty = false
      else
        redraw() -- always redraw for blink animation
      end
    end
  end)
end

-- =============================================
-- ENCODER HANDLING
-- =============================================
function enc(n, d)
  local p = pedals[current_pedal]

  if n == 1 then
    -- E1: Switch pedal page
    current_pedal = util.clamp(current_pedal + d, 1, #pedals)
    selected_knob = 1
  elseif n == 2 then
    -- E2: Select knob
    if #p.knobs > 0 then
      selected_knob = util.clamp(selected_knob + d, 1, #p.knobs)
    end
  elseif n == 3 then
    -- E3: Adjust selected knob value
    if #p.knobs > 0 and selected_knob <= #p.knobs then
      local k = p.knobs[selected_knob]
      local step = 0.01
      k.value = util.clamp(k.value + (d * step), 0, 1)
      p.send(p)
    end
  end
  screen_dirty = true
end

-- =============================================
-- KEY HANDLING
-- =============================================
function key(n, z)
  local p = pedals[current_pedal]

  if n == 2 and z == 1 then
    -- K2: Toggle switches (cycle through them)
    if #p.switches > 0 then
      local sw = p.switches[1]
      -- If there's a second switch and first is non-togglable, cycle
      for i, s in ipairs(p.switches) do
        if s.cycle then
          s.cycle_val = ((s.cycle_val or 0) + 1) % s.cycle
          p.send(p)
          screen_dirty = true
          return
        end
      end
      -- Default: toggle first switch
      sw.state = not sw.state
      p.send(p)
    end
  elseif n == 2 and z == 0 then
    -- Release: handle momentary switches
    for _, s in ipairs(p.switches) do
      if s.momentary then
        s.state = false
        p.send(p)
        screen_dirty = true
      end
    end

  elseif n == 3 and z == 1 then
    -- K3: Toggle bypass
    p.bypass = not p.bypass
    p.send(p)

    -- Also handle momentary freeze trigger on K3 for Freeze pedal
    if current_pedal == 5 then
      p.switches[2].state = true
      p.send(p)
    end
  elseif n == 3 and z == 0 then
    -- Release K3: release freeze gate
    if current_pedal == 5 then
      p.switches[2].state = false
      p.send(p)
    end
  end
  screen_dirty = true
end

-- =============================================
-- SCREEN DRAWING
-- =============================================

-- Draw a knob at position (cx, cy) with radius r
-- val is 0-1, selected highlights the knob
local function draw_knob(cx, cy, r, val, name, display_val, selected)
  -- Knob range: 7 o'clock to 5 o'clock (approx 225deg sweep)
  local start_angle = 2.35  -- ~135 degrees (7 o'clock)
  local end_angle = 7.07    -- ~405 degrees (5 o'clock) = 360+45
  local angle = start_angle + (val * (end_angle - start_angle))

  -- Outer ring
  screen.level(selected and 15 or 6)
  screen.circle(cx, cy, r)
  screen.stroke()

  -- Fill for selected
  if selected then
    screen.level(3)
    screen.circle(cx, cy, r - 1)
    screen.fill()
  end

  -- Pointer line
  local px = cx + math.cos(angle) * (r - 1)
  local py = cy + math.sin(angle) * (r - 1)
  screen.level(15)
  screen.move(cx, cy)
  screen.line(px, py)
  screen.stroke()

  -- Center dot
  screen.level(15)
  screen.circle(cx, cy, 1)
  screen.fill()

  -- Knob name below
  screen.level(selected and 15 or 5)
  screen.font_size(8)
  screen.move(cx, cy + r + 9)
  screen.text_center(name)

  -- Value above
  screen.level(selected and 12 or 4)
  screen.move(cx, cy - r - 3)
  screen.text_center(tostring(display_val))
end

-- Draw a toggle switch
local function draw_switch(x, y, name, state, label)
  screen.level(state and 15 or 4)
  -- Switch body
  screen.rect(x - 10, y - 5, 20, 10)
  screen.stroke()
  -- Switch position indicator
  if state then
    screen.level(15)
    screen.rect(x + 1, y - 4, 8, 8)
    screen.fill()
  else
    screen.level(6)
    screen.rect(x - 9, y - 4, 8, 8)
    screen.fill()
  end
  -- Label
  screen.level(state and 15 or 5)
  screen.move(x, y + 13)
  screen.text_center(label or name)
end

-- Draw a cycle switch (3-way)
local function draw_cycle_switch(x, y, name, cycle_val, labels)
  local label = labels[cycle_val + 1] or "?"
  screen.level(12)
  screen.rect(x - 14, y - 5, 28, 10)
  screen.stroke()
  -- Position indicator
  local positions = {x - 9, x, x + 9}
  for i = 1, #labels do
    screen.level(cycle_val == (i - 1) and 15 or 3)
    screen.circle(positions[i] or x, y, 2)
    screen.fill()
  end
  -- Label
  screen.level(15)
  screen.move(x, y + 13)
  screen.text_center(label)
end

function redraw()
  screen.clear()
  local p = pedals[current_pedal]

  -- === TOP BAR ===
  -- Pedal name
  screen.level(15)
  screen.font_size(8)
  screen.move(2, 8)
  screen.text(p.name)

  -- Page indicator
  screen.level(6)
  screen.move(126, 8)
  screen.text_right(current_pedal .. "/" .. #pedals)

  -- Bypass indicator
  if p.bypass then
    if blink then
      screen.level(15)
    else
      screen.level(8)
    end
    screen.move(64, 8)
    screen.text_center("ON")
  else
    screen.level(3)
    screen.move(64, 8)
    screen.text_center("OFF")
  end

  -- Divider line
  screen.level(2)
  screen.move(0, 10)
  screen.line(128, 10)
  screen.stroke()

  -- === KNOBS AREA ===
  local num_knobs = #p.knobs
  if num_knobs > 0 then
    local knob_y = 30
    local knob_r = 8
    local spacing = 128 / (num_knobs + 1)

    for i, k in ipairs(p.knobs) do
      local kx = math.floor(spacing * i)
      draw_knob(kx, knob_y, knob_r, k.value, k.name, k.fmt(k.value), i == selected_knob)
    end
  end

  -- === SWITCHES AREA ===
  local num_switches = #p.switches
  if num_switches > 0 then
    local sw_y = 54
    local sw_spacing = 128 / (num_switches + 1)
    for i, s in ipairs(p.switches) do
      local sx = math.floor(sw_spacing * i)
      if s.cycle then
        draw_cycle_switch(sx, sw_y, s.name, s.cycle_val or 0, s.labels)
      else
        local label = s.name
        if s.labels then
          label = s.state and s.labels[2] or s.labels[1]
        end
        if s.momentary and s.state then
          label = ">>HOLD<<"
        end
        draw_switch(sx, sw_y, s.name, s.state, label)
      end
    end
  end

  -- === BOTTOM: chain indicator dots ===
  screen.level(2)
  screen.move(0, 63)
  screen.line(128, 63)
  screen.stroke()

  for i = 1, #pedals do
    local dot_x = 8 + ((i - 1) * 17)
    if pedals[i].bypass then
      screen.level(i == current_pedal and 15 or 8)
      screen.circle(dot_x, 61, 2)
      screen.fill()
    else
      screen.level(i == current_pedal and 6 or 2)
      screen.circle(dot_x, 61, 2)
      screen.stroke()
    end
  end

  screen.update()
end

-- =============================================
-- CLEANUP
-- =============================================
function cleanup()
  -- nothing to clean up; engine handles its own free
end
