# Tic-Tac-Toe Game Map

An iPad app, built with SwiftUI, that plays tic-tac-toe while drawing your game as a path through a map of every possible ending.

Tic-tac-toe has 255,168 complete games, but if you treat rotations and reflections of the board as the same, they end on only **138 distinct finished boards**: 91 X wins, 44 O wins and 3 draws. The app follows your game from the empty board towards one of those 138.

## What it does

- **Play board:** a 3×3 board with pixel-art marks. It shows whose turn it is and the result of best play from the current position.
- **Game map:** each move travels down a branch to the next board. The boards you could reach next are shown as dashed options, each labelled with its best-play result and how many endings are still possible from it. Tap an option to play it, or tap an earlier board to go back.
- **Endings meter:** one dot for each of the 138 endings. A dot stays lit while that ending is still reachable. When the game ends, the meter marks which ending you reached.
- **Look and feel:** pastel light and dark themes, rounded shapes, and animated moves between boards. Reduce Motion is respected.
- **iPad behaviour:** text follows the system text size, buttons and squares react to the pointer, and the app has haptics and VoiceOver labels.
- **Keyboard shortcuts:** ⌘Z undo, ⌘N new game, ⌘R recenter the map, ⇧⌘D switch the theme.

## How it works

`Game.swift` solves the game with minimax over the 765 positions that remain once symmetric boards are merged. For each position it also records which of the 138 endings can still be reached. A board's canonical key is the smallest of its 8 rotations and reflections.

## Building

Requires Xcode 16 or later and iPadOS 18 or later.

Open `TicTacToeMap.xcodeproj` and run the `TicTacToeMap` scheme on an iPad or the iPad simulator.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After changing `project.yml`, regenerate it with:

```bash
xcodegen generate
```

## Web version

A browser version of the same app lives in its own repository, [tic-tac-toe-map](https://github.com/mageshsridhar/tic-tac-toe-map), and you can play it at https://mageshsridhar.github.io/tic-tac-toe-map/.
