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
-- Norns K2         = F2 (Sounds/FX)
-- Norns K3         = F3 (Mode/BPM)
-- Norns ENC1       = Key / browse left-right
-- Norns ENC2       = Octave / value up-down
-- Norns ENC3       = Degree select / volume

engine.name = "HiChord"

local ControlSpec = require "controlspec"

-- ═══════════════════════════════════════════════════════════════
-- CONSTANTS & TABLES
-- ═══════════════════════════════════════════════════════════════

local NOTE_NAMES  = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

local SCALES = {
  {name="MAJOR",       short="MAJ", offsets={0,2,4,5,7,9,11},  qualities={1,2,2,1,1,2,3}},
  {name="NAT MIN",     short="MIN", offsets={0,2,3,5,7,8,10},  qualities={2,3,1,2,2,1,1}},
  {name="HARM MIN",    short="HRM", offsets={0,2,3,5,7,8,11},  qualities={2,3,4,2,1,1,3}},
  {name="MEL MIN",     short="MEL", offsets={0,2,3,5,7,9,11},  qualities={2,2,4,1,1,3,3}},
  {name="DORIAN",      short="DOR", offsets={0,2,3,5,7,9,10},  qualities={2,2,1,1,2,3,2}},
  {name="MIXOLYDIAN",  short="MIX", offsets={0,2,4,5,7,9,10},  qualities={1,2,3,1,2,1,2}},
  {name="LYDIAN",      short="LYD", offsets={0,2,4,6,7,9,11},  qualities={1,1,2,1,1,2,3}},
  {name="BLUES",       short="BLU", offsets={0,3,5,6,7,10,12}, qualities={7,2,7,7,1,2,2}},
}

local CHORD_TYPES = {
  {name="maj",   ints={0,4,7}},
  {name="min",   ints={0,3,7}},
  {name="dim",   ints={0,3,6}},
  {name="aug",   ints={0,4,8}},
  {name="sus4",  ints={0,5,7}},
  {name="sus2",  ints={0,2,7}},
  {name="Maj7",  ints={0,4,7,11}},
  {name="dom7",  ints={0,4,7,10}},
  {name="min7",  ints={0,3,7,10}},
  {name="6",     ints={0,4,7,9}},
  {name="Maj9",  ints={0,4,7,11,14}},
  {name="min9",  ints={0,3,7,10,14}},
  {name="add9",  ints={0,4,7,14}},
  {name="m7b5",  ints={0,3,6,10}},
  {name="min11", ints={0,3,7,10,14,17}},
  {name="dom9",  ints={0,4,7,10,14}},
  {name="Maj7#11",ints={0,4,7,11,18}},
}

-- Joystick direction → quality index per base chord type
local JOY_DEFAULT = {
  up      ={maj=2,min=1,dim=2},  dn      ={maj=5,min=5,dim=5},
  left    ={maj=3,min=2,dim=3},  right   ={maj=7,min=9,dim=9},
  up_left ={maj=4,min=4,dim=4},  up_right={maj=8,min=8,dim=8},
  dn_left ={maj=10,min=6,dim=6}, dn_right={maj=11,min=12,dim=12},
}
local JOY_EXTENDED = {
  up      ={maj=2,min=1,dim=2},  dn      ={maj=16,min=16,dim=16},
  left    ={maj=5,min=5,dim=5},  right   ={maj=13,min=13,dim=13},
  up_left ={maj=14,min=14,dim=14},up_right={maj=16,min=16,dim=16},
  dn_left ={maj=13,min=13,dim=13},dn_right={maj=15,min=15,dim=15},
}

-- Grid joystick: 3×3 block at cols 1-3, rows 3-5
-- Maps (col,row) offset from top-left of block → direction string
local JOY_GRID = {
  [1]={[3]="up_left",[4]="left",  [5]="dn_left"},
  [2]={[3]="up",     [4]=nil,     [5]="dn"},
  [3]={[3]="up_right",[4]="right",[5]="dn_right"},
}

local MODES = {"ONESHOT","STRUM","LEAD","DRONE","ARPEGGIO","REPEAT","DRUMMODE","DRUMLOOP","SEQUENCER"}
local MODES_SHORT = {"1SHOT","STRUM","LEAD","DRONE","ARP","RPT","DRUM","DLOOP","SEQ"}

local ADSR_PRESETS = {
  {name="LONG",    a=0.6,  d=0.3, s=0.8, r=3.0},
  {name="SHORT",   a=0.005,d=0.1, s=0.5, r=0.3},
  {name="SWELL",   a=1.2,  d=0.3, s=0.9, r=2.0},
  {name="PLUCK",   a=0.002,d=0.05,s=0.0, r=0.2},
  {name="TOUCH",   a=0.08, d=0.2, s=0.7, r=1.0},
  {name="SUSTAIN", a=0.01, d=0.1, s=1.0, r=4.0},
}

local WAVEFORMS = {
  {name="SAW",     id=0}, {name="SINE",  id=1},
  {name="SQUARE",  id=2}, {name="TRI",   id=3},
  {name="FM EPI",  id=4}, {name="FM HX7",id=5},
  {name="FM BELL", id=6}, {name="JUNO",  id=7},
  {name="STRINGS", id=8},
}

local STRUM_DELAYS = {0.20, 0.08, 0.04}
local ARP_PAT_NAMES = {"UP","DOWN","U/D","RAND","FNGR"}

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local st = {
  -- Music
  root        = 1,       -- 1=C..12=B
  scale_idx   = 1,
  octave      = 4,
  per_oct     = {0,0,0,0,0,0,0},
  chord_locks = {},
  inversion   = {0,0,0,0,0,0,0},
  degree      = 1,
  joy_dir     = nil,
  joy_mode    = "DEFAULT",

  -- Playing
  mode_idx    = 1,
  bpm         = 120,
  held_degree = nil,
  playing     = {},

  -- Sound
  wave_idx    = 1,
  adsr_idx    = 5,

  -- Effects
  fx_reverb   = true,
  fx_chorus   = false,
  fx_flanger  = false,
  fx_glide    = false,
  fx_filter   = false,
  fx_stereo   = true,
  fx_delay    = 1,    -- 1=OFF
  fx_midi     = false,
  filter_hz   = 2000,

  -- Strum / arp
  strum_speed = 2,
  arp_pattern = 1,

  -- Looper
  loop_state  = {1,1},   -- per track: 1=OFF 2=WAIT 3=REC 4=PLAY
  loop_events = {{},{}},
  loop_start  = {0,0},
  loop_len    = {0,0},
  loop_track  = 1,

  -- UI
  page        = "A",   -- "A"=norns menus  "B"=HiChord OLED replica
  menu        = "main",-- "main"|"f1"|"f2s"|"f2x"|"f3m"|"f3b"
  fx_cursor   = 1,
  k1_held     = false,
  k1_held_t   = 0,

  -- Animation
  tick        = 0,
  flash       = 0,

  -- Last chord played (for Page B display animation)
  last_chord_name = "—",
  last_notes      = {},
  vel_vis         = 0,    -- 0-15 velocity flash

  -- Arpeggiator runtime
  arp_active  = false,
  arp_notes   = {},
  arp_idx     = 1,

  -- Repeat runtime
  rep_active  = false,

  -- MIDI
  midi_dev = nil,
  midi_ch  = 1,

  -- Grid: which buttons are currently lit (for visual feedback)
  grid_held   = {},   -- set of "col,row" strings
}

-- ═══════════════════════════════════════════════════════════════
-- MUSIC THEORY HELPERS
-- ═══════════════════════════════════════════════════════════════

local function get_scale() return SCALES[st.scale_idx] end

local function diatonic_qi(degree)
  return get_scale().qualities[degree]
end

local function degree_root_semi(degree)
  local sc = get_scale()
  return (st.root - 1 + (sc.offsets[degree] or 0)) % 12
end

local function resolve_quality(degree)
  if st.chord_locks[degree] then return st.chord_locks[degree] end
  local base_qi = diatonic_qi(degree)
  if not st.joy_dir then return base_qi end
  local jmap = (st.joy_mode == "EXTENDED") and JOY_EXTENDED or JOY_DEFAULT
  local dmap = jmap[st.joy_dir]
  if not dmap then return base_qi end
  local bt = CHORD_TYPES[base_qi].name
  if bt:find("maj") or bt == "6" then return dmap.maj
  elseif bt == "dim" or bt == "m7b5" then return dmap.dim
  else return dmap.min end
end

local function chord_notes(degree)
  local qi   = resolve_quality(degree)
  local ct   = CHORD_TYPES[qi]
  local semi = degree_root_semi(degree)
  local oct  = st.octave + (st.per_oct[degree] or 0)
  local base = 12 * oct + semi
  local inv  = st.inversion[degree] or 0
  local notes = {}
  for i, iv in ipairs(ct.ints) do
    local n = base + iv
    if inv > 0 and i <= inv then n = n + 12 end
    table.insert(notes, n)
  end
  return notes, CHORD_TYPES[qi].name
end

local function chord_display_name(degree)
  local qi   = resolve_quality(degree)
  local semi = degree_root_semi(degree)
  return NOTE_NAMES[semi+1] .. CHORD_TYPES[qi].name
end

-- ═══════════════════════════════════════════════════════════════
-- AUDIO
-- ═══════════════════════════════════════════════════════════════

local function apply_adsr()
  local p = ADSR_PRESETS[st.adsr_idx]
  engine.attack(p.a); engine.decay(p.d)
  engine.sustain(p.s); engine.release(p.r)
end

local function note_on(n, vel)
  vel = vel or 100
  local vol = 0.8
  pcall(function() vol = params:get("vol") / 100 end)
  engine.noteOn(n, (vel/127) * vol)
  if st.midi_dev and st.fx_midi then st.midi_dev:note_on(n, vel, st.midi_ch) end
end

local function note_off(n)
  engine.noteOff(n)
  if st.midi_dev and st.fx_midi then st.midi_dev:note_off(n, 0, st.midi_ch) end
end

local function all_off()
  engine.allNotesOff()
  if st.midi_dev then
    for _, n in ipairs(st.playing) do st.midi_dev:note_off(n, 0, st.midi_ch) end
  end
  st.playing = {}
end

-- ═══════════════════════════════════════════════════════════════
-- LOOPER
-- ═══════════════════════════════════════════════════════════════

local loop_clocks = {nil,nil}

local function loop_record_event(notes, vel)
  local tr = st.loop_track
  if st.loop_state[tr] == 3 then
    local t = util.time() - st.loop_start[tr]
    table.insert(st.loop_events[tr], {t=t, notes=notes, vel=vel})
  end
end

local function loop_play(tr)
  if loop_clocks[tr] then clock.cancel(loop_clocks[tr]) end
  loop_clocks[tr] = clock.run(function()
    while st.loop_state[tr] == 4 do
      local t0 = util.time()
      for _, ev in ipairs(st.loop_events[tr]) do
        local w = ev.t - (util.time()-t0)
        if w > 0 then clock.sleep(w) end
        for _, n in ipairs(ev.notes) do note_on(n, ev.vel) end
      end
      local rem = st.loop_len[tr] - (util.time()-t0)
      if rem > 0 then clock.sleep(rem) end
    end
  end)
end

local function loop_click(tr)
  local ls = st.loop_state[tr]
  if ls == 1 then
    st.loop_state[tr] = 2                     -- OFF → WAIT
    st.loop_events[tr] = {}
  elseif ls == 2 then
    st.loop_state[tr] = 3                     -- WAIT → REC
    st.loop_start[tr] = util.time()
  elseif ls == 3 then
    st.loop_len[tr]   = util.time() - st.loop_start[tr]
    st.loop_state[tr] = 4                     -- REC → PLAY
    loop_play(tr)
  elseif ls == 4 then
    st.loop_state[tr] = 1                     -- PLAY → OFF
    if loop_clocks[tr] then clock.cancel(loop_clocks[tr]); loop_clocks[tr]=nil end
    if tr == 1 then
      st.loop_state[2] = 1
      if loop_clocks[2] then clock.cancel(loop_clocks[2]); loop_clocks[2]=nil end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════
-- ARPEGGIATOR
-- ═══════════════════════════════════════════════════════════════

local arp_clk = nil

local function arp_stop()
  st.arp_active = false
  if arp_clk then clock.cancel(arp_clk); arp_clk = nil end
end

local function arp_start(notes)
  arp_stop()
  local base = {}
  for _,n in ipairs(notes) do table.insert(base,n) end
  local up = {}; for _,n in ipairs(base) do table.insert(up,n) end
  table.insert(up, base[1]+12)

  if     st.arp_pattern==1 then st.arp_notes=up
  elseif st.arp_pattern==2 then
    local d={}; for i=#up,1,-1 do table.insert(d,up[i]) end; st.arp_notes=d
  elseif st.arp_pattern==3 then
    local ud={}; for _,n in ipairs(up) do table.insert(ud,n) end
    for i=#up-1,2,-1 do table.insert(ud,up[i]) end; st.arp_notes=ud
  elseif st.arp_pattern==4 then st.arp_notes=up
  elseif st.arp_pattern==5 then
    st.arp_notes={base[1], base[3] or base[1], base[2] or base[1], base[1]+12}
  end

  st.arp_idx=1; st.arp_active=true
  arp_clk = clock.run(function()
    while st.arp_active do
      all_off()
      local n = (st.arp_pattern==4)
        and st.arp_notes[math.random(#st.arp_notes)]
        or  st.arp_notes[st.arp_idx]
      st.playing={n}; note_on(n,90)
      st.arp_idx = (st.arp_idx % #st.arp_notes) + 1
      clock.sync(1/4)
    end
  end)
end

-- ═══════════════════════════════════════════════════════════════
-- REPEAT
-- ═══════════════════════════════════════════════════════════════

local rep_clk = nil

local function rep_stop()
  st.rep_active=false
  if rep_clk then clock.cancel(rep_clk); rep_clk=nil end
end

local function rep_start(notes)
  rep_stop(); st.rep_active=true
  rep_clk = clock.run(function()
    while st.rep_active do
      all_off(); st.playing=notes
      for _,n in ipairs(notes) do note_on(n,88) end
      clock.sync(1/8)
    end
  end)
end

-- ═══════════════════════════════════════════════════════════════
-- CHORD TRIGGER
-- ═══════════════════════════════════════════════════════════════

local function trigger(degree, vel)
  vel = vel or 100
  local mode = MODES[st.mode_idx]
  local notes, qname = chord_notes(degree)
  st.held_degree      = degree
  st.last_chord_name  = chord_display_name(degree)
  st.last_notes       = notes
  st.vel_vis          = 15

  loop_record_event(notes, vel)

  if mode == "ONESHOT" then
    all_off(); st.playing=notes
    for _,n in ipairs(notes) do note_on(n,vel) end

  elseif mode == "STRUM" then
    local delay = STRUM_DELAYS[st.strum_speed]
    all_off(); st.playing=notes
    clock.run(function()
      for i,n in ipairs(notes) do
        clock.sleep((i-1)*delay); note_on(n, vel - i*3)
      end
    end)

  elseif mode == "LEAD" then
    all_off()
    st.playing={notes[1]}; note_on(notes[1],vel)

  elseif mode == "DRONE" then
    all_off(); st.playing=notes
    for _,n in ipairs(notes) do note_on(n,vel) end

  elseif mode == "ARPEGGIO" then
    arp_start(notes)

  elseif mode == "REPEAT" then
    rep_start(notes)

  elseif mode == "DRUMMODE" then
    note_on(36+degree-1, vel)
    st.playing={36+degree-1}
  end
end

local function release(degree)
  st.held_degree = nil
  local mode = MODES[st.mode_idx]
  if mode=="ONESHOT" or mode=="STRUM" or mode=="LEAD" then all_off()
  elseif mode=="ARPEGGIO" then arp_stop(); all_off()
  elseif mode=="REPEAT"   then rep_stop(); all_off()
  end
end

-- ═══════════════════════════════════════════════════════════════
-- GRID LAYOUT CONSTANTS
-- ═══════════════════════════════════════════════════════════════
-- We target 16×8. Many grids are 16×8 (128) or at minimum 8×8 (64).
-- For 8×8 grids we compress: chord buttons cols 2-8, joy cols omitted.
-- We detect grid size in g.connect callback.

local GRID_W = 16  -- detected at runtime
local GRID_H = 8

-- (chord_col is not needed: degree→col is inlined as 9+deg)
local function is_chord_cell(col, row)
  if GRID_W >= 16 then
    return col >= 10 and col <= 16 and row >= 3 and row <= 6
  else
    return col >= 2 and col <= 8 and row >= 3 and row <= 6
  end
end

-- Joystick cell (3×3 block, cols 1-3 rows 3-5)
local function joy_dir_at(col, row)
  if GRID_W < 16 then return nil end
  if JOY_GRID[col] then return JOY_GRID[col][row] end
  return nil
end

-- Function button positions (F1/F2/F3 at cols 5/6/7 rows 3-5, tall buttons)
local function is_fn_button(col, row)
  return GRID_W >= 16 and row >= 3 and row <= 5 and col >= 5 and col <= 7
end

-- Looper row 7: cols 1-4 = track1, 5-8 = track2
local function looper_cell(col, row)
  if row ~= 7 then return nil end
  if col == 1 then return {tr=1, act="click"}
  elseif col == 2 then return {tr=1, act="prev"}
  elseif col == 4 then return {tr=2, act="click"}
  elseif col == 5 then return {tr=2, act="prev"}
  end
  return nil
end

-- Mode row 7, cols 10-16
local function mode_cell(col, row)
  if row == 7 and col >= 10 and col <= 16 then
    return col - 9
  end
  return nil
end

-- Key row 1
local function key_cell(col, row)
  if row == 1 and col >= 1 and col <= 12 then
    return col  -- = root (1-12)
  end
  return nil
end

-- Waveform row 8 cols 1-9, ADSR row 8 cols 10-15
local function wave_cell(col, row)
  if row == 8 and col >= 1 and col <= 9 then return col end
  return nil
end
local function adsr_cell(col, row)
  if row == 8 and col >= 10 and col <= 15 then return col-9 end
  return nil
end

-- Page toggle: row 8 col 16
local function is_page_toggle(col, row)
  return col == 16 and row == 8
end

-- Octave buttons: row 6 cols 1-2 (oct down, oct up) for 16-wide
local function octave_cell(col, row)
  if GRID_W >= 16 and row == 6 and col == 1 then return -1 end
  if GRID_W >= 16 and row == 6 and col == 2 then return  1 end
  return nil
end

-- Scale row 2 cols 1-8
local function scale_cell(col, row)
  if row == 2 and col >= 1 and col <= 8 then return col end
  return nil
end

-- ═══════════════════════════════════════════════════════════════
-- GRID REDRAW — device replica lighting
-- ═══════════════════════════════════════════════════════════════

local g = grid.connect()

-- Grid size — updated in init() once device is connected
-- grid.connect() is non-blocking; cols/rows may be 0 until device responds

local function grid_redraw()
  if not g or not g.cols or g.cols == 0 then return end
  g:all(0)

  if GRID_W >= 16 then

    -- ── ROW 1: KEY SELECTOR ──────────────────────────────────────
    for k = 1, 12 do
      -- highlight black keys dimmer
      local is_black = ({[2]=true,[4]=true,[7]=true,[9]=true,[11]=true})[k]
      local base_bri = is_black and 2 or 3
      local bri = (k == st.root) and 15 or base_bri
      g:led(k, 1, bri)
    end
    -- scale indicator: mark scale degrees on row 1
    local sc = SCALES[st.scale_idx]
    for _, off in ipairs(sc.offsets) do
      local k = ((st.root - 1 + off) % 12) + 1
      if k ~= st.root then
        g:led(k, 1, 6)
      end
    end

    -- ── ROW 2: SCALE SELECTOR ────────────────────────────────────
    for i = 1, #SCALES do
      g:led(i, 2, (i == st.scale_idx) and 12 or 3)
    end

    -- ── ROWS 3-5: JOYSTICK PAD (3×3, cols 1-3) ───────────────────
    -- Center dot
    g:led(2, 4, 6)
    -- Directions — light active direction brightly, others dim
    local dir_cells = {
      up_left={1,3}, up={2,3}, up_right={3,3},
      left={1,4},               right={3,4},
      dn_left={1,5}, dn={2,5}, dn_right={3,5},
    }
    for dir, pos in pairs(dir_cells) do
      local bri = (st.joy_dir == dir) and 15 or 4
      g:led(pos[1], pos[2], bri)
    end

    -- ── ROWS 3-5: F1 F2 F3 (cols 5-7) ───────────────────────────
    local fn_bri = {5,5,5}
    if st.menu == "f1" then fn_bri[1] = 15
    elseif st.menu == "f2s" or st.menu == "f2x" then fn_bri[2] = 15
    elseif st.menu == "f3m" or st.menu == "f3b" then fn_bri[3] = 15 end
    g:led(5, 3, fn_bri[1])
    g:led(5, 4, fn_bri[1])
    g:led(6, 3, fn_bri[2])
    g:led(6, 4, fn_bri[2])
    g:led(7, 3, fn_bri[3])
    g:led(7, 4, fn_bri[3])
    -- labels above (row 2 already used, use col 5-7 row 2 for F labels)
    g:led(5, 2, 8)  -- F1 indicator
    g:led(6, 2, 8)  -- F2
    g:led(7, 2, 8)  -- F3

    -- ── ROW 6: OCTAVE BUTTONS (cols 1-2) + JOYSTICK MODE (col 4) ─
    g:led(1, 6, 5)  -- OCT-
    g:led(2, 6, 5)  -- OCT+
    -- Octave position indicator (cols 4-9)
    for o = 2, 7 do
      local bri = (o == st.octave) and 15 or ((o < st.octave) and 4 or 1)
      g:led(o + 2, 6, bri)  -- cols 4-9
    end

    -- ── ROWS 3-6: CHORD BUTTONS 1-7 (cols 10-16) ─────────────────
    for deg = 1, 7 do
      local cx = 9 + deg
      -- All 4 rows form the "tall button"
      local is_held   = (st.held_degree == deg)
      local is_cur    = (st.degree == deg)
      local qi        = resolve_quality(deg)
      -- Chord quality colour hint: maj=bright, min=medium, dim=low
      local ct        = CHORD_TYPES[qi].name
      local base_bri  = ct:find("maj") and 5 or (ct:find("min") and 4 or 3)

      for row = 3, 6 do
        local bri
        if is_held then
          -- held = full column lit bright + flash
          bri = (st.tick % 4 < 2) and 15 or 10
        elseif is_cur then
          -- selected but not held: gradient bright-dim top-bottom
          bri = 7 + (6 - row)
        else
          bri = base_bri - (row - 3)  -- slight dim from top to bottom
          bri = math.max(bri, 1)
        end
        g:led(cx, row, bri)
      end
    end

    -- ── ROW 7: LOOPER + MODE SELECT ──────────────────────────────
    -- Track 1 state (cols 1-4)
    local loop_icons = {1,3,6,15}  -- OFF,WAIT,REC,PLAY brightness
    local l1 = st.loop_state[1]
    local l2 = st.loop_state[2]

    g:led(1, 7, loop_icons[l1])      -- T1 click
    -- rec blink
    if l1==3 then g:led(1,7, (st.tick%4<2) and 15 or 5) end
    g:led(2, 7, (st.loop_track==1) and 8 or 2)   -- T1 select
    g:led(3, 7, 2)
    g:led(4, 7, loop_icons[l2])      -- T2 click
    if l2==3 then g:led(4,7, (st.tick%4<2) and 15 or 5) end
    g:led(5, 7, (st.loop_track==2) and 8 or 2)   -- T2 select

    -- Mode select (cols 10-16 = modes 1-7)
    for m = 1, 7 do
      g:led(9+m, 7, (m == st.mode_idx) and 15 or 3)
    end
    -- Col 9 row 7 = extended modes (8-9) indicator
    if st.mode_idx >= 8 then
      g:led(9, 7, (st.tick%4<2) and 12 or 6)  -- blink when active
    else
      g:led(9, 7, 2)
    end

    -- ── ROW 8: WAVEFORM + ADSR + PAGE TOGGLE ─────────────────────
    for w = 1, #WAVEFORMS do
      g:led(w, 8, (w == st.wave_idx) and 15 or 3)
    end
    for a = 1, #ADSR_PRESETS do
      g:led(9+a, 8, (a == st.adsr_idx) and 12 or 3)
    end
    -- Page toggle col 16 row 8
    g:led(16, 8, (st.page=="B") and 15 or 5)

  else
    -- ── 8×8 COMPACT LAYOUT ───────────────────────────────────────
    -- Row 1: key selector (cols 1-8 = C to G#)
    for k = 1, 8 do
      g:led(k, 1, (k == ((st.root-1)%8)+1) and 15 or 3)
    end
    -- Rows 2-5: chord buttons (compressed to cols 2-8)
    for deg = 1, 7 do
      local is_held = (st.held_degree == deg)
      local is_cur  = (st.degree == deg)
      for row = 2, 5 do
        local bri = is_held and 15 or (is_cur and 10 or 4)
        g:led(1+deg, row, bri)
      end
    end
    -- Row 6: looper
    g:led(1, 6, st.loop_state[1]>1 and 15 or 3)
    g:led(2, 6, st.loop_state[2]>1 and 15 or 3)
    -- Row 7: modes (1-7)
    for m=1,7 do g:led(m,7,(m==st.mode_idx) and 15 or 3) end
    -- Row 8: waveforms (1-8)
    for w=1,8 do g:led(w,8,(w==st.wave_idx) and 15 or 2) end
  end

  g:refresh()
end

-- ═══════════════════════════════════════════════════════════════
-- GRID INPUT  (defined as named function so hot-plug can reassign)
-- ═══════════════════════════════════════════════════════════════

local function on_grid_key(col, row, z)
  -- Track holds
  local key_id = col..","..row
  if z==1 then st.grid_held[key_id]=true
  else st.grid_held[key_id]=nil end

  -- Chord buttons (rows 3-6, cols 10-16 on 16-wide, cols 2-8 on 8-wide)
  if is_chord_cell(col, row) then
    local deg = GRID_W>=16 and (col-9) or (col-1)
    if deg >= 1 and deg <= 7 then
      if z==1 then
        st.degree = deg
        trigger(deg, 100)
      else
        release(deg)
      end
    end

  elseif z == 0 then
    -- Release: nothing else needs z==0 handling beyond chord buttons above
    -- (joystick directions are toggle-on-press, not hold)

  -- All remaining handlers: press only (z==1)
  elseif GRID_W >= 16 then
    local jdir = joy_dir_at(col, row)
    if jdir then
      -- Toggle direction: pressing same dir again cancels
      st.joy_dir = (st.joy_dir == jdir) and nil or jdir
      if st.held_degree then trigger(st.held_degree, 100) end

    -- F1 / F2 / F3
    elseif is_fn_button(col, row) then
      if col==5 then
        st.menu = (st.menu=="f1") and "main" or "f1"
      elseif col==6 then
        if st.menu=="f2s" then st.menu="f2x"
        elseif st.menu=="f2x" then st.menu="main"
        else st.menu="f2s" end
      elseif col==7 then
        if st.menu=="f3m" then st.menu="f3b"
        elseif st.menu=="f3b" then st.menu="main"
        else st.menu="f3m" end
      end

    -- Key selector row 1
    elseif row==1 then
      local k = key_cell(col, row)
      if k then st.root = k end

    -- Scale row 2
    elseif row==2 then
      local sc = scale_cell(col, row)
      if sc and sc <= #SCALES then st.scale_idx = sc end

    -- Octave
    elseif row==6 then
      local od = octave_cell(col, row)
      if od then st.octave = util.clamp(st.octave+od, 2, 7) end

    -- Looper row 7
    elseif row==7 then
      local lc = looper_cell(col, row)
      if lc then loop_click(lc.tr) end
      local mi = mode_cell(col, row)
      if mi and mi <= #MODES then
        st.mode_idx = mi; all_off(); arp_stop(); rep_stop()
      end
      -- col 9 = cycle through extended modes (8,9)
      if col==9 then
        if st.mode_idx < 8 then st.mode_idx = 8
        elseif st.mode_idx == 8 then st.mode_idx = 9
        else st.mode_idx = 1 end
        all_off(); arp_stop(); rep_stop()
      end

    -- Waveform / ADSR / page row 8
    elseif row==8 then
      local w = wave_cell(col, row)
      if w and w <= #WAVEFORMS then
        st.wave_idx = w
        engine.waveform(WAVEFORMS[w].id)
      end
      local a = adsr_cell(col, row)
      if a then
        st.adsr_idx = a; apply_adsr()
      end
      if is_page_toggle(col, row) then
        st.page = (st.page=="A") and "B" or "A"
      end
    end
  end

  grid_redraw()
  redraw()
end

-- wire key handler to connected grid
g.key = on_grid_key

-- ═══════════════════════════════════════════════════════════════
-- NORNS KEYS
-- ═══════════════════════════════════════════════════════════════

function key(n, z)
  if n==1 then
    if z==1 then
      st.k1_held=true; st.k1_held_t=util.time()
    else
      local held_dur = util.time() - st.k1_held_t
      st.k1_held=false
      if held_dur < 0.35 then
        -- Short press: toggle page A ↔ B
        st.page = (st.page=="A") and "B" or "A"
      else
        -- Long press: F1 menu
        st.menu = (st.menu=="f1") and "main" or "f1"
      end
    end
  elseif n==2 and z==1 then
    if st.menu=="f2s" then st.menu="f2x"
    elseif st.menu=="f2x" then st.menu="main"
    else st.menu="f2s" end
  elseif n==3 and z==1 then
    if st.menu=="f3m" then st.menu="f3b"
    elseif st.menu=="f3b" then st.menu="main"
    else st.menu="f3m" end
  end
  redraw(); grid_redraw()
end

-- ═══════════════════════════════════════════════════════════════
-- NORNS ENCODERS
-- ═══════════════════════════════════════════════════════════════

function enc(n, d)
  local dir = d>0 and 1 or -1
  if st.menu=="main" then
    if n==1 then st.root = ((st.root-1+d) % 12)+1
    elseif n==2 then st.octave = util.clamp(st.octave+dir, 2, 7)
    elseif n==3 then
      local new_deg = util.clamp(st.degree+dir, 1, 7)
      if new_deg ~= st.degree then
        st.degree = new_deg
        all_off(); arp_stop(); rep_stop()
        trigger(st.degree, 100)
      end
    end
  elseif st.menu=="f1" then
    if n==1 then st.root = ((st.root-1+d) % 12)+1
    elseif n==2 then st.octave = util.clamp(st.octave+dir, 2, 7)
    elseif n==3 then st.scale_idx = util.clamp(st.scale_idx+dir, 1, #SCALES) end
  elseif st.menu=="f2s" then
    if n==1 then
      st.wave_idx = util.clamp(st.wave_idx+dir, 1, #WAVEFORMS)
      engine.waveform(WAVEFORMS[st.wave_idx].id)
    elseif n==2 then
      st.adsr_idx = util.clamp(st.adsr_idx+dir, 1, #ADSR_PRESETS); apply_adsr()
    elseif n==3 then params:delta("vol", d*2) end
  elseif st.menu=="f2x" then
    local fxl = {"fx_reverb","fx_chorus","fx_flanger","fx_glide","fx_filter","fx_stereo"}
    if n==1 then st.fx_cursor = util.clamp(st.fx_cursor+dir, 1, #fxl)
    elseif n==2 then
      local f = fxl[st.fx_cursor]
      if type(st[f])=="boolean" then
        st[f] = not st[f]
        local val = st[f] and 1 or 0
        local fname = f:sub(4)  -- strip "fx_" → "reverb","chorus","flanger","glide","filter","stereo"
        pcall(function() engine[fname](val) end)
      end
    elseif n==3 then
      st.filter_hz = util.clamp(st.filter_hz + d*50, 20, 20000)
      engine.cutoff(st.filter_hz)
    end
  elseif st.menu=="f3m" then
    if n==1 then
      st.mode_idx = util.clamp(st.mode_idx+dir, 1, #MODES)
      all_off(); arp_stop(); rep_stop()
    elseif n==2 then
      if MODES[st.mode_idx]=="STRUM" then
        st.strum_speed = util.clamp(st.strum_speed+dir,1,3)
      elseif MODES[st.mode_idx]=="ARPEGGIO" then
        st.arp_pattern = util.clamp(st.arp_pattern+dir,1,5)
      end
    elseif n==3 then
      st.joy_mode = (st.joy_mode=="DEFAULT") and "EXTENDED" or "DEFAULT"
    end
  elseif st.menu=="f3b" then
    if n==1 then
      st.bpm = util.clamp(st.bpm+d, 40, 240); clock.set_tempo(st.bpm)
    end
  end
  redraw(); grid_redraw()
end

-- ═══════════════════════════════════════════════════════════════
-- PIXEL FONT  (5×7 bitmaps, rendered at 2×2 px per dot)
-- ═══════════════════════════════════════════════════════════════

local F5 = {
  [" "]={{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}},
  ["0"]={{1,1,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,1,1,0}},
  ["1"]={{0,1,0,0},{1,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{1,1,1,0}},
  ["2"]={{1,1,1,0},{0,0,1,0},{0,1,0,0},{1,0,0,0},{1,0,0,0},{1,1,1,0}},
  ["3"]={{1,1,1,0},{0,0,1,0},{0,1,1,0},{0,0,1,0},{0,0,1,0},{1,1,1,0}},
  ["4"]={{1,0,1,0},{1,0,1,0},{1,1,1,0},{0,0,1,0},{0,0,1,0},{0,0,1,0}},
  ["5"]={{1,1,1,0},{1,0,0,0},{1,1,1,0},{0,0,1,0},{0,0,1,0},{1,1,1,0}},
  ["6"]={{0,1,1,0},{1,0,0,0},{1,1,1,0},{1,0,1,0},{1,0,1,0},{1,1,1,0}},
  ["7"]={{1,1,1,0},{0,0,1,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0}},
  ["8"]={{1,1,1,0},{1,0,1,0},{1,1,1,0},{1,0,1,0},{1,0,1,0},{1,1,1,0}},
  ["9"]={{1,1,1,0},{1,0,1,0},{1,1,1,0},{0,0,1,0},{0,0,1,0},{1,1,0,0}},
  ["A"]={{0,1,0,0},{1,0,1,0},{1,0,1,0},{1,1,1,0},{1,0,1,0},{1,0,1,0}},
  ["B"]={{1,1,0,0},{1,0,1,0},{1,1,0,0},{1,0,1,0},{1,0,1,0},{1,1,0,0}},
  ["C"]={{0,1,1,0},{1,0,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0},{0,1,1,0}},
  ["D"]={{1,1,0,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,1,0,0}},
  ["E"]={{1,1,1,0},{1,0,0,0},{1,1,0,0},{1,0,0,0},{1,0,0,0},{1,1,1,0}},
  ["F"]={{1,1,1,0},{1,0,0,0},{1,1,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0}},
  ["G"]={{0,1,1,0},{1,0,0,0},{1,0,0,0},{1,0,1,0},{1,0,1,0},{0,1,1,0}},
  ["H"]={{1,0,1,0},{1,0,1,0},{1,1,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0}},
  ["I"]={{1,1,1,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{1,1,1,0}},
  ["J"]={{0,0,1,0},{0,0,1,0},{0,0,1,0},{0,0,1,0},{1,0,1,0},{0,1,0,0}},
  ["K"]={{1,0,1,0},{1,0,1,0},{1,1,0,0},{1,0,1,0},{1,0,1,0},{1,0,1,0}},
  ["L"]={{1,0,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0},{1,1,1,0}},
  ["M"]={{1,0,1,0},{1,1,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0}},
  ["N"]={{1,0,1,0},{1,1,1,0},{1,1,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0}},
  ["O"]={{0,1,0,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{0,1,0,0}},
  ["P"]={{1,1,0,0},{1,0,1,0},{1,1,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0}},
  ["R"]={{1,1,0,0},{1,0,1,0},{1,1,0,0},{1,1,0,0},{1,0,1,0},{1,0,1,0}},
  ["S"]={{0,1,1,0},{1,0,0,0},{1,1,0,0},{0,1,1,0},{0,0,1,0},{1,1,0,0}},
  ["T"]={{1,1,1,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0}},
  ["U"]={{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,1,1,0}},
  ["V"]={{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,0,1,0},{0,1,0,0}},
  ["W"]={{1,0,1,0},{1,0,1,0},{1,0,1,0},{1,1,1,0},{1,1,1,0},{1,0,1,0}},
  ["X"]={{1,0,1,0},{1,0,1,0},{0,1,0,0},{0,1,0,0},{1,0,1,0},{1,0,1,0}},
  ["Y"]={{1,0,1,0},{1,0,1,0},{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0}},
  ["Z"]={{1,1,1,0},{0,0,1,0},{0,1,0,0},{1,0,0,0},{1,0,0,0},{1,1,1,0}},
  ["#"]={{0,1,0,1},{1,1,1,1},{0,1,0,1},{1,1,1,1},{0,1,0,1},{0,0,0,0}},
  ["+"]={{0,0,0,0},{0,1,0,0},{1,1,1,0},{0,1,0,0},{0,0,0,0},{0,0,0,0}},
  ["-"]={{0,0,0,0},{0,0,0,0},{1,1,1,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}},
  ["/"]={{0,0,1,0},{0,0,1,0},{0,1,0,0},{0,1,0,0},{1,0,0,0},{1,0,0,0}},
  [":"]={{0,0,0,0},{0,1,0,0},{0,0,0,0},{0,0,0,0},{0,1,0,0},{0,0,0,0}},
  ["°"]={{0,1,0,0},{1,0,1,0},{0,1,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}},
  ["●"]={{0,1,0,0},{1,1,1,0},{1,1,1,0},{0,1,0,0},{0,0,0,0},{0,0,0,0}},
  ["○"]={{0,1,0,0},{1,0,1,0},{1,0,1,0},{0,1,0,0},{0,0,0,0},{0,0,0,0}},
  ["▶"]={{1,0,0,0},{1,1,0,0},{1,1,1,0},{1,1,0,0},{1,0,0,0},{0,0,0,0}},
  ["<"]={{0,0,1,0},{0,1,0,0},{1,0,0,0},{0,1,0,0},{0,0,1,0},{0,0,0,0}},
  [">"]={{1,0,0,0},{0,1,0,0},{0,0,1,0},{0,1,0,0},{1,0,0,0},{0,0,0,0}},
  ["^"]={{0,1,0,0},{1,0,1,0},{0,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}},
  ["v"]={{0,0,0,0},{0,0,0,0},{0,0,0,0},{1,0,1,0},{0,1,0,0},{0,0,0,0}},
  ["~"]={{0,0,0,0},{0,1,0,0},{1,0,1,0},{0,0,1,0},{0,0,0,0},{0,0,0,0}},
}
local F5_UNK = {{1,0,1,0},{0,1,0,0},{1,0,1,0},{0,1,0,0},{0,0,0,0},{0,0,0,0}}

local S = 2  -- pixel dot size (2×2 for double-res)

-- (dpx helper removed — use screen.rect directly)(ch, px, py, lv)
  -- Try exact match first (handles UTF-8 special chars), then uppercase
  local bm = F5[ch] or F5[ch:upper()] or F5_UNK
  screen.level(lv or 15)
  for row = 1, 6 do
    for col = 1, 4 do
      if bm[row] and bm[row][col] == 1 then
        screen.rect(px + (col-1)*S, py + (row-1)*S, S, S)
        screen.fill()
      end
    end
  end
end

-- UTF-8 aware character iterator (handles multi-byte chars like ●▶○—)
local function utf8_chars(str)
  local chars = {}
  local i = 1
  while i <= #str do
    local byte = str:byte(i)
    local char_len
    if byte < 0x80 then char_len = 1
    elseif byte < 0xE0 then char_len = 2
    elseif byte < 0xF0 then char_len = 3
    else char_len = 4 end
    table.insert(chars, str:sub(i, i + char_len - 1))
    i = i + char_len
  end
  return chars
end

local CHAR_W = S*4 + S  -- 4 pixels wide + 1 gap = 10px at S=2

local function dtext(str, px, py, lv)
  local chars = utf8_chars(str)
  for i, ch in ipairs(chars) do
    dchar(ch, px + (i-1)*CHAR_W, py, lv)
  end
end

local function hline(x, y, w, lv)
  screen.level(lv or 6)
  screen.rect(x, y, w, 1); screen.fill()
end

-- (vline helper removed — not used in current layouts)

-- ═══════════════════════════════════════════════════════════════
-- PAGE A  —  norns parameter / menu display
-- ═══════════════════════════════════════════════════════════════

local function draw_page_A()
  screen.level(15)
  screen.font_size(8); screen.font_face(1)

  if st.menu == "main" then
    -- Chord buttons row (top)
    for deg = 1, 7 do
      local bx  = 2 + (deg-1)*18
      local held = (st.held_degree == deg)
      local cur  = (st.degree == deg)
      if held then
        screen.level(15); screen.rect(bx,2,16,12); screen.fill()
        screen.level(0)
      elseif cur then
        screen.level(8); screen.rect(bx,2,16,12); screen.stroke()
        screen.level(12)
      else
        screen.level(3); screen.rect(bx,2,16,12); screen.stroke()
        screen.level(6)
      end
      screen.move(bx+4, 12)
      screen.text(tostring(deg))
    end

    -- Chord name (large)
    screen.level(15); screen.font_size(14)
    screen.move(4, 34); screen.text(st.last_chord_name)

    -- Joy dir / mode badge
    if st.joy_dir then
      screen.level(10); screen.font_size(7)
      screen.move(90, 20); screen.text(st.joy_dir:upper())
    end

    hline(0, 37, 128, 4)

    -- Bottom strip
    screen.font_size(7); screen.level(8)
    screen.move(4,  48); screen.text(MODES_SHORT[st.mode_idx])
    screen.move(52, 48); screen.text("KEY:"..NOTE_NAMES[st.root])
    screen.move(96, 48); screen.text("O"..st.octave)

    -- Loop indicators
    local lc = {"—","W","●","▶"}
    screen.move(4,  58)
    screen.level(st.loop_state[1]>1 and 15 or 4)
    screen.text("T1:"..lc[st.loop_state[1]])
    screen.move(52, 58)
    screen.level(st.loop_state[2]>1 and 12 or 4)
    screen.text("T2:"..lc[st.loop_state[2]])
    screen.level(6)
    screen.move(96, 58); screen.text(st.bpm.."bpm")

    -- Velocity flash bar
    if st.vel_vis > 0 then
      screen.level(st.vel_vis)
      screen.rect(0, 63, math.floor(st.vel_vis/15*128), 1); screen.fill()
    end

  elseif st.menu == "f1" then
    screen.level(15); screen.move(4,12); screen.text("F1  SETTINGS")
    hline(0,14,128,4)
    screen.level(8); screen.move(4,26); screen.text("KEY")
    screen.level(15); screen.move(32,26); screen.text(NOTE_NAMES[st.root])
    screen.level(8); screen.move(4,38); screen.text("OCT")
    screen.level(15); screen.move(32,38); screen.text(tostring(st.octave))
    screen.level(8); screen.move(4,50); screen.text("SCALE")
    screen.level(12); screen.move(52,50); screen.text(SCALES[st.scale_idx].name)

  elseif st.menu == "f2s" then
    screen.level(15); screen.move(4,10); screen.text("F2  SOUNDS")
    hline(0,12,128,4)
    -- Show all waveforms, 7px per row (9 × 7 = 63px, fits in 64-12=52px... use 5px rows)
    for i=1,#WAVEFORMS do
      local cur = (i==st.wave_idx)
      local wy = 14+(i-1)*6
      if wy > 58 then break end  -- safety clip
      if cur then
        screen.level(15); screen.rect(0,wy-1,80,6); screen.fill()
        screen.level(0); screen.move(4,wy+4); screen.text(WAVEFORMS[i].name)
        -- animated waveform preview (right side)
        for xi=0,30 do
          local amp=0; local wid=WAVEFORMS[i].id
          if wid==0 then amp=xi%6<3 and 2 or -2
          elseif wid==1 then amp=math.floor(2.5*math.sin(xi*0.5+st.tick*0.15))
          elseif wid==2 then amp=xi%8<4 and 2 or -2
          elseif wid==3 then local p=xi%8; amp=p<4 and p-2 or 4-p
          else amp=math.floor(2*math.sin(xi*0.4+math.sin(xi*0.2)*2)) end
          screen.level(8); screen.rect(90+xi, wy+2-amp, 1, 1); screen.fill()
        end
      else
        screen.level(4); screen.move(4,wy+4); screen.text(WAVEFORMS[i].name)
      end
    end
    hline(0,58,128,4)
    screen.level(10); screen.font_size(7); screen.move(4,63)
    screen.text("ENV:"..ADSR_PRESETS[st.adsr_idx].name)

  elseif st.menu == "f2x" then
    screen.level(15); screen.move(4,12); screen.text("F2  EFFECTS")
    hline(0,14,128,4)
    local fxl = {
      {k="fx_reverb",n="REVERB"},{k="fx_chorus",n="CHORUS"},
      {k="fx_flanger",n="FLANGER"},{k="fx_glide",n="GLIDE"},
      {k="fx_filter",n="FILTER"},{k="fx_stereo",n="STEREO"},
    }
    for i=1,#fxl do
      local cur=(i==st.fx_cursor); local on=st[fxl[i].k]
      local fy=18+(i-1)*7
      if cur then
        screen.level(15); screen.move(4,fy+6); screen.text(">"..fxl[i].n)
      else
        screen.level(5); screen.move(12,fy+6); screen.text(fxl[i].n)
      end
      -- dot
      screen.level(on and 15 or 3)
      screen.rect(90, fy+1, 4, 4); if on then screen.fill() else screen.stroke() end
      screen.level(on and 12 or 3); screen.move(96,fy+6)
      screen.text(on and "ON" or "--")
    end

  elseif st.menu == "f3m" then
    screen.level(15); screen.move(4,12); screen.text("F3  MODES")
    hline(0,14,128,4)
    for i=1,#MODES do
      local mx=2+((i-1)%4)*32; local my=18+math.floor((i-1)/4)*16
      local cur=(i==st.mode_idx)
      screen.level(cur and 15 or 4)
      screen.rect(mx-1,my-1,31,12)
      if cur then screen.fill(); screen.level(0)
      else screen.stroke(); screen.level(6) end
      screen.font_size(7); screen.move(mx+1,my+8)
      screen.text(MODES_SHORT[i])
    end
    hline(0,54,128,4)
    screen.level(8); screen.font_size(7)
    if MODES[st.mode_idx]=="STRUM" then
      screen.move(4,63); screen.text("SPEED:"..({"SLOW","MED","FAST"})[st.strum_speed])
    elseif MODES[st.mode_idx]=="ARPEGGIO" then
      screen.move(4,63); screen.text("PATT:"..ARP_PAT_NAMES[st.arp_pattern])
    end
    screen.move(88,63); screen.text("JOY:"..st.joy_mode:sub(1,3))

  elseif st.menu == "f3b" then
    screen.level(15); screen.move(4,12); screen.text("F3  BPM")
    hline(0,14,128,4)
    screen.font_size(22); screen.move(30,50); screen.text(tostring(st.bpm))
    -- beat pulse bars
    local beat = clock.get_beats() % 1
    local pulse_h = math.max(1, math.floor((1-beat)*35))
    local pulse_lv = math.floor((1-beat)*15)
    screen.level(pulse_lv)
    screen.rect(4, 18, 18, pulse_h); screen.fill()
    screen.rect(106, 18, 18, pulse_h); screen.fill()
  end
end

-- ═══════════════════════════════════════════════════════════════
-- PAGE B  —  HiChord OLED pixel-art replica
-- Mimics the real 64×32 OLED at 2× scale (= 128×64 on norns)
-- Layout per manual ASCII art:
--  ┌──────────────────────────────────────────────────────────┐
--  │ ◯  Cmaj                               KEY:C  OCT:4      │  row 0-13
--  │────────────────────────────────────────────────────────  │
--  │ [1][2][3][4][5][6][7]   joy·  MODE   SCALE              │  row 14-27
--  │ ● ○  ONESHOT   KEY:C   BPM:120                          │  row 50-63
--  └──────────────────────────────────────────────────────────┘
-- ═══════════════════════════════════════════════════════════════

local function draw_page_B()
  -- ── STATUS BAR ──────────────────────────────────────────────
  -- Loop T1 icon
  local l1s = st.loop_state[1]
  local loop_ch = l1s==4 and "▶" or (l1s==3 and ((st.tick%8<4) and "●" or "○") or (l1s==2 and "○" or " "))
  local loop_lv = l1s>1 and 15 or 4
  dtext(loop_ch, 2, 2, loop_lv)

  -- Chord name (big, pixel font)
  local cname = st.last_chord_name
  dtext(cname, 14, 2, 15)

  -- Key and octave (right side)
  dtext("K:"..NOTE_NAMES[st.root], 76, 2, 7)
  dtext("O"..st.octave, 112, 2, 7)

  hline(2, 14, 124, 4)

  -- ── CHORD BUTTONS (7 tall rectangles) ────────────────────────
  local btn_y = 17
  local btn_h = 22
  for deg = 1, 7 do
    local bx = 2 + (deg-1)*18
    local held = (st.held_degree == deg)
    local cur  = (st.degree == deg)

    if held then
      -- fully lit white button, black digit inside
      screen.level(15)
      screen.rect(bx, btn_y, 16, btn_h); screen.fill()
      dchar(tostring(deg), bx+4, btn_y+2, 0)
      -- chord quality abbreviated (bottom of button, black on white)
      local qi = resolve_quality(deg)
      local ct = CHORD_TYPES[qi].name:sub(1,3):upper()
      dtext(ct, bx+1, btn_y+btn_h-10, 0)
    elseif cur then
      -- selected: medium brightness fill + bright outline
      screen.level(5); screen.rect(bx,btn_y,16,btn_h); screen.fill()
      screen.level(12); screen.rect(bx,btn_y,16,btn_h); screen.stroke()
      dchar(tostring(deg), bx+4, btn_y+2, 15)
      local qi = resolve_quality(deg)
      local ct = CHORD_TYPES[qi].name:sub(1,3):upper()
      dtext(ct, bx+1, btn_y+btn_h-10, 8)
    else
      -- idle: dim outline
      local qi = resolve_quality(deg)
      local ct = CHORD_TYPES[qi].name
      -- major bright, minor medium, dim dark
      local bri = ct:find("maj") and 4 or (ct:find("min") and 3 or 2)
      screen.level(bri)
      screen.rect(bx, btn_y, 16, btn_h); screen.stroke()
      dchar(tostring(deg), bx+4, btn_y+2, bri+2)
    end
  end

  -- ── JOYSTICK CROSSHAIR (right of buttons, tucked to edge) ────
  local jx, jy = 122, btn_y + 11  -- right-aligned, clear of button 7 at x=110
  -- 3×3 grid of dots
  local joy_pos = {
    up_left={-4,-4}, up={0,-4}, up_right={4,-4},
    left={-4,0},                right={4,0},
    dn_left={-4,4}, dn={0,4},  dn_right={4,4},
  }
  -- outer ring
  for _, pos in pairs(joy_pos) do
    screen.level(3); screen.rect(jx+pos[1]-1, jy+pos[2]-1, 3, 3); screen.fill()
  end
  -- center dot
  screen.level(6); screen.rect(jx-1, jy-1, 3, 3); screen.fill()
  -- active direction: bright
  if st.joy_dir and joy_pos[st.joy_dir] then
    local p = joy_pos[st.joy_dir]
    screen.level(15); screen.rect(jx+p[1]-1, jy+p[2]-1, 3, 3); screen.fill()
  end
  -- joy mode label
  dtext(st.joy_mode:sub(1,3), jx-8, btn_y+btn_h-8, 5)

  -- ── SEPARATOR ────────────────────────────────────────────────
  hline(2, btn_y+btn_h+2, 124, 4)

  -- ── BOTTOM BAR ───────────────────────────────────────────────
  local by = btn_y + btn_h + 5

  -- Loop track dots
  local lc = {"—","W","●","▶"}
  screen.level(st.loop_state[1]>1 and 15 or 3)
  dtext(lc[st.loop_state[1]], 2, by, st.loop_state[1]>1 and 15 or 3)
  dtext(lc[st.loop_state[2]], 12, by, st.loop_state[2]>1 and 12 or 3)

  -- Mode (short, 5 chars max = 50px)
  dtext(MODES_SHORT[st.mode_idx], 24, by, 10)

  -- Key (K:C# = 4 chars = 40px)
  dtext("K:"..NOTE_NAMES[st.root], 76, by, 7)

  -- BPM (B:120 = 5 chars = 50px, fits from x=96 to 146... use shorter form)
  local bpm_str = tostring(st.bpm)  -- 3 chars max
  local beat_bri = math.floor(6 + (1-(clock.get_beats()%1))*9)
  dtext(bpm_str, 108, by, beat_bri)

  -- ── ARP ANIMATION ────────────────────────────────────────────
  if st.arp_active then
    -- bouncing dot that tracks arp position
    local ax = 2 + (st.arp_idx-1) * 8
    screen.level((st.tick%4<2) and 15 or 5)
    screen.rect(ax, by-4, 3, 3); screen.fill()
  end

  -- ── VELOCITY FLASH ───────────────────────────────────────────
  if st.vel_vis > 0 then
    screen.level(math.floor(st.vel_vis * 0.8))
    screen.rect(0, 63, math.floor(st.vel_vis/15*128), 1); screen.fill()
  end

  -- ── PAGE B INDICATOR (top-right corner) ──────────────────────
  screen.level(4)
  screen.move(120, 8); screen.font_size(7); screen.font_face(1)
  screen.text("B")
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN REDRAW
-- ═══════════════════════════════════════════════════════════════

function redraw()
  screen.clear()
  screen.aa(false)  -- disable AA for crisp pixel art

  if st.page == "A" then
    screen.aa(true)
    draw_page_A()
  else
    draw_page_B()
  end

  screen.update()
end

-- ═══════════════════════════════════════════════════════════════
-- PARAMS
-- ═══════════════════════════════════════════════════════════════

function init_params()
  params:add_separator("HICHORD")
  params:add{type="control", id="vol", name="volume",
    controlspec=ControlSpec.new(0,100,"lin",1,80),
    action=function(v) engine.gain(v/100) end}
  params:add{type="number", id="midi_out_dev", name="MIDI out device",
    min=0, max=4, default=0,
    action=function(v)
      st.midi_dev = (v>0) and midi.connect(v) or nil
    end}
  params:add{type="number", id="midi_out_ch", name="MIDI out channel",
    min=1, max=16, default=1,
    action=function(v) st.midi_ch=v end}
  params:bang()
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

function init()
  -- Grid size detection
  local function update_grid_size()
    if g and g.cols and g.cols > 0 then
      GRID_W = g.cols
      GRID_H = g.rows
    end
  end

  -- Handle hot-plug
  grid.add = function(dev)
    g = dev
    g.key = on_grid_key
    update_grid_size()
    grid_redraw()
  end
  grid.remove = function() end

  update_grid_size()

  init_params()

  init_params()
  apply_adsr()
  engine.waveform(0)
  engine.gain(0.8)
  engine.cutoff(st.filter_hz)
  clock.set_tempo(st.bpm)

  -- Animation clock
  clock.run(function()
    while true do
      clock.sleep(1/20)
      st.tick = (st.tick+1) % 64
      -- decay velocity flash
      if st.vel_vis > 0 then st.vel_vis = st.vel_vis - 1 end
      redraw()
      grid_redraw()
    end
  end)

  grid_redraw()
  print("HiChord v3 loaded")
  print("K1 short=page toggle  K1 long=F1  K2=F2  K3=F3")
  print("Grid: 7 chord buttons + joystick pad + F1/F2/F3 + looper + key/scale/wave/adsr")
end

function cleanup()
  pcall(all_off)
  pcall(arp_stop)
  pcall(rep_stop)
  for i=1,2 do
    if loop_clocks[i] then
      pcall(function() clock.cancel(loop_clocks[i]) end)
    end
  end
end
