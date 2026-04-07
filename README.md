# checkmate_hero

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Puzzle Schema (Mate in N)

Puzzles support line-based solving with multi-move sequences.

Required fields:

- `id` (int)
- `name` (string)
- `fen` (string)
- `difficulty` (string)
- `mode` (`"line"`)
- `movesToSolve` (int, player moves)
- `lineUci` (array of UCI moves, full line including opponent replies)

Example mate-in-2 puzzle:

```json
{
	"id": 13,
	"name": "Forced Net Mate in 2",
	"fen": "1rb1kb1r/pp1p2pp/P1p4n/n3ppq1/3P1P2/1NN4P/1PP1P1P1/R1BQKB1R b KQk - 3 12",
	"difficulty": "Advanced",
	"mode": "line",
	"movesToSolve": 2,
	"lineUci": ["g5g3", "e1d2", "a5c4"]
}
```

## Downloadable Packs

Pack loading is wired into the app. Set a remote index URL at launch:

```powershell
flutter run --dart-define=CHECKMATE_PACK_INDEX=https://your-host.example.com/index.json
```

Pack ZIP format (root files):

- `manifest.json`
- `puzzles.json`

Manifest example:

```json
{
	"id": "starter-tactics",
	"name": "Starter Tactics Pack",
	"version": "1.0.0",
	"puzzleCount": 2
}
```

## Local Pack Testing

1. Build a sample pack zip + index:

```powershell
python tools/pack_builder/build_pack_index.py --pack-dir sample_packs/starter_tactics --dist-dir sample_packs/dist --base-url http://localhost:8000
```

2. Host generated files:

```powershell
python -m http.server 8000 --directory sample_packs/dist
```

3. Run the app against local index:

```powershell
flutter run --dart-define=CHECKMATE_PACK_INDEX=http://localhost:8000/index.json
```

4. In app, open the packs button in the app bar and install `Starter Tactics Pack`.
