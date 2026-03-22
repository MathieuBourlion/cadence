# Cadence

A macOS utility that floats above Capture One and lets photographers build and run automated camera control sequences via AppleScript.

## Download

1. Go to [Releases](../../releases) and download the latest `Cadence-vX.X.X.dmg`
2. Open the DMG and drag **Cadence** to your Applications folder
3. **First launch:** right-click Cadence → **Open** → **Open** to bypass macOS's security check for unsigned apps

## Requirements

- macOS 14+
- Capture One (any current version)

## Usage

1. Open Capture One and connect your camera(s)
2. Launch Cadence — it floats above Capture One
3. Add steps to build your sequence (capture, change settings, focus, wait)
4. Press Run to execute the sequence

## Supported Steps

- **Capture** — fire the shutter with configurable post-capture delay
- **Switch Camera** — select a different connected camera
- **Set ISO / Aperture / Shutter Speed** — change camera settings
- **Autofocus** — trigger autofocus
- **Move Focus** — adjust focus position (nearer/further, small/medium/large)
- **Wait** — pause for 1–60 seconds

## Presets

Save and load sequences as presets. Presets are stored as JSON in `~/Library/Application Support/Cadence/presets/`.

Note: Camera selections in Switch Camera steps are not saved in presets (cameras change between sessions). You'll need to re-select cameras after loading a preset.

## License

MIT
