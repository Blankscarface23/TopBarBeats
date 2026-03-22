# TopBarBeats Developer Log

## v2.0

### Bug Fixes
- **Playlist loading no longer aborts on a single bad track.** Previously, if one track failed to load (invalid ID or name fetch failure), the entire `loadTracks` call would stop. Now it skips the bad track with a warning and continues loading the rest.
- **Track switching now works correctly.** `toggleMusic` was calling `Resume()` even when switching to a different song, which wouldn't actually start playback. It now detects new tracks and calls `Play()` instead.
- **Auto-advance properly restarts the next track.** When a song ended, the next track could start mid-way because `TimePosition` wasn't being reset. Fixed.
- **Event connections are now properly cleaned up.** `Ended`, `Paused`, `Resumed`, and `Played` connections were never disconnected on `destroy()`, causing a memory leak. All connections are now tracked and disconnected during cleanup.
- **Removed the menu flicker workaround.** The nested `task.delay` deselect/reselect hack for rescaling the menu on long track names has been removed. Track title labels are now updated directly.
- **Fixed SoundGroup child lookup.** `init()` was checking for a child named `"Sound"` but the actual instance was named `"TopBarTrack"`, which could cause duplicate Sound instances.
- **Playlist order is now guaranteed.** `loadTracks` uses `ipairs` instead of `pairs` to preserve the order you pass tracks in.
- **Track index resets on reload.** Calling `loadTracks` again now properly resets `CurrentTrackIndex` to 1.

### New Features
- **Volume Control (API).** Set and get playback volume programmatically:
  - `TopBarBeats:setVolume(0.75)` — accepts a value from 0 to 1.
  - `TopBarBeats:getVolume()` — returns the current volume.
  - Volume is applied at the SoundGroup level for cleaner audio mixing.
  - You can also pass `volume` in the config table: `loadTracks({...}, { volume = 0.5 })`.
- **Repeat Modes (API).** Control what happens when a track ends:
  - `TopBarBeats:setRepeatMode("All")` — loop the entire playlist (default, same as v1.x behavior).
  - `TopBarBeats:setRepeatMode("One")` — loop the current track.
  - `TopBarBeats:setRepeatMode("Off")` — play through the playlist once and stop.
- **Mute Support.** `TopBarBeats.IsMuted` flag is available for muting without losing the volume setting.

### Efficiency Improvements
- Connection tracking via `_connections` table ensures zero leaked listeners.
- `destroy()` now fully cleans up all state: connections, sound instances, UI elements, and the SoundGroup.
- Removed unnecessary `pcall` wrapping around `validateSoundId` inside `toggleMusic` — validation already happens at load time. Validation in `toggleMusic` is kept as a safety net but failures are now handled gracefully.
- Eliminated redundant nil checks and tightened guard clauses throughout.

### Usage Example (v2.0)
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TopBarPlus = require(ReplicatedStorage.Icon)
local TopBarBeats = require(ReplicatedStorage.TopBarBeats)

TopBarBeats:init(TopBarPlus)
TopBarBeats:loadTracks({
    "rbxassetid://140584467386533",
    "rbxassetid://132839662402626",
    "rbxassetid://1839841807",
    "rbxassetid://129338574094673",
    "rbxassetid://79333319537529",
    "rbxassetid://92664338374114",
    "rbxassetid://87188555700638",
    "rbxassetid://131065621936266"
}, { autostart = true, shuffle = true, volume = 0.5 })

-- Loop just the current track
TopBarBeats:setRepeatMode("One")

-- Adjust volume at any time
TopBarBeats:setVolume(0.75)
```
