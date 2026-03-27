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
drums.VOICE_NAMES = {"kick", "snare", "hat", "hat2", "perc"}
drums.VOICE_MIDI = {
  drums.MIDI_KICK,
  drums.MIDI_SNARE,
  drums.MIDI_HAT_CLOSED,
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

  -- hat2: open hat accents on &'s
  hat2_pattern =  {0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},
  hat2_vel =      {0,0,75,0, 0,0,0,0, 0,0,70,0, 0,0,0,0},
  hat2_timing =   {0,0,2,0, 0,0,0,0, 0,0,3,0, 0,0,0,0},
  hat2_prob =     {0,0,80,0, 0,0,0,0, 0,0,75,0, 0,0,0,0},
  hat2_open =     {0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},

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

  -- hat2: shaker-like 16ths, very soft, forward-leaning
  hat2_pattern =  {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat2_vel =      {35,20,30,18, 38,22,28,16, 35,24,30,20, 36,18,32,22},
  hat2_timing =   {-3,-8,-2,-7, -3,-9,-2,-6, -3,-7,-2,-8, -3,-8,-2,-6},
  hat2_prob =     {90,70,85,65, 88,68,82,60, 90,72,85,68, 88,65,85,70},
  hat2_open =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

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

  -- hat2: lazy swung open hat barks
  hat2_pattern =  {0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0},
  hat2_vel =      {0,0,0,0, 0,0,80,0, 0,0,0,0, 0,0,75,0},
  hat2_timing =   {0,0,0,0, 0,0,20,0, 0,0,0,0, 0,0,22,0},
  hat2_prob =     {0,0,0,0, 0,0,85,0, 0,0,0,0, 0,0,80,0},
  hat2_open =     {0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0},

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

-- 5. GOSPEL BOUNCE (Sunday Service feel)
-- Swung 8ths, open hats on upbeats, hat2 as tambourine 16ths
drums.PRESETS["gospel_bounce"] = {
  name = "Gospel Bounce",
  kick_pattern =  {1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,0,0},
  kick_vel =      {110,0,0,0, 0,0,90,0, 105,0,0,0, 0,0,0,0},
  kick_timing =   {0,0,0,0, 0,0,6,0, 2,0,0,0, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,95,0, 100,0,0,0, 0,0,0,0},

  snare_pattern = {0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 120,0,0,35, 0,0,0,0, 118,0,0,0},
  snare_timing =  {0,0,0,0, 3,0,0,8, 0,0,0,0, 4,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,65, 0,0,0,0, 100,0,0,0},

  hat_pattern =   {1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0},
  hat_vel =       {95,0,60,0, 90,0,65,0, 95,0,58,0, 88,0,62,0},
  hat_timing =    {0,0,12,0, 0,0,14,0, 0,0,12,0, 0,0,15,0},
  hat_prob =      {100,0,95,0, 100,0,92,0, 100,0,95,0, 100,0,90,0},
  hat_open =      {0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},

  hat2_pattern =  {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat2_vel =      {40,25,35,22, 42,24,38,20, 40,26,35,24, 38,22,36,20},
  hat2_timing =   {0,-3,2,-4, 0,-3,3,-4, 0,-3,2,-5, 0,-3,3,-4},
  hat2_prob =     {95,75,90,70, 92,72,88,68, 95,78,90,72, 92,70,88,68},
  hat2_open =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  perc_pattern =  {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  perc_vel =      {0,0,0,0, 85,0,0,0, 0,0,0,0, 80,0,0,0},
  perc_timing =   {0,0,0,0, 3,0,0,0, 0,0,0,0, 4,0,0,0},
  perc_prob =     {0,0,0,0, 50,0,0,0, 0,0,0,0, 45,0,0,0},
}

-- 6. TRAP (Atlanta)
-- Rapid hat rolls, 808 kick, sparse snare
drums.PRESETS["trap"] = {
  name = "Trap",
  kick_pattern =  {1,0,0,0, 0,0,0,0, 0,0,1,0, 0,1,0,0},
  kick_vel =      {127,0,0,0, 0,0,0,0, 0,0,110,0, 0,95,0,0},
  kick_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,3,0,0},
  kick_prob =     {100,0,0,0, 0,0,0,0, 0,0,100,0, 0,90,0,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 127,0,0,0, 0,0,0,0, 125,0,0,0},
  snare_timing =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 100,0,0,0},

  -- hat1: machine gun 16ths with rolls
  hat_pattern =   {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat_vel =       {90,50,70,45, 85,48,72,40, 90,52,68,48, 88,45,75,42},
  hat_timing =    {0,-2,1,-3, 0,-2,2,-3, 0,-2,1,-4, 0,-2,2,-3},
  hat_prob =      {100,95,98,90, 100,92,98,88, 100,95,98,92, 100,90,98,88},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  -- hat2: accent opens and barks on syncopated hits
  hat2_pattern =  {0,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0},
  hat2_vel =      {0,0,0,0, 0,0,100,0, 0,0,0,90,0, 0,0,0},
  hat2_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,-2, 0,0,0,0},
  hat2_prob =     {0,0,0,0, 0,0,90,0, 0,0,0,85, 0,0,0,0},
  hat2_open =     {0,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0},

  perc_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
}

-- 7. NEO SOUL (D'Angelo / Erykah Badu pocket)
-- Lazy behind-the-beat, hat2 as subtle ride pattern
drums.PRESETS["neosoul"] = {
  name = "Neo Soul",
  kick_pattern =  {1,0,0,0, 0,0,0,1, 0,0,1,0, 0,0,0,0},
  kick_vel =      {105,0,0,0, 0,0,0,80, 0,0,95,0, 0,0,0,0},
  kick_timing =   {6,0,0,0, 0,0,0,10, 0,0,8,0, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,0,85,0, 0,100,0, 0,0,0,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1},
  snare_vel =     {0,0,0,0, 110,0,0,0, 0,0,0,0, 108,0,0,30},
  snare_timing =  {0,0,0,0, 10,0,0,0, 0,0,0,0, 12,0,0,8},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 100,0,0,60},

  hat_pattern =   {1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0},
  hat_vel =       {80,0,48,0, 75,0,45,0, 78,0,50,0, 72,0,42,0},
  hat_timing =    {4,0,16,0, 6,0,18,0, 4,0,15,0, 5,0,20,0},
  hat_prob =      {100,0,92,0, 100,0,88,0, 100,0,90,0, 100,0,85,0},
  hat_open =      {0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,0,0},

  -- hat2: ride-like quarter notes, very soft
  hat2_pattern =  {1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0},
  hat2_vel =      {45,0,0,0, 40,0,0,0, 42,0,0,0, 38,0,0,0},
  hat2_timing =   {3,0,0,0, 5,0,0,0, 4,0,0,0, 6,0,0,0},
  hat2_prob =     {85,0,0,0, 80,0,0,0, 82,0,0,0, 78,0,0,0},
  hat2_open =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  perc_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
}

-- 8. AFROBEAT (Tony Allen inspired)
-- Polyrhythmic kick, hat1=bell, hat2=shaker
drums.PRESETS["afrobeat"] = {
  name = "Afrobeat",
  kick_pattern =  {1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,1,0},
  kick_vel =      {110,0,0,0, 0,0,95,0, 0,0,0,85, 0,0,100,0},
  kick_timing =   {0,0,0,0, 0,0,-2,0, 0,0,0,-3, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,100,0, 0,0,0,90, 0,0,100,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,1,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 115,0,0,0, 0,0,90,0, 110,0,0,0},
  snare_timing =  {0,0,0,0, 0,0,0,0, 0,0,-3,0, 2,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,85,0, 100,0,0,0},

  -- hat1: bell pattern (ride-like 12/8 feel)
  hat_pattern =   {1,0,1,1, 0,1,1,0, 1,1,0,1, 1,0,1,0},
  hat_vel =       {95,0,70,80, 0,65,90,0, 75,85,0,68, 92,0,72,0},
  hat_timing =    {0,0,-2,0, 0,-3,0,0, -2,0,0,-3, 0,0,-2,0},
  hat_prob =      {100,0,95,98, 0,92,100,0, 95,98,0,90, 100,0,95,0},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  -- hat2: shaker 16ths
  hat2_pattern =  {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat2_vel =      {38,22,32,20, 40,24,30,18, 36,22,34,20, 38,20,32,22},
  hat2_timing =   {0,-4,2,-5, 0,-4,3,-5, 0,-4,2,-6, 0,-4,3,-5},
  hat2_prob =     {92,70,88,65, 90,68,85,62, 92,72,88,68, 90,65,85,65},
  hat2_open =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  -- perc: claves-inspired
  perc_pattern =  {1,0,0,1, 0,0,1,0, 1,0,0,0, 1,0,1,0},
  perc_vel =      {80,0,0,70, 0,0,75,0, 72,0,0,0, 78,0,68,0},
  perc_timing =   {0,0,0,0, 0,0,-2,0, 0,0,0,0, 0,0,-3,0},
  perc_prob =     {90,0,0,82, 0,0,88,0, 85,0,0,0, 88,0,80,0},
}

-- 9. BOOM BAP (90s NYC)
-- Punchy classic breaks, chopped hat
drums.PRESETS["boombap"] = {
  name = "Boom Bap",
  kick_pattern =  {1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},
  kick_vel =      {125,0,0,0, 0,0,0,0, 0,0,120,0, 0,0,0,0},
  kick_timing =   {0,0,0,0, 0,0,0,0, 0,0,2,0, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,0,0, 0,0,100,0, 0,0,0,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 125,0,0,0, 0,0,0,0, 120,0,0,0},
  snare_timing =  {0,0,0,0, 2,0,0,0, 0,0,0,0, 3,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 100,0,0,0},

  -- hat1: chopped pattern with gaps
  hat_pattern =   {1,1,0,1, 1,0,1,0, 1,1,0,1, 0,1,1,0},
  hat_vel =       {90,55,0,50, 85,0,60,0, 88,50,0,55, 0,52,80,0},
  hat_timing =    {0,-3,0,-2, 0,0,4,0, 0,-3,0,-4, 0,3,0,0},
  hat_prob =      {100,88,0,85, 100,0,90,0, 100,85,0,88, 0,85,100,0},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  -- hat2: off (classic boom bap is single hat)
  hat2_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  hat2_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  hat2_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  hat2_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  hat2_open =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  perc_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1},
  perc_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,70},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,2},
  perc_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,50},
}

-- 10. GOSPEL SHOUT (uptempo praise)
-- Driving 16th hats, heavy backbeat, hat2 as tambourine accents
drums.PRESETS["gospel_shout"] = {
  name = "Gospel Shout",
  kick_pattern =  {1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,1,0},
  kick_vel =      {115,0,0,0, 0,0,100,0, 0,0,0,0, 110,0,85,0},
  kick_timing =   {0,0,0,0, 0,0,2,0, 0,0,0,0, 0,0,3,0},
  kick_prob =     {100,0,0,0, 0,0,100,0, 0,0,0,0, 100,0,90,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  snare_vel =     {0,0,0,0, 127,0,0,0, 0,0,0,0, 127,0,0,0},
  snare_timing =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 100,0,0,0},

  hat_pattern =   {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat_vel =       {100,45,75,40, 98,42,78,38, 100,48,72,42, 95,40,76,38},
  hat_timing =    {0,-3,2,-4, 0,-3,3,-4, 0,-3,2,-5, 0,-3,3,-4},
  hat_prob =      {100,95,98,90, 100,92,98,88, 100,95,98,92, 100,90,98,88},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0},

  -- hat2: tambourine accents on upbeats
  hat2_pattern =  {0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0},
  hat2_vel =      {0,0,65,0, 0,0,60,0, 0,0,68,0, 0,0,62,0},
  hat2_timing =   {0,0,-2,0, 0,0,-3,0, 0,0,-2,0, 0,0,-3,0},
  hat2_prob =     {0,0,88,0, 0,0,85,0, 0,0,90,0, 0,0,85,0},
  hat2_open =     {0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0},

  perc_pattern =  {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0},
  perc_vel =      {0,0,0,0, 95,0,0,0, 0,0,0,0, 90,0,0,0},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_prob =     {0,0,0,0, 60,0,0,0, 0,0,0,0, 55,0,0,0},
}

-- 11. REGGAETON (Dembow)
-- Characteristic dembow riddim
drums.PRESETS["reggaeton"] = {
  name = "Reggaeton",
  kick_pattern =  {1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},
  kick_vel =      {120,0,0,0, 0,0,0,0, 0,0,115,0, 0,0,0,0},
  kick_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  kick_prob =     {100,0,0,0, 0,0,0,0, 0,0,100,0, 0,0,0,0},

  -- snare: dembow pattern (3-3-2 feel)
  snare_pattern = {0,0,0,1, 0,0,1,0, 0,0,0,1, 0,0,1,0},
  snare_vel =     {0,0,0,110, 0,0,105,0, 0,0,0,108, 0,0,100,0},
  snare_timing =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  snare_prob =    {0,0,0,100, 0,0,100,0, 0,0,0,100, 0,0,100,0},

  hat_pattern =   {1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1},
  hat_vel =       {85,40,65,38, 82,42,68,35, 85,38,65,40, 80,38,68,35},
  hat_timing =    {0,-2,1,-3, 0,-2,2,-3, 0,-2,1,-4, 0,-2,2,-3},
  hat_prob =      {100,90,95,85, 100,88,95,82, 100,90,95,88, 100,85,95,82},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  -- hat2: syncopated opens on the dembow hits
  hat2_pattern =  {0,0,0,1, 0,0,0,0, 0,0,0,1, 0,0,0,0},
  hat2_vel =      {0,0,0,85, 0,0,0,0, 0,0,0,80, 0,0,0,0},
  hat2_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  hat2_prob =     {0,0,0,90, 0,0,0,0, 0,0,0,85, 0,0,0,0},
  hat2_open =     {0,0,0,1, 0,0,0,0, 0,0,0,1, 0,0,0,0},

  perc_pattern =  {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_vel =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_timing =   {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
  perc_prob =     {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
}

-- 12. BROKEN BEAT (Dego / 4hero / IG Culture)
-- Irregular kick, complex hat interplay
drums.PRESETS["broken"] = {
  name = "Broken Beat",
  kick_pattern =  {1,0,0,0, 0,0,0,1, 0,1,0,0, 0,0,1,0},
  kick_vel =      {110,0,0,0, 0,0,0,90, 0,85,0,0, 0,0,100,0},
  kick_timing =   {0,0,0,0, 0,0,0,5, 0,-3,0,0, 0,0,2,0},
  kick_prob =     {100,0,0,0, 0,0,0,92, 0,88,0,0, 0,0,100,0},

  snare_pattern = {0,0,0,0, 1,0,0,0, 0,0,0,0, 0,1,0,0},
  snare_vel =     {0,0,0,0, 115,0,0,0, 0,0,0,0, 0,110,0,0},
  snare_timing =  {0,0,0,0, 3,0,0,0, 0,0,0,0, 0,4,0,0},
  snare_prob =    {0,0,0,0, 100,0,0,0, 0,0,0,0, 0,100,0,0},

  -- hat1: syncopated closed pattern
  hat_pattern =   {1,0,1,0, 0,1,0,1, 1,0,0,1, 0,1,0,1},
  hat_vel =       {85,0,60,0, 0,55,0,70, 80,0,0,58, 0,65,0,72},
  hat_timing =    {0,0,3,0, 0,-4,0,5, 2,0,0,-3, 0,4,0,3},
  hat_prob =      {100,0,92,0, 0,88,0,95, 100,0,0,85, 0,92,0,95},
  hat_open =      {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},

  -- hat2: interlocking counter-pattern with opens
  hat2_pattern =  {0,1,0,1, 1,0,1,0, 0,1,1,0, 1,0,1,0},
  hat2_vel =      {0,50,0,55, 60,0,48,0, 0,52,65,0, 58,0,50,0},
  hat2_timing =   {0,-3,0,4, 2,0,-3,0, 0,5,-2,0, 3,0,-4,0},
  hat2_prob =     {0,85,0,88, 92,0,82,0, 0,88,95,0, 90,0,85,0},
  hat2_open =     {0,0,0,1, 0,0,0,0, 0,0,1,0, 0,0,0,0},

  perc_pattern =  {0,0,1,0, 0,0,0,0, 0,0,0,0, 0,0,0,1},
  perc_vel =      {0,0,65,0, 0,0,0,0, 0,0,0,0, 0,0,0,60},
  perc_timing =   {0,0,2,0, 0,0,0,0, 0,0,0,0, 0,0,0,4},
  perc_prob =     {0,0,70,0, 0,0,0,0, 0,0,0,0, 0,0,0,65},
}

-- Preset order for cycling
drums.PRESET_ORDER = {
  "funk", "brazilian", "hiphop", "straight",
  "gospel_bounce", "trap", "neosoul", "afrobeat",
  "boombap", "gospel_shout", "reggaeton", "broken",
}

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
  mute = {false, false, false, false, false}, -- per-voice mutes (kick, snare, hat, hat2, perc)
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

  -- For hat voices, check open hat mask
  local is_open_hat = false
  if voice_name == "hat" and preset.hat_open and preset.hat_open[step] == 1 then
    is_open_hat = true
    midi_note = drums.MIDI_HAT_OPEN
  elseif voice_name == "hat2" and preset.hat2_open and preset.hat2_open[step] == 1 then
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
    trigger_voice("hat2", drums.MIDI_HAT_CLOSED, step, preset)
  end
  if not seq.mute[5] then
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
  if voice_idx >= 1 and voice_idx <= 5 then
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
    hat2 = preset.hat2_pattern or {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    perc = preset.perc_pattern,
    kick_vel = preset.kick_vel,
    snare_vel = preset.snare_vel,
    hat_vel = preset.hat_vel,
    hat2_vel = preset.hat2_vel or {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
    perc_vel = preset.perc_vel,
  }
end

------------------------------------------------------------------------
-- PARAMS (call from init)
------------------------------------------------------------------------

function drums.add_params()
  params:add_separator("DRUMS")

  params:add_option("drum_preset", "Drum Groove", {
    "Funk", "Brazilian Funk", "Hip-Hop", "Straight",
    "Gospel Bounce", "Trap", "Neo Soul", "Afrobeat",
    "Boom Bap", "Gospel Shout", "Reggaeton", "Broken Beat",
  }, 2)
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
