-- gospel.lua
-- Congregation: choir automation layer for HiChord
-- SATB voicing, generative call-and-response,
-- intensity builds, and mood-driven progressions

local gospel = {}

----------------------------------------------------------------------
-- EXTENDED CHORD VOCABULARY
-- Gospel uses rich harmonic extensions beyond basic triads
----------------------------------------------------------------------
gospel.CHORD_TYPES = {
  -- Triads
  {name="MAJ",      intervals={0,4,7}},
  {name="MIN",      intervals={0,3,7}},
  -- Sevenths
  {name="MAJ7",     intervals={0,4,7,11}},
  {name="MIN7",     intervals={0,3,7,10}},
  {name="DOM7",     intervals={0,4,7,10}},
  {name="DIM7",     intervals={0,3,6,9}},
  -- Extensions (gospel staples)
  {name="ADD9",     intervals={0,4,7,14}},
  {name="MADD9",    intervals={0,3,7,14}},
  {name="MAJ9",     intervals={0,4,7,11,14}},
  {name="MIN9",     intervals={0,3,7,10,14}},
  {name="DOM9",     intervals={0,4,7,10,14}},
  {name="MIN11",    intervals={0,3,7,10,14,17}},
  {name="MAJ6/9",   intervals={0,4,7,9,14}},
  -- Suspensions (tension that resolves beautifully)
  {name="SUS4",     intervals={0,5,7}},
  {name="SUS2",     intervals={0,2,7}},
  {name="7SUS4",    intervals={0,5,7,10}},
  -- Altered / dissonant (the "Sunday Service" sound)
  {name="AUG",      intervals={0,4,8}},
  {name="MAJ7#11",  intervals={0,4,7,11,18}},
  {name="DOM7#9",   intervals={0,4,7,10,15}},
  {name="MIN7b5",   intervals={0,3,6,10}},
  -- Power / open voicing
  {name="5",        intervals={0,7}},
  {name="OCT",      intervals={0,12}},
}

-- Quick lookup by name
gospel.chord_by_name = {}
for i, ct in ipairs(gospel.CHORD_TYPES) do
  gospel.chord_by_name[ct.name] = i
end

----------------------------------------------------------------------
-- VOICE TYPES
-- 0=soprano, 1=alto, 2=tenor, 3=bass, 4=lead, 5=sub
----------------------------------------------------------------------
gospel.VOICE = {
  SOPRANO = 0,
  ALTO    = 1,
  TENOR   = 2,
  BASS    = 3,
  LEAD    = 4,
  SUB     = 5,
}

-- Voice ranges (MIDI note numbers)
gospel.VOICE_RANGE = {
  [0] = {low=60, high=84},  -- soprano: C4-C6
  [1] = {low=53, high=77},  -- alto: F3-F5
  [2] = {low=48, high=72},  -- tenor: C3-C5
  [3] = {low=36, high=60},  -- bass: C2-C4
  [4] = {low=48, high=84},  -- lead: C3-C6
  [5] = {low=24, high=48},  -- sub: C1-C3
}

-- Stereo placement per voice
gospel.VOICE_PAN = {
  [0] = 0.3,    -- soprano: slight right
  [1] = -0.3,   -- alto: slight left
  [2] = 0.15,   -- tenor: just right of center
  [3] = -0.15,  -- bass: just left of center
  [4] = 0.0,    -- lead: center
  [5] = 0.0,    -- sub: center
}

----------------------------------------------------------------------
-- GOSPEL SCALES / MODES
----------------------------------------------------------------------
gospel.SCALES = {
  major       = {0,2,4,5,7,9,11},
  minor       = {0,2,3,5,7,8,10},
  dorian      = {0,2,3,5,7,9,10},     -- minor with bright 6th
  mixolydian  = {0,2,4,5,7,9,10},     -- major with flat 7
  blues       = {0,3,5,6,7,10},       -- hip-hop flavor
  gospel_pent = {0,2,4,7,9},          -- pentatonic (choir-friendly)
  gospel_full = {0,2,3,4,5,7,9,10,11}, -- chromatic gospel passing tones
}

----------------------------------------------------------------------
-- CONGREGATION PROGRESSION TEMPLATES
-- Each entry: list of {root_offset, chord_name, beats, intensity_hint}
-- root_offset is semitones from the song key
-- Blends gospel harmony with jazz, neo-soul, ambient, and chromatic movement
----------------------------------------------------------------------
gospel.PROGRESSIONS = {

  -- ASCEND: epic build, gospel IV-V motion with chromatic passing chords
  ascend = {
    {0, "MAJ7",    8, 0.5},
    {5, "MAJ9",    8, 0.6},
    {6, "MIN7",    4, 0.7},  -- chromatic passing chord
    {7, "7SUS4",   4, 0.8},
    {7, "DOM9",    8, 0.9},
    {0, "ADD9",    8, 1.0},
    {3, "MAJ7",    4, 0.7},  -- mediant shift
    {5, "MAJ6/9",  4, 0.8},
    {4, "MIN9",    8, 0.7},
    {7, "DOM7#9",  4, 0.9},
    {0, "MAJ9",    4, 1.0},
  },

  -- GLOW: warm, soulful, ii-V-I with neo-soul chromatic detours
  glow = {
    {2, "MIN9",    8, 0.5},
    {7, "DOM9",    8, 0.6},
    {0, "MAJ9",    8, 0.7},
    {1, "DIM7",    4, 0.6},  -- chromatic neighbor
    {2, "MIN7",    4, 0.5},
    {5, "MAJ7",    8, 0.7},
    {4, "MIN7",    4, 0.6},
    {3, "MAJ7",    4, 0.7},  -- Coltrane-ish third relation
    {2, "MIN9",    8, 0.5},
    {7, "DOM7#9",  8, 0.8},
    {0, "MAJ7#11", 8, 0.7},
  },

  -- STRIDE: rhythmic, driving, hip-hop meets gospel with minor key grit
  stride = {
    {0, "MIN7",    4, 0.7},
    {0, "MIN9",    4, 0.7},
    {10,"DOM7",    4, 0.8},
    {8, "MAJ7",    4, 0.8},
    {5, "MIN7",    4, 0.7},
    {3, "MAJ9",    4, 0.8},
    {1, "DOM7",    4, 0.9},  -- tritone sub
    {0, "MIN7",    4, 0.9},
  },

  -- STILL: sparse, ambient, suspensions that dissolve slowly
  still = {
    {0, "SUS2",    8, 0.2},
    {0, "ADD9",    8, 0.3},
    {5, "SUS4",    8, 0.4},
    {5, "MAJ7#11", 8, 0.5},
    {7, "SUS2",    8, 0.4},
    {7, "ADD9",    8, 0.5},
    {8, "MAJ7",    8, 0.6},  -- unexpected shift up
    {0, "MAJ9",    16, 0.4},
  },

  -- BLOOM: uplifting, full choir, major key with jazz extensions
  bloom = {
    {0, "MAJ9",    8, 0.7},
    {7, "DOM9",    8, 0.8},
    {9, "MIN7",    4, 0.7},
    {5, "MAJ7",    4, 0.8},
    {0, "MAJ6/9",  8, 0.9},
    {4, "MIN9",    4, 0.7},
    {3, "DOM7",    4, 0.8},  -- chromatic approach
    {5, "MAJ9",    8, 0.8},
    {6, "MIN7b5",  4, 0.9},  -- tension
    {7, "DOM9",    4, 0.9},
    {0, "MAJ9",    8, 1.0},
  },

  -- DRIFT: flowing, ethereal, ambiguous tonality, suspensions and modes
  drift = {
    {0, "SUS2",    8, 0.3},
    {2, "SUS4",    8, 0.4},
    {5, "SUS2",    8, 0.4},
    {4, "MAJ7#11", 8, 0.5},
    {7, "SUS4",    8, 0.5},
    {9, "ADD9",    8, 0.6},
    {8, "MAJ7",    8, 0.7},
    {0, "ADD9",    8, 0.5},
  },

  -- ALTAR: solemn, powerful, plagal cadence with weight
  altar = {
    {0, "MAJ",     8, 0.5},
    {5, "MAJ",     8, 0.7},
    {0, "MAJ7",    8, 0.6},
    {5, "MAJ9",    4, 0.8},
    {6, "DIM7",    4, 0.7},  -- diminished passing chord
    {0, "MAJ7",    8, 0.7},
    {8, "MAJ",     8, 0.8},  -- bVI — deceptive
    {5, "MAJ9",    8, 0.9},
    {7, "7SUS4",   4, 0.9},
    {7, "DOM7",    4, 0.9},
    {0, "MAJ",     8, 1.0},
  },

  -- FRACTURE: dramatic, dissonant beauty, angular movement
  fracture = {
    {0, "MIN7",    8, 0.5},
    {3, "MAJ7",    8, 0.6},
    {5, "MIN7b5",  4, 0.7},
    {6, "DOM7",    4, 0.7},  -- tritone away
    {8, "MAJ7",    8, 0.8},
    {7, "DOM7#9",  4, 0.9},
    {6, "MAJ7#11", 4, 0.9},  -- Lydian color
    {0, "MADD9",   8, 0.7},
    {1, "MAJ7",    8, 0.8},  -- half-step shift
    {10,"DOM9",    8, 0.8},
    {0, "MAJ7#11", 8, 1.0},
  },

  -- EMBER: slow burn, minor key, dorian/blues gospel fusion
  ember = {
    {0, "MIN7",    8, 0.4},
    {0, "MIN9",    8, 0.5},
    {5, "DOM7",    8, 0.6},
    {3, "MAJ9",    8, 0.7},
    {5, "MIN7",    8, 0.6},
    {8, "MAJ7",    4, 0.7},
    {7, "DOM9",    4, 0.8},
    {0, "MIN7",    8, 0.5},
    {10,"MAJ7",    8, 0.8},
    {0, "MADD9",   8, 0.9},
  },

  -- CONVENE: call-to-gather, unison feel, open voicings expanding
  convene = {
    {0, "5",       8, 0.3},
    {0, "SUS4",    8, 0.4},
    {0, "MAJ",     8, 0.5},
    {0, "MAJ7",    8, 0.6},
    {5, "ADD9",    8, 0.7},
    {7, "MAJ9",    8, 0.8},
    {5, "MAJ7",    4, 0.9},
    {7, "DOM9",    4, 0.9},
    {0, "MAJ9",    8, 1.0},
  },
}

-- Backward compat alias
gospel.JIK_PROGRESSIONS = gospel.PROGRESSIONS

-- Progression names for display/selection
gospel.PROGRESSION_NAMES = {}
for name, _ in pairs(gospel.PROGRESSIONS) do
  table.insert(gospel.PROGRESSION_NAMES, name)
end
table.sort(gospel.PROGRESSION_NAMES)

----------------------------------------------------------------------
-- CONGREGATION KEYS (warm keys: Eb, Ab, Bb, C, F, Db)
----------------------------------------------------------------------
gospel.GOSPEL_KEYS = {
  {name="C",  root=1},
  {name="Db", root=2},
  {name="Eb", root=4},
  {name="F",  root=6},
  {name="Ab", root=9},
  {name="Bb", root=11},
}

----------------------------------------------------------------------
-- VOICE ARRANGEMENT ENGINE
-- Generates SATB + lead voicings from a chord
----------------------------------------------------------------------

-- Build notes for a single chord in a given key and octave
function gospel.build_gospel_chord(key_root, chord_type_name, octave)
  local ct = gospel.chord_by_name[chord_type_name]
  if not ct then ct = 1 end
  local chord = gospel.CHORD_TYPES[ct]
  if not chord then return {} end

  local base = (octave + 1) * 12 + (key_root - 1)
  local notes = {}
  for _, interval in ipairs(chord.intervals) do
    local n = base + interval
    if n >= 0 and n <= 127 then
      table.insert(notes, n)
    end
  end
  return notes
end

-- Fit a note into a voice's range by octave transposition
local function fit_to_range(note, voice_type)
  local range = gospel.VOICE_RANGE[voice_type]
  if not range then return note end
  while note < range.low do note = note + 12 end
  while note > range.high do note = note - 12 end
  if note < range.low then return nil end
  return note
end

-- Generate a full SATB arrangement from chord tones
-- Returns: {soprano={notes}, alto={notes}, tenor={notes}, bass={notes}}
function gospel.arrange_satb(key_root, chord_type_name, base_octave)
  local ct_idx = gospel.chord_by_name[chord_type_name]
  if not ct_idx then ct_idx = 1 end
  local chord = gospel.CHORD_TYPES[ct_idx]
  if not chord then return {} end

  local root_midi = (base_octave + 1) * 12 + (key_root - 1)
  local intervals = chord.intervals

  local arrangement = {
    [gospel.VOICE.SOPRANO] = {},
    [gospel.VOICE.ALTO]    = {},
    [gospel.VOICE.TENOR]   = {},
    [gospel.VOICE.BASS]    = {},
  }

  -- Bass: root note (and sometimes 5th)
  local bass_root = fit_to_range(root_midi, gospel.VOICE.BASS)
  if bass_root then
    table.insert(arrangement[gospel.VOICE.BASS], bass_root)
  end
  if #intervals >= 3 then
    local bass_fifth = fit_to_range(root_midi + intervals[3], gospel.VOICE.BASS)
    if bass_fifth and bass_fifth ~= bass_root then
      table.insert(arrangement[gospel.VOICE.BASS], bass_fifth)
    end
  end

  -- Tenor: 3rd and 7th (the color tones)
  if #intervals >= 2 then
    local tenor_note = fit_to_range(root_midi + intervals[2], gospel.VOICE.TENOR)
    if tenor_note then
      table.insert(arrangement[gospel.VOICE.TENOR], tenor_note)
    end
  end
  if #intervals >= 4 then
    local tenor_7th = fit_to_range(root_midi + intervals[4], gospel.VOICE.TENOR)
    if tenor_7th then
      table.insert(arrangement[gospel.VOICE.TENOR], tenor_7th)
    end
  end

  -- Alto: 5th and extensions
  if #intervals >= 3 then
    local alto_note = fit_to_range(root_midi + intervals[3], gospel.VOICE.ALTO)
    if alto_note then
      table.insert(arrangement[gospel.VOICE.ALTO], alto_note)
    end
  end
  if #intervals >= 5 then
    local alto_ext = fit_to_range(root_midi + intervals[5], gospel.VOICE.ALTO)
    if alto_ext then
      table.insert(arrangement[gospel.VOICE.ALTO], alto_ext)
    end
  end

  -- Soprano: root (high octave), 3rd, and any remaining extensions
  local sop_root = fit_to_range(root_midi + 12, gospel.VOICE.SOPRANO)
  if sop_root then
    table.insert(arrangement[gospel.VOICE.SOPRANO], sop_root)
  end
  if #intervals >= 2 then
    local sop_3rd = fit_to_range(root_midi + intervals[2] + 12, gospel.VOICE.SOPRANO)
    if sop_3rd and sop_3rd ~= sop_root then
      table.insert(arrangement[gospel.VOICE.SOPRANO], sop_3rd)
    end
  end

  return arrangement
end

----------------------------------------------------------------------
-- INTENSITY SYSTEM
-- Controls how many voices and how dense the arrangement is
----------------------------------------------------------------------

-- intensity: 0.0 to 1.0
-- Returns which voices should be active and their velocity multipliers
function gospel.get_voice_config(intensity)
  if intensity <= 0.2 then
    -- Minimal: just lead
    return {
      {voice=gospel.VOICE.LEAD, vel=0.6, active=true},
      {voice=gospel.VOICE.SUB,  vel=0.3, active=true},
    }
  elseif intensity <= 0.4 then
    -- Sparse: lead + bass + one choir voice
    return {
      {voice=gospel.VOICE.LEAD,    vel=0.7, active=true},
      {voice=gospel.VOICE.BASS,    vel=0.5, active=true},
      {voice=gospel.VOICE.SUB,     vel=0.4, active=true},
      {voice=gospel.VOICE.SOPRANO, vel=0.0, active=false},
      {voice=gospel.VOICE.ALTO,    vel=0.4, active=true},
      {voice=gospel.VOICE.TENOR,   vel=0.0, active=false},
    }
  elseif intensity <= 0.6 then
    -- Medium: lead + SAB
    return {
      {voice=gospel.VOICE.LEAD,    vel=0.7, active=true},
      {voice=gospel.VOICE.SOPRANO, vel=0.5, active=true},
      {voice=gospel.VOICE.ALTO,    vel=0.5, active=true},
      {voice=gospel.VOICE.BASS,    vel=0.6, active=true},
      {voice=gospel.VOICE.SUB,     vel=0.5, active=true},
      {voice=gospel.VOICE.TENOR,   vel=0.0, active=false},
    }
  elseif intensity <= 0.8 then
    -- Full SATB: all choir voices
    return {
      {voice=gospel.VOICE.LEAD,    vel=0.75, active=true},
      {voice=gospel.VOICE.SOPRANO, vel=0.6,  active=true},
      {voice=gospel.VOICE.ALTO,    vel=0.55, active=true},
      {voice=gospel.VOICE.TENOR,   vel=0.55, active=true},
      {voice=gospel.VOICE.BASS,    vel=0.65, active=true},
      {voice=gospel.VOICE.SUB,     vel=0.55, active=true},
    }
  else
    -- Full spectacle: everything maxed, wider panning, doubled voices
    return {
      {voice=gospel.VOICE.LEAD,    vel=0.9,  active=true},
      {voice=gospel.VOICE.SOPRANO, vel=0.8,  active=true},
      {voice=gospel.VOICE.ALTO,    vel=0.7,  active=true},
      {voice=gospel.VOICE.TENOR,   vel=0.7,  active=true},
      {voice=gospel.VOICE.BASS,    vel=0.8,  active=true},
      {voice=gospel.VOICE.SUB,     vel=0.7,  active=true},
    }
  end
end

----------------------------------------------------------------------
-- CALL AND RESPONSE PATTERNS
-- Generative/algorithmic: beat lengths vary with intensity,
-- voice groups shift based on progression step
----------------------------------------------------------------------
gospel.CALL_RESPONSE = {
  -- solo/chorus: lead alone, then full choir answers
  solo_chorus = {
    call   = {gospel.VOICE.LEAD},
    respond = {gospel.VOICE.SOPRANO, gospel.VOICE.ALTO, gospel.VOICE.TENOR, gospel.VOICE.BASS},
    call_beats = 2,
    response_beats = 2,
    adaptive = true,  -- beat lengths scale with intensity
  },
  -- cascade: voices enter one at a time, top down
  cascade = {
    call   = {gospel.VOICE.SOPRANO},
    respond = {gospel.VOICE.SOPRANO, gospel.VOICE.ALTO, gospel.VOICE.TENOR, gospel.VOICE.BASS, gospel.VOICE.LEAD},
    call_beats = 1,
    response_beats = 3,
    adaptive = true,
  },
  -- converge: low voices call, all voices answer in unison
  converge = {
    call   = {gospel.VOICE.BASS, gospel.VOICE.TENOR},
    respond = {gospel.VOICE.SOPRANO, gospel.VOICE.ALTO, gospel.VOICE.TENOR, gospel.VOICE.BASS, gospel.VOICE.LEAD},
    call_beats = 4,
    response_beats = 4,
    adaptive = false,
  },
  -- scatter: stereo antiphonal, left vs right voices alternate rapidly
  scatter = {
    call   = {gospel.VOICE.ALTO, gospel.VOICE.BASS},
    respond = {gospel.VOICE.SOPRANO, gospel.VOICE.TENOR},
    call_beats = 1,
    response_beats = 1,
    adaptive = true,
  },
  -- breathe: all voices together, no call/response (bypass)
  breathe = {
    call   = {gospel.VOICE.SOPRANO, gospel.VOICE.ALTO, gospel.VOICE.TENOR, gospel.VOICE.BASS, gospel.VOICE.LEAD},
    respond = {gospel.VOICE.SOPRANO, gospel.VOICE.ALTO, gospel.VOICE.TENOR, gospel.VOICE.BASS, gospel.VOICE.LEAD},
    call_beats = 4,
    response_beats = 4,
    adaptive = false,
  },
  -- murmur: random voice subset calls, complement responds
  murmur = {
    call   = {gospel.VOICE.ALTO, gospel.VOICE.LEAD},
    respond = {gospel.VOICE.SOPRANO, gospel.VOICE.BASS, gospel.VOICE.TENOR},
    call_beats = 3,
    response_beats = 1,
    adaptive = true,
  },
}

gospel.CALL_RESPONSE_NAMES = {}
for name, _ in pairs(gospel.CALL_RESPONSE) do
  table.insert(gospel.CALL_RESPONSE_NAMES, name)
end
table.sort(gospel.CALL_RESPONSE_NAMES)

----------------------------------------------------------------------
-- CONGREGATION AUTOMATION STATE
----------------------------------------------------------------------
function gospel.new_state()
  return {
    active = false,
    key_root = 4,          -- Eb
    base_octave = 4,
    progression_name = "ascend",
    progression_step = 1,
    intensity = 0.5,
    target_intensity = 0.5,
    intensity_ramp_speed = 0.02,  -- how fast intensity changes per tick

    call_response_mode = "solo_chorus",
    call_response_phase = "call",  -- "call" or "respond"
    call_response_beat = 0,

    auto_advance = true,   -- auto-advance through progression
    beat_counter = 0,
    beats_per_step = 4,    -- current step duration in beats

    -- Currently sounding voices: {key -> {note, voice_type}}
    active_voices = {},

    -- Build mode: ramp intensity up over time
    building = false,
    build_target = 1.0,

    -- Humanize: subtle timing/velocity variations
    humanize = 0.3,  -- 0=robotic, 1=very human

    -- Sub bass enable
    sub_enabled = true,

    -- Display state
    display_chord_name = "",
    display_voice_count = 0,
  }
end

----------------------------------------------------------------------
-- PROGRESSION PLAYBACK
----------------------------------------------------------------------

-- Get current chord from progression
function gospel.get_current_chord(gstate)
  local prog = gospel.JIK_PROGRESSIONS[gstate.progression_name]
  if not prog then return nil end

  local step = gstate.progression_step
  if step < 1 or step > #prog then step = 1 end

  local entry = prog[step]
  -- entry = {root_offset, chord_name, beats, intensity_hint}
  return {
    root_offset = entry[1],
    chord_name  = entry[2],
    beats       = entry[3],
    intensity   = entry[4],
  }
end

-- Advance to next step in progression
function gospel.advance_step(gstate)
  local prog = gospel.JIK_PROGRESSIONS[gstate.progression_name]
  if not prog then return end

  gstate.progression_step = gstate.progression_step + 1
  if gstate.progression_step > #prog then
    gstate.progression_step = 1
  end

  local chord = gospel.get_current_chord(gstate)
  if chord then
    gstate.beats_per_step = chord.beats
    gstate.beat_counter = 0
    if gstate.building then
      gstate.target_intensity = math.min(gstate.build_target, chord.intensity)
    else
      gstate.target_intensity = chord.intensity
    end
  end
end

-- Get the actual MIDI root for current chord (key + offset)
function gospel.get_chord_root(gstate)
  local chord = gospel.get_current_chord(gstate)
  if not chord then return gstate.key_root end
  return ((gstate.key_root - 1 + chord.root_offset) % 12) + 1
end

-- Get full voice arrangement for current state
function gospel.get_arrangement(gstate)
  local chord = gospel.get_current_chord(gstate)
  if not chord then return {} end

  local actual_root = gospel.get_chord_root(gstate)
  local satb = gospel.arrange_satb(actual_root, chord.chord_name, gstate.base_octave)
  local voice_config = gospel.get_voice_config(gstate.intensity)

  -- Build final note list with voice assignments
  local result = {}

  -- Add lead voice (root + octave up)
  local lead_root = fit_to_range(
    (gstate.base_octave + 1) * 12 + (actual_root - 1) + 12,
    gospel.VOICE.LEAD
  )
  if lead_root then
    table.insert(result, {note=lead_root, voice=gospel.VOICE.LEAD, vel=0.7})
  end

  -- Add SATB from arrangement
  for voice_type, notes in pairs(satb) do
    for _, note in ipairs(notes) do
      table.insert(result, {note=note, voice=voice_type, vel=0.6})
    end
  end

  -- Add sub bass if enabled
  if gstate.sub_enabled then
    local sub_note = fit_to_range(
      (gstate.base_octave + 1) * 12 + (actual_root - 1) - 12,
      gospel.VOICE.SUB
    )
    if sub_note then
      table.insert(result, {note=sub_note, voice=gospel.VOICE.SUB, vel=0.5})
    end
  end

  -- Apply intensity filtering: remove voices that shouldn't play
  local filtered = {}
  for _, entry in ipairs(result) do
    for _, vc in ipairs(voice_config) do
      if vc.voice == entry.voice and vc.active then
        entry.vel = entry.vel * vc.vel
        table.insert(filtered, entry)
        break
      end
    end
  end

  -- Apply call/response filtering
  local cr = gospel.CALL_RESPONSE[gstate.call_response_mode]
  if cr then
    local allowed_voices = {}
    local phase_voices = (gstate.call_response_phase == "call") and cr.call or cr.respond
    for _, v in ipairs(phase_voices) do
      allowed_voices[v] = true
    end

    local cr_filtered = {}
    for _, entry in ipairs(filtered) do
      if allowed_voices[entry.voice] then
        table.insert(cr_filtered, entry)
      end
    end
    -- Only filter if we're in active call/response mode and there are results
    if #cr_filtered > 0 then
      filtered = cr_filtered
    end
  end

  -- Apply humanization: slight velocity variation
  if gstate.humanize > 0 then
    for _, entry in ipairs(filtered) do
      local variation = (math.random() - 0.5) * 0.15 * gstate.humanize
      entry.vel = math.max(0.1, math.min(1.0, entry.vel + variation))
    end
  end

  return filtered
end

-- Tick the automation: called once per beat
-- Returns: {notes_on={...}, notes_off={...}, chord_changed=bool}
function gospel.tick(gstate)
  if not gstate.active then
    return {notes_on={}, notes_off={}, chord_changed=false}
  end

  local result = {notes_on={}, notes_off={}, chord_changed=false}

  -- Ramp intensity toward target
  if gstate.intensity < gstate.target_intensity then
    gstate.intensity = math.min(gstate.target_intensity,
      gstate.intensity + gstate.intensity_ramp_speed)
  elseif gstate.intensity > gstate.target_intensity then
    gstate.intensity = math.max(gstate.target_intensity,
      gstate.intensity - gstate.intensity_ramp_speed)
  end

  -- Advance call/response phase (adaptive: beat lengths scale with intensity)
  local cr = gospel.CALL_RESPONSE[gstate.call_response_mode]
  if cr then
    gstate.call_response_beat = gstate.call_response_beat + 1
    local call_len = cr.call_beats
    local resp_len = cr.response_beats
    if cr.adaptive then
      -- At low intensity: longer calls, shorter responses (more space)
      -- At high intensity: shorter calls, longer responses (fuller choir)
      local scale = gstate.intensity
      call_len = math.max(1, math.floor(cr.call_beats * (1.5 - scale)))
      resp_len = math.max(1, math.floor(cr.response_beats * (0.5 + scale)))
    end
    local phase_len = (gstate.call_response_phase == "call") and call_len or resp_len
    if gstate.call_response_beat >= phase_len then
      gstate.call_response_beat = 0
      gstate.call_response_phase = (gstate.call_response_phase == "call") and "respond" or "call"
    end
  end

  -- Check if we need to advance the progression
  gstate.beat_counter = gstate.beat_counter + 1
  if gstate.auto_advance and gstate.beat_counter >= gstate.beats_per_step then
    -- Send note-offs for current voices
    for key, v in pairs(gstate.active_voices) do
      table.insert(result.notes_off, {note=v.note, voice=v.voice})
    end
    gstate.active_voices = {}

    gospel.advance_step(gstate)
    result.chord_changed = true
  end

  -- Get current arrangement and trigger
  if result.chord_changed or gstate.beat_counter == 1 then
    local arrangement = gospel.get_arrangement(gstate)

    -- Update display info
    local chord = gospel.get_current_chord(gstate)
    if chord then
      local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
      local actual_root = gospel.get_chord_root(gstate)
      gstate.display_chord_name = NOTES[actual_root] .. chord.chord_name
    end
    gstate.display_voice_count = #arrangement

    -- Build note-on list
    for _, entry in ipairs(arrangement) do
      table.insert(result.notes_on, entry)
      local key = entry.note * 10 + entry.voice
      gstate.active_voices[key] = {note=entry.note, voice=entry.voice}
    end
  end

  return result
end

-- Stop all voices
function gospel.stop(gstate)
  local result = {}
  for key, v in pairs(gstate.active_voices) do
    table.insert(result, {note=v.note, voice=v.voice})
  end
  gstate.active_voices = {}
  gstate.active = false
  return result
end

-- Start the automation
function gospel.start(gstate)
  gstate.active = true
  gstate.beat_counter = 0
  gstate.progression_step = 1
  gstate.call_response_beat = 0
  gstate.call_response_phase = "call"

  local chord = gospel.get_current_chord(gstate)
  if chord then
    gstate.beats_per_step = chord.beats
    gstate.target_intensity = chord.intensity
  end
end

-- Trigger a build (ramp intensity from current to target over time)
function gospel.trigger_build(gstate, target, speed)
  gstate.building = true
  gstate.build_target = target or 1.0
  gstate.intensity_ramp_speed = speed or 0.05
end

-- Release build (return to progression-driven intensity)
function gospel.release_build(gstate)
  gstate.building = false
  local chord = gospel.get_current_chord(gstate)
  if chord then
    gstate.target_intensity = chord.intensity
  end
  gstate.intensity_ramp_speed = 0.02
end

----------------------------------------------------------------------
-- CHORD SUGGESTION (gospel-aware)
----------------------------------------------------------------------
function gospel.suggest_next(gstate)
  local prog = gospel.JIK_PROGRESSIONS[gstate.progression_name]
  if not prog then return {} end

  local next_step = gstate.progression_step + 1
  if next_step > #prog then next_step = 1 end

  local suggestions = {}
  for i = 0, 2 do
    local s = ((next_step - 1 + i) % #prog) + 1
    local entry = prog[s]
    local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local root = ((gstate.key_root - 1 + entry[1]) % 12) + 1
    table.insert(suggestions, {
      name = NOTES[root] .. entry[2],
      root = root,
      chord = entry[2],
      intensity = entry[4],
    })
  end
  return suggestions
end

----------------------------------------------------------------------
-- VOICE NAME HELPERS
----------------------------------------------------------------------
gospel.VOICE_NAMES = {
  [0] = "SOP",
  [1] = "ALT",
  [2] = "TEN",
  [3] = "BAS",
  [4] = "LEAD",
  [5] = "SUB",
}

function gospel.voice_name(vtype)
  return gospel.VOICE_NAMES[vtype] or "?"
end

return gospel
