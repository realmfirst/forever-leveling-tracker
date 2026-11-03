# Realm First Leveling Tracker

A small leveling tracker for World of Warcraft: Forever. One movable frame shows:

- XP per hour, for the last 15 minutes and for the whole session
- time to next level at the current rate
- rested XP as a percentage of the XP bar
- time played on the current level (from `/played`)
- a session summary: duration, XP gained, levels gained

It uses only standard Classic-family API calls (`UnitXP`, `UnitXPMax`, `GetXPExhaustion`, `RequestTimePlayed`, `TIME_PLAYED_MSG`, `PLAYER_XP_UPDATE`). No libraries, no network access.

## Install

1. Download `RealmFirstLeveling-1.0.0.zip` from the [latest release](https://github.com/realmfirst/forever-leveling-tracker/releases/latest), or install it from CurseForge once the project page is approved.
2. Unzip it so that the folder `RealmFirstLeveling` sits directly inside the `Interface/AddOns/` folder of your WoW Forever client (the same place your other Forever addons live).
3. Start the game and enable **Realm First Leveling Tracker** on the character select screen.

## Commands

| Command | What it does |
| --- | --- |
| `/rfl` | Show or hide the frame |
| `/rfl summary` | Print the current session summary to chat |
| `/rfl played` | Request `/played` and print it normally |
| `/rfl last` | Print the summary saved when you last logged out |
| `/rfl reset` | Start a new session |
| `/rfl lock`, `/rfl unlock` | Prevent or allow dragging the frame |

`/rflevel` works as an alias. Drag the frame with the left mouse button to move it. Position and visibility are saved in `RealmFirstLevelingDB`.

## Notes

- The addon asks for `/played` itself at login and after each level-up, and hides that chat output. `/rfl played` shows it.
- XP per hour needs about a minute of data before it shows a number.
- Time played counts while you are logged in, including time spent away from the keyboard.
- The TOC declares `## Interface: 16001`, the value for the 1.60.1 client.
- The automated checks run the Lua through a syntax check, unit tests for the calculations and a smoke test against a mocked game API. If something looks wrong in the live client, please open an issue with what you saw.

## Development

```
luac5.1 -p RealmFirstLeveling/*.lua
lua5.1 tests/calc_test.lua
lua5.1 tests/smoke_test.lua
```

Releases are a zip with the single top-level folder `RealmFirstLeveling`.

## About

Made by the Realm First desk. Guides, trackers and news for WoW Forever: <https://realmfirst.net/world-of-warcraft-forever/>

Licensed under the [MIT License](LICENSE).
