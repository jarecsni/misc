# display-modes.zsh
# Switches the iMac between colour-critical ("photo") and everyday ("day") modes.
# Sourced from ~/.zshrc by install.sh. See README.md for the full rationale.
#
# Requires: betterdisplaycli (BetterDisplay app must be running), nightlight

# ---- configuration -----------------------------------------------------------
# Display name comes from: betterdisplaycli get --identifiers
: ${DISPLAY_NAME:="Built-in Display"}

# PHOTO_BRIGHTNESS must match the luminance the ICC profile was measured at.
# If you recalibrate, update this value:
#   betterdisplaycli get --name="$DISPLAY_NAME" --brightness
: ${PHOTO_BRIGHTNESS:=0.67}
# ------------------------------------------------------------------------------

photomode() {
  betterdisplaycli set --name="$DISPLAY_NAME" --brightness=$PHOTO_BRIGHTNESS --autoBrightness=off
  betterdisplaycli set --trueTone=off          # Pro feature - fails silently without a licence
  nightlight schedule stop
  print -- "photo mode  | brightness $PHOTO_BRIGHTNESS | auto-brightness off | True Tone off | Night Shift schedule stopped"
}

daymode() {
  betterdisplaycli set --name="$DISPLAY_NAME" --autoBrightness=on
  betterdisplaycli set --trueTone=on           # Pro feature - fails silently without a licence
  nightlight schedule start
  print -- "day mode    | auto-brightness on | True Tone on | Night Shift sunset-to-sunrise"
}

# Read back actual state. System Settings caches its values and will lie to you;
# this does not.
displaystatus() {
  print -- "display:         $DISPLAY_NAME"
  print -- "brightness:      $(betterdisplaycli get --name="$DISPLAY_NAME" --brightness 2>/dev/null)"
  print -- "auto-brightness: $(betterdisplaycli get --name="$DISPLAY_NAME" --autoBrightness 2>/dev/null)"
  print -- "true tone:       $(betterdisplaycli get --trueTone 2>/dev/null)"
  print -- "night shift:     $(nightlight schedule 2>/dev/null)"
}
