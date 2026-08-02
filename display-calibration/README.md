# iMac display calibration + mode switching

Setup notes and ready-to-run scripts for calibrating the 24" M3 iMac with a
Calibrite colorimeter, and for switching between colour-critical and everyday
display modes afterwards.

First set up: 2 August 2026.

---

## Quick start (new machine, or after a wipe)

```sh
chmod +x install.sh   # executable bit does not survive file transfer / fresh clone
./install.sh
source ~/.zshrc
```

Then recalibrate (see below) and update `PHOTO_BRIGHTNESS` in `display-modes.zsh`
to whatever the new calibration lands on.

Commands provided:

| Command | Effect |
|---|---|
| `photomode` | brightness → calibrated level, auto-brightness off, True Tone off, Night Shift schedule stopped |
| `daymode` | auto-brightness on, True Tone on, Night Shift back to sunset-to-sunrise |
| `displaystatus` | reads actual current state |

---

## Part 1 — Calibration (Calibrite PROFILER)

### Settings that matter

| Step | Choice | Why |
|---|---|---|
| Display and Technology Type | **GB LED** | Calibrite maps the 24" 4.5K Retina panel (late-2015 onward iMacs) to GB-LED. *Not* White LED — that is for pre-Retina Apple displays and the Studio Display. *Not* PFS Phosphor — that is Intel MacBook Pro. |
| Preset | **Photo** | D65 / gamma 2.2 / ~120 cd/m². Pre-Press is D50 at lower luminance for print-booth matching and looks yellow otherwise. Video targets Rec.709. |
| Manual adjustments | **Brightness only** | The iMac exposes no hardware contrast or RGB gain controls. Leave both unticked. |

### Before measuring

Turn all of these **off** in System Settings → Displays:

- Automatically adjust brightness (ambient sensor will move what you just set)
- True Tone (shifts white point with room lighting — invalidates the whole exercise)
- Night Shift (same problem; check it is not merely scheduled to kick in later)

Let the display warm up ~30 minutes. Dim the room so nothing reflects off the
glass onto the sensor.

### Brightness adjustment during the guided step

Brightness keys are F1/F2. If "Use F1, F2, etc. keys as standard function keys"
is enabled (System Settings → Keyboard → Keyboard Shortcuts… → Function Keys),
hold **fn** as well.

Hold **⌥⇧** while pressing them for quarter-steps — full steps are too coarse to
land on the target luminance.

### After calibration

The profile is written to `~/Library/ColorSync/Profiles/` (e.g.
`Apple_Display_26-08-02.icc`). Being in that folder *is* the installation —
there is no import step and no right-click action.

To select it: System Settings → Displays → Colour Profile. If it does not appear,
**quit System Settings entirely (⌘Q)** and reopen — the pane caches the list.
Log out and back in if that fails.

Do **not** use the `+` button in that panel. It opens Apple's Display Calibrator
Assistant, an unrelated eyeball-based wizard that produces a third, worse profile.

### Gotcha encountered

A stale `linear-mac.icc` was selected as the display profile. A gamma-1.0 profile
tells macOS the panel responds linearly, which it does not, so everything renders
substantially darker than intended. Worth checking for leftovers in
`/Library/ColorSync/Profiles/`.

### Expected result

The screen will look drastically dark immediately afterwards. This is correct —
the iMac ships around 400–500 nits and the Photo preset targets ~120. Eyes adapt
in about ten minutes. This is the most common reason people abandon a correct
calibration.

**Record the brightness value.** There is no mark on the slider and reading it
from a screenshot is unreliable (a slider that looked like 57% was actually 0.67).

```sh
betterdisplaycli get --name="Built-in Display" --brightness
```

Recalibrate roughly monthly — LED backlights drift.

---

## Part 2 — Mode switching

The ICC profile controls **neither brightness nor True Tone**. Leave the
calibrated profile selected permanently — it is a measurement of this specific
panel and is more accurate than the factory profile for everyday use too. Only
these change between modes:

| | Everyday | Photo editing |
|---|---|---|
| Brightness | comfortable | the calibrated level |
| Auto-brightness | on | off |
| True Tone | on | **off** |
| Night Shift | on schedule | schedule stopped |

True Tone genuinely matters: it shifts the display white point with ambient
lighting, which is exactly the variable the calibration fixed at D65.

### Tooling

- **BetterDisplay** + `betterdisplaycli` — brightness, auto-brightness, True Tone.
  The app must be **running** or the CLI returns *"Host app might not be running"*.
- **nightlight** — Night Shift, including the schedule. BetterDisplay's CLI can
  only toggle Night Shift on/off; it has no schedule parameter, which is why a
  second tool is used.

Display name is `Built-in Display`, not `iMac`. Confirm with
`betterdisplaycli get --identifiers`.

### Gotchas

- **System Settings does not live-update.** It caches values and will show stale
  state after a CLI change, which reads convincingly as "the script is broken" or
  "the toggle is inverted". Verify with `displaystatus`, not with the window.
- **Do not force Night Shift on** in `daymode` (`--nightShift=on`). It overrides
  the schedule immediately, so running it at 4pm gives a yellow screen. Use
  `nightlight schedule start` instead, which restores schedule control.
- `nightlight` subcommand is `schedule stop`, not `schedule off` — some
  documentation online has this wrong.
- Defining these as **functions**, not aliases: an alias of the same name already
  live in the shell will break the function definition with
  *"defining function based on alias"*. `unalias` first, or open a new shell.

---

## Part 3 — Licensing

| Feature used | Tier |
|---|---|
| `brightness` (get/set) | free |
| `autoBrightness` | free (Apple displays only) |
| `trueTone` | **BetterDisplay Pro** |
| Night Shift + schedule (`nightlight`) | free |

BetterDisplay Pro is $21.99 / €19.99, perpetual, with at least a year of updates.
A fresh install runs a 14-day trial with everything unlocked — features working
during the trial says nothing about whether they are gated.

Only `trueTone` requires the licence. Pro is therefore **optional**:

- **Buy it** if you want True Tone on for everyday use and off automatically for
  editing.
- **Skip it** by leaving True Tone off permanently in System Settings. Nothing to
  toggle, no licence needed. Cost: a slightly cooler-looking screen under warm
  indoor lighting. This is the recommended default for colour work.

If you skip it, delete the two `--trueTone=` lines from `display-modes.zsh` — they
fail silently rather than erroring, which is confusing later.

---

## Files

- `install.sh` — installs dependencies via Homebrew, sources `display-modes.zsh`
  from `~/.zshrc` between markers. Idempotent; backs up `~/.zshrc` first.
- `display-modes.zsh` — the `photomode` / `daymode` / `displaystatus` functions.

## References

- [Calibrite — Selecting the Correct Backlight Technology](https://calibrite.com/us/learning-centre/selecting-the-correct-backlight-technology/)
- [BetterDisplay — Integration features, CLI](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI)
- [nightlight](https://github.com/smudge/nightlight)
