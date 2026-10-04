# RETROGRADE - Notation, Prior Art

Real-world systems for printing a timed pulse rhythm, researched 2026-09-24 while looking for
a better form for the **Notation** (`docs/SWEEP.md` §5).

Reference only. **No direction here is chosen** - the light-character system below was the
strongest candidate and was set aside on 2026-09-25. The Notation's printed form is still
open, and the dot grid `PlacardPanel` draws today is still what ships.

Primary standards were pulled and rendered rather than taken from summaries; anything
unverified is flagged.

---

## 1. Why this was worth looking up

The thing being printed is a sequence of key-holds of varying duration, which a player must
read off a surface and then perform. That is an unusual thing to print, and the search turned
up one **negative finding worth keeping**: there is no standardised notation anywhere for
"press and hold for N seconds" on equipment placards. IEC 80416 governs how safety symbols are
*constructed*, not how durations are expressed. The space is unclaimed.

The closest real analogue is not a computer interface at all. It is maritime navigation.

---

## 2. Light characteristics (IALA / IHO)

The system for describing a lighthouse or buoy's flash rhythm, printed on every nautical chart.
It exists to solve exactly the same problem: a timed on/off sequence, printed very small, read
under pressure, matched against a real signal.

### The string

Order is fixed: **class → group → colour → period → elevation → range.**

`Fl(3)WRG.15s.21m.15-11M` = group flashing, three flashes; white/red/green sectors; a 15-second
period ("the time taken to exhibit one full sequence of three flashes and eclipses"); focal
plane 21 m; nominal range 15-11 nautical miles.

Classes: `F` fixed · `Oc` occulting (light longer than dark) · `Iso` isophase (equal) ·
`Fl` flashing (dark longer than light) · `LFl` long-flashing (flash ≥ 2 s) · `Q` quick (50-79
per minute) · `VQ` very quick (80-159) · `UQ` ultra quick (≥160) · `Mo(K)` Morse ·
`FFl` fixed and flashing · `Al` alternating. Groups are `(3)`; composite groups `(2+1)`;
interrupted forms `IQ`, `IVQ`, `IUQ`.

Morse lights (IALA E-110 §8): dot ≈ 0.5 s, dash not less than 3 × the dot. Worked `Mo(A)`:
`l 0.5s, d 0.5s, l' 1.5s, d' 4.5s, p 7s`.

**Cardinal marks** are the canonical "memorise four rhythms" set, on a clock-face mnemonic:
E = `Q(3)10s`, S = `Q(6)+LFl.15s`, W = `Q(9)15s`, N = continuous `Q`. The long flash on the
south mark exists for no reason except to make certain you counted six.

### The printed diagram

This is the part worth looking at, and it is drawn the opposite way round from a chart or a
timing diagram:

- **The bar is black, and black is darkness.** Roughly 15:1 aspect. The bar is the timeline.
- **Light is a white shape punched out of it.** Not ink on paper - a hole in the dark.
- **Shape encodes the duration class.** A sustained flash is a **white rectangle** whose width
  is proportional to its duration. A quick flash is a **white triangle**, apex up, rising off
  the bottom edge and not reaching the top. Ultra-quick becomes a comb of hairlines.
  So "tap" and "hold" differ in *shape*, not only in width - which is what survives small print.
- `Mo(K)` renders as wide rectangle, triangle, wide rectangle. In E-110's `Mo(A)` figure the
  dash is drawn **exactly 3 × the dot's width**.
- **Dimension labels** sit outside the bar on thin vertical ticks: `l` light, `d` dark,
  `l'`/`d'` the long ones, `c` cycle within a group, `p` period spanning the whole thing below.
- Chart No. 1 prints a thin **magenta bracket with end ticks** under the bar spanning one period.
- Alternating lights put the colour letter inside each white box: `W R W R`.

### The machine-readable form

IHO **S-57 attribute `SIGSEQ`** serialises a light's literal durations:

```
00.8+(02.2)+00.8+(05.2)        flashing
(00.8)+02.2+(00.8)+05.2        occulting
```

Seconds, 0.01 s resolution. **Bare = light on, parenthesised = dark.** Companion attributes
`SIGPER` (period) and `SIGGRP` (group, e.g. `VQ(6)+LFl` → `(6)(1)`).

### Fog signals - the same grammar, for sound

Chart No. 1 **Section R** applies all of the above to acoustic signals: `SIREN Mo(N) 60s`,
`HORN(1) 15s`, `BELL`, `Whis`, `Gong`, `Dia`, `Explos`. Radar beacons in Section S print as
`Racon(Z)` or sometimes with the bare Morse glyph, `RACON (–)`.

So the precedent for this notation describing an *acoustic* pulse - which is what a Sweep is -
is already on the charts.

### How it is performed

Navigator practice is **time it first, then look it up** - stopwatch, or counting "Mississippi
one". Identification is always character *plus* period, never character alone.

### If it is ever revisited

The composite-group syntax maps onto a Procedure's word structure with no adaptation:
`Fl(2+1)` is a group of two then a group of one, which is an Operation and its Argument. SR-7's
`SEAT·1 CYCLE·1` would print as `Fl(1+1)(2+1) LFl`, derived from `ProcedureDef.steps` with no
authoring, and it scales - Roke's four words with a prologue are `Fl(6+6)(3+2)(1+3)(2+1) LFl`.

Sources: [IALA E-110](https://www.iala.int/content/uploads/2017/03/E-110-Ed.4-Rhythmic-Characters-of-Lights-on-Aids-to-Navigation_16Dec2016.pdf) ·
[NGA Chart No. 1 Sec. P](https://msi.nga.mil/api/publications/download?key=16694005%2FSFH00000%2FSec_P.pdf) ·
[Sec. R, fog signals](https://msi.nga.mil/api/publications/download?key=16694005%2FSFH00000%2FSec_R.pdf) ·
[IHO S-57 App. A ch.2](https://iho.int/uploads/user/pubs/standards/s-57/31ApAch2.pdf) ·
[Sealite IALA flash codes](http://sealite.s3.amazonaws.com/newweb/files/6_pdf.pdf) ·
[Light characteristic](https://en.wikipedia.org/wiki/Light_characteristic) ·
[Identifying lights at night](https://www.safe-skipper.com/light-characteristics-how-do-navigators-identify-lights-at-night/)

---

## 3. Duration as symbol

**Morse.** ITU-R M.1677-1 Annex 1 §2: "A dash is equal to three dots. The space between the
signals forming the same letter is equal to one dot. The space between two letters is equal to
three dots. The space between two words is equal to seven dots." Note the ITU never says
"dot = 1 unit" - **the dot is the unit.** `PARIS` is exactly 50 units, hence
`dit_ms = 1200 / WPM`. Farnsworth timing stretches only the 19 units of *silence*, never the
elements, which is how rhythm stays legible at slow speed. Prosigns are letters run together
with the inter-letter gap deleted, printed with an overbar.

The **International Code of Signals** (Pub 102 ch.1) adds an instruction worth keeping: "it is
best to err on the side of making the dots rather shorter in their proportion to the dashes as
it then makes the distinction between the elements plainer" - i.e. exaggerate past 3:1. It also
gives a real human rate: forty letters a minute by flashing light.

⚠️ No standard mandates a printed 3:1 dash-to-dot *glyph* ratio. That is temporal only; drawing
it mimetically is a choice.

**Wheatstone perforated tape** is the strongest printed Morse and the best answer found to
"show the grid without a spreadsheet": three rows, where the top hole turns the mark on, the
bottom hole turns it off, and **the middle row has a hole at every single time slot**. The
middle row is a printed clock. Self-clocking - the grid is drawn in.

**COLREGS sound signals.** Rule 32: short blast ≈ 1 s, prolonged blast 4-6 s. Two durations,
ratio looser than Morse on purpose. ⚠️ The regulations contain no glyphs at all; the `• — •`
rendering is teaching convention, and the chart-legal printed form is Section R's grammar.

**Timing diagrams** (digital logic). Horizontal time, no vertical scale, one signal per row,
name at left, clock on top. Transitions drawn deliberately **slanted** so an arrowhead can land
on a threshold. Buses are hexagons with the value inside; hatching means don't-care; a
mid-height line is high-Z; a zig-zag break across all rows means time passes. Parameters are
double-headed arrows on dashed verticals dropped from the two edges. ⚠️ No enforced standard -
vendors contradict each other; IEEE 991-1986 is nearest and is paywalled.

**WaveDrom / WaveJSON** is a compact text DSL worth copying if Procedures ever need hand
authoring: one character = one time slot, and `.` extends the previous state by one more slot,
so `"1...."` is a five-slot hold.

**Code 39 barcode** gives empirical contrast guidance: wide-to-narrow ratio 2:1 minimum, 3:1
preferred; below 2:1 even scanners misread.

Sources: [ITU-R M.1677-1](https://www.itu.int/rec/R-REC-M.1677-1-200910-I/) ·
[Pub 102 ch.1](https://msi.nga.mil/api/publications/download?key=16694273%2FSFH00000%2FChapter1.pdf) ·
[Wheatstone system](https://en.wikipedia.org/wiki/Wheatstone_system) ·
[WaveJSON](https://github.com/wavedrom/schema/blob/master/WaveJSON.md) ·
[JEDEC JESD79](https://cs.baylor.edu/~maurer/CSI5338/JEDEC79R2.pdf) ·
[IALA COLREG sound signals](https://ialacolreg.com/en/sound-signals)

---

## 4. Whales, dolphins, bioacoustics

**Payne & McVay 1971**, *Songs of Humpback Whales* (Science 173:585-597) gave the hierarchy
still in use: **subunit → unit → subphrase → phrase → theme → song → song session**. That maps
onto this game's **Mark → word → Procedure** almost exactly. The figures are hand tracings of
Kay sonograph printouts, redrawn to strip noise and harmonics, laid out frequency-vertical and
time-horizontal, read left to right then top to bottom "the same as sheet music". McVay printed
one syllable at a time and taped the pages into a scroll he rolled across his living-room
floor; that is how the repeat was found. The *Science* cover was a photonegative of the
tracings - white on black. ⚠️ Closed access; whether the original figures lettered the units is
unverified.

**The modern symbolic layer** is the useful part. Spectrogram plus four coexisting conventions:
abbreviated unit names (`ac` ascending cry, `dws` descending whistle); **a one-letter-per-unit
alphabet**, so a phrase is literally a word and two themes can differ by a single letter;
themes as numbers with letter variants (`2A`), drift written as a chain `3-a → 3-ab → 3-b`; and
**a whole song as a comma-separated theme string** - `1,2,3,4,5,6,7,8`, with variants
`1,4,5,7,8`, `1,2,8`, `2,3`. Strings are rotated to start at the lowest theme number, and songs
are compared by Levenshtein distance with acoustically weighted substitution costs.

**Variation is almost always deletion, never reordering.** That is a ready-made rule if seeded
Gate Procedures (ADR 0005) ever need to vary in a way that stays readable.

**Watkins' sonagram anatomy**, if a spectrogram is ever drawn in-game: pale warm-grey mottled
field about 3:1, **no box and no gridlines** - just em-dash ticks outside the left edge with
numerals, and a hand-lettered italic `cps` set vertically between the top two ticks. Time axis
is a thin baseline with `0 … 1 … 2` and hand-lettered `time – seconds`. Small black
oscilloscope insets with white traces pasted above. And his rule, exclamation mark included:
"The filter bandwidth should be indicated on every published spectrogram!"

**Dolphin signature whistles** are polylines of (time, frequency). ARTwarp's `.ctr` format is a
bare vector of frequencies on a fixed 0.01 s grid - no time column, time is the index. Shape
vocabulary: constant / upsweep / downsweep / concave / convex / sine. The compact encoding is
**Parsons code**: resample to ten segments, record each as up/down/constant, giving a nine-trit
string - 3⁹ = 19,683 possible whistles. A whole identity in nine symbols.

⚠️ **The "Payne song wheel" does not exist.** No circular or spiral Payne display could be
found. The circular whale images people remember are **Mark Fischer / AguaSonic** - continuous
wavelet transforms plotted in polar coordinates, printed at 4×8 ft. The song genuinely is
cyclical, but the literature handles that as a rotation-normalisation rule on theme strings,
not as a drawn wheel.

Sources: [Payne & McVay 1971](https://www.science.org/doi/10.1126/science.173.3997.585) ·
[Watkins 1967 (WHOI)](http://web.archive.org/web/20220120055118id_/https://darchive.mblwhoilibrary.org/bitstream/handle/1912/2726/WHOI-68-13.pdf) ·
[Kershenbaum et al. 2016](https://pmc.ncbi.nlm.nih.gov/articles/PMC4720438/) ·
[ARTwarp](https://www.marineconservationresearch.co.uk/downloads/artwarp/) ·
[Parsons code](https://en.wikipedia.org/wiki/Parsons_code) ·
[AguaSonic](https://aguasonic.com/)

---

## 5. Sonar and echo-sounding displays

Not notation, but the visual register the game is already in. Useful if the Log, the scanner or
the Sweep's own readout ever want a period-accurate look.

- **A-scan.** X = time of flight (range), Y = echo amplitude off a flat baseline carrying
  "grass" (noise hash). A huge clipped **main bang** at far left with a dead zone behind it,
  then the front-surface echo, flaw spikes, and a backwall echo with evenly spaced decaying
  repeats. Amplitude in %FSH. A **gate** is a horizontal bar floating at a threshold height
  over a span of X - anything breaking it alarms.
- **M-mode.** One beam line. X = time, scrolling; Y = depth downward. Stationary structure
  draws a dead-straight horizontal line, moving structure a wavy one. Sweep speed is an
  explicit control in mm/s.
- **PPI.** Polar. Radius = range, angle = bearing, 12 o'clock = 000°, sweep rotates clockwise.
  Blips are **arcs, not dots** - smeared tangentially by beamwidth and radially by pulse
  length. Real phosphors (P7/P19/P26/P33) were **amber and yellow-green**, not saturated green,
  with a brighter leading edge and a comet tail fading round the clock.
- **BTR / waterfall.** X = bearing, Y = time flowing downward, newest at top. A contact is a
  vertical bright streak, fuzzy at beamwidth. **Vertical means constant bearing; slope is
  bearing rate; a kink means the target manoeuvred.** Historically annotated in grease pencil
  on the glass.
- **LOFARgram.** X = frequency, Y = time downward, burned onto electrostatic paper by a
  sweeping stylus. Thin persistent vertical lines in **harmonic combs** through a grainy
  speckle field. A DEMON gram is the same geometry over 0-500 Hz of modulation frequency.
- **Paper echo sounder.** A stylus on a belt makes one constant-velocity pass while the paper
  creeps perpendicular - **the stylus pass is the timebase**, and it fires the transmitter as it
  crosses zero. Heavy black transmission line ruled down the top edge, a ringing band, then the
  bottom contour as a thick black line whose thickness is hardness, with second and third echoes
  at exactly 2× and 3× depth. A **fish arch** is an inverted U because the beam is a cone: arch
  thickness is target strength, arch width is dwell time, so boat speed rather than fish size.
- **WWII ASDIC range recorder.** Paper rolls downward for time, stylus sweeps across for range,
  one dash per ping. Stacked pings form a track **whose slope is the closing rate**, and the
  extrapolated diagonal carries the attack through the final blind run when the target passes
  under the beam. ⚠️ The slope-direction convention here traces to a game dev diary, not a
  primary manual.

Sources: [PPI](https://en.wikipedia.org/wiki/Plan_position_indicator) ·
[LOFAR](https://en.wikipedia.org/wiki/Low_Frequency_Analyzer_and_Recorder) ·
[FAO fisheries acoustics](https://www.fao.org/4/x5818e/x5818e04.htm) ·
[ASDIC aboard HMCS Haida](http://www.jproc.ca/sari/asd_gen.html)

---

## 6. Printed rhythm, elsewhere

- **TUBS** (Time Unit Box System, Harland/Koetting ~1962). A contiguous strip of equal-width
  boxes with shared walls, each box one fixed time unit, mark = event, stacked rows vertically
  aligned for simultaneous voices, heavier rule every 4 boxes. Proportional, unlike staff
  notation. ⚠️ Canonical TUBS encodes **onset only, not duration**.
- **Piano roll.** Physically: lateral position = note, **slot length along the paper =
  duration**, tempo printed on the leader in feet per minute. Long holds are punched as a chain
  of short holes with paper bridges (or the roll tears), **densest at the attack** then sparse
  to the release - a physically motivated way to draw "press, then keep holding".
- **ECG paper.** 25 mm/s; small square 1 mm = 0.04 s, large square 5 mm = 0.20 s, five large
  squares = 1 second. Fine grid in a light tint with **every fifth line heavier**, and a
  **printed calibration pulse** (10 mm tall, 0.2 s wide) at the start of the strip so the reader
  confirms the scale before measuring anything.
- **Seismogram / helicorder.** Paper on a rotating drum, stylus stepping down each rotation, so
  a day is a stack of parallel lines read like a page of text. **Minute marks are a small jog in
  the trace itself**, not separate ticks. Phases annotated as a vertical tick through the trace
  with the letter beside it (P, S, pP, PKIKP).
- **Labanotation.** A vertical staff read **bottom to top**, columns per body part, and
  **symbol length = movement duration**, shading = level. Key-holds of varying duration in a
  column-per-key vertical layout - the alternative to a horizontal timeline, and it scrolls.
- **Kodály stick notation.** The most ink-efficient printed rhythm: bare stems, no noteheads.
  Quarter is `|`, an eighth pair is `∏`. Noteheads come back only for half and whole notes.
- **Aretas Saunders' birdsong shorthand** (*A Guide to Bird Songs*, 1935). A three-band score:
  prose timbre label on top; the song drawn as lines on an implicit pitch/time field where
  **length = duration, height = pitch, thickness = loudness, broken = trill, slant = glide**;
  phonetic syllables underneath. Five dimensions in one drawn line, no axes and no noteheads.

Sources: [TUBS](https://en.wikipedia.org/wiki/Time_unit_box_system) ·
[Tufte on bird song notation](https://www.edwardtufte.com/notebook/visual-notation-of-bird-songs/) ·
[Labanotation](https://en.wikipedia.org/wiki/Labanotation) ·
[ECG basics](https://litfl.com/ecg-basics/)

---

## 7. What recurs across all of them

Patterns that held in every system looked at, whatever form the Notation eventually takes:

1. **Length = duration** is the universal legend-free idiom - piano roll, Morse tape, ECG,
   Labanotation, IALA bars. Nobody has to be told.
2. **Two hold-lengths, not more.** Morse 1:3, COLREGS 1:4-6. American Morse had more dash
   lengths and was abolished in 1865 for being unreadable. ⚠️ This constrains *open-loop*
   reading - decoding a stranger's signal with no readout and one chance. Retrograde's input is
   closed-loop (the bar draws the Slot as the key is held, and `CoreHousing` echoes each Mark
   back), so it does not transfer to the number of Slots. It does still apply to the print.
3. **Exaggerate the ratio past the spec.** The ICS says so in as many words.
4. **Give the classes different shapes, not just different widths** - IALA's triangle versus
   rectangle. Readable when small or degraded, which width alone is not. The drawing may be
   coarser than the signal: shape carries the class, width carries the value.
5. **The gap is part of the notation.** Morse specifies 1/3/7, COLREGS ~2 s between blasts,
   IALA constrains every eclipse.
6. **Nest the grid 5:1 and print a calibration glyph** (ECG). Coarse count on big divisions,
   fine on small, never reach for a ruler.
7. **Separate proportion from rate.** The diagram carries the shape; one number outside carries
   the period - `.15s`, `♩=120`, `25 mm/s`.
8. **Draw light as holes in a dark bar**, not ink on white, if it should read as signal in
   darkness.
9. **Have the reader time it before matching it.** Real navigator practice, and a better
   mechanic than pattern recognition alone.
