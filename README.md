# Turtle Map Notes

`Turtle Map Notes` is a standalone map notes addon for Turtle WoW.

It adds manual map notes, edit/delete dialogs, map coordinates, and automatic node notes for mining, herbalism, woodcutting and treasure chests.

## Features

- **Manual map notes**
  - `Ctrl + Right Click` on World Map to create a note at cursor location.
  - `Left Click` an existing note to edit its name.
  - `Right Click` an existing note to delete it (with confirmation dialog).
- **Tooltips**
  - Hover a note icon to show its note name.
- **Coordinates on map**
  - Bottom-left: cursor coordinates.
  - Bottom-right: player coordinates.
- **Automatic gathering and treasure notes**
  - Auto-adds notes when gathering **Mining**, **Herbalism**, and **Woodcutting** nodes.
  - Auto-adds notes for treasure chests when they are opened or interacted with.
  - Uses node-specific icons for ore, herb, wood, and treasure notes.
- **Map filter dropdown**
  - Adds a `Gathering` dropdown to the world map panel.
  - Filters notes by `All`, `Personal`, `Mining`, `Herbalism`, `Woodcutting`, or `Treasure`.
- **Per-map persistence**
  - Notes are saved per map/zone in `ForgedMapNotesDB`.

## Requirements

- **Game:** Turtle WoW (Vanilla Client)
- **Interface:** `11200`

## Installation

1. Copy the `ForgedMapNotes` folder into your WoW AddOns directory:
   - `World of Warcraft/Interface/AddOns/ForgedMapNotes`
2. Start the game (or type `/reload`).
3. Enable **ForgedMapNotes** in the AddOns list.

## Usage

### Manual notes

- Open World Map.
- Hold `Ctrl` and **Right-Click** where you want a note.
- Enter a note name and press **Accept** (or `Enter`).

### Edit/Delete notes

- **Left-Click** a note icon to edit its name.
- **Right-Click** a note icon to open delete confirmation.

### Slash command

- `/tmn clear`
  - Clears notes for the currently viewed map.

## Survival Woodcutting

The addon recognizes these Turtle WoW woodcutting node types and stores them as map notes when gathered:

- `Simple Wood`
- `Bright Wood`
- `Shade Wood`
- `Tropical Wood`
- `Dead Wood Tree`
- `Star Wood`

## Notes

- Auto note detection is based on gather, loot, cast, and error events plus tooltip node names.
- If behavior seems stale after updates, use `/reload`.

## Credits

Inspired by the original Cartographer ecosystem:

- Cartographer Notes
- Cartographer_Mining
- Cartographer_Herbalism
