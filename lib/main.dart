import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_models.dart';
import 'puzzle_repository.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PuzzleController()..initialize(),
      child: const CheckmateHeroApp(),
    ),
  );
}

class CheckmateHeroApp extends StatelessWidget {
  const CheckmateHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checkmate Hero',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PuzzleScreen(),
    );
  }
}

class PuzzleScreen extends StatelessWidget {
  const PuzzleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkmate Hero'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: 'Progress',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ProgressScreen(),
                ),
              );
            },
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'Reset progress',
            onPressed: () => _showResetProgressDialog(context),
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            tooltip: 'Packs',
            onPressed: () async {
              final vm = context.read<PuzzleController>();
              await vm.refreshPackCatalog();
              if (context.mounted) {
                _showPackManager(context);
              }
            },
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: Consumer<PuzzleController>(
        builder: (context, vm, _) {
          if (vm.isPuzzleSolved && !vm.dialogShown) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSuccessDialog(context, vm);
            });
          }

          if (vm.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(vm.statusText, style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final boardSize = math.min(
                constraints.maxWidth - 24,
                constraints.maxHeight - 260,
              );

              return SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Puzzle ${vm.currentPuzzleNumber} of ${vm.totalPuzzles}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontSize: 18),
                              ),
                              if (vm.currentPuzzle != null) ...[
                                const SizedBox(width: 12),
                                Chip(
                                  label: Text(vm.currentPuzzle!.difficulty),
                                  backgroundColor: Colors.blue.shade100,
                                ),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Solved: ${vm.solvedCount}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          if (vm.currentPuzzle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '${vm.currentPuzzle!.name} • ${vm.objectiveText}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700],
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (vm.totalLinePly > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Step ${vm.currentLineStep}/${vm.totalLinePly}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Center(
                      child: Chessboard(
                        size: boardSize.clamp(240.0, 520.0),
                        orientation: dc.Side.white,
                        fen: vm.fen,
                        lastMove: vm.lastMove,
                        shapes: vm.shapes,
                        settings: const ChessboardSettings(
                          drawShape: DrawShapeOptions(enable: false),
                        ),
                        game: GameData(
                          playerSide: vm.playerSide,
                          sideToMove: vm.sideToMove,
                          validMoves: vm.validMoves,
                          promotionMove: null,
                          isCheck: vm.isInCheck,
                          onMove: vm.onUserMove,
                          onPromotionSelection: (_) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      vm.statusText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: vm.canShowHint ? vm.showHint : null,
                          icon: const Icon(Icons.lightbulb),
                          label: const Text('Hint'),
                        ),
                        FilledButton.icon(
                          onPressed: vm.hasNextPuzzle ? vm.nextPuzzle : null,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Next Puzzle'),
                        ),
                        OutlinedButton.icon(
                          onPressed: vm.resetCurrentPuzzle,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showResetProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
          'This will mark all solved puzzles as unsolved so they can appear again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await context.read<PuzzleController>().resetProgress();
              if (context.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showPackManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Puzzle Packs'),
          content: SizedBox(
            width: 450,
            child: Consumer<PuzzleController>(
              builder: (context, vm, _) {
                if (vm.isRefreshingPacks) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Installed',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (vm.installedPacks.isEmpty)
                        const Text('No downloaded packs yet.'),
                      ...vm.installedPacks.map(
                        (pack) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${pack.name} (${pack.version})'),
                          subtitle: Text('${pack.puzzleCount} puzzles'),
                          trailing: IconButton(
                            tooltip: 'Remove pack',
                            onPressed: vm.isInstallingPack
                                ? null
                                : () => vm.removePack(pack.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Available',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (vm.availablePacks.isEmpty)
                        const Text(
                          'No remote pack catalog configured. Add a pack index URL in PackService.',
                        ),
                      ...vm.availablePacks.map(
                        (pack) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${pack.name} (${pack.version})'),
                          subtitle: Text('${pack.puzzleCount} puzzles'),
                          trailing: vm.isPackInstalled(pack.id)
                              ? const Text('Installed')
                              : FilledButton(
                                  onPressed: vm.isInstallingPack
                                      ? null
                                      : () => vm.installPack(pack),
                                  child: vm.installingPackId == pack.id
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Install'),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.read<PuzzleController>().refreshPackCatalog(),
              child: const Text('Refresh'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, PuzzleController vm) {
    if (vm.dialogShown) return;
    vm.markDialogShown();

    if (vm.isAtEndOfList || !vm.hasNextPuzzle) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text(
            'You\'ve completed all available puzzles!\n\n'
            'More Puzzles Coming Soon™',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialog);
                vm.resetCurrentPuzzle();
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          title: const Text('Puzzle Solved!'),
          content: Text('Great sequence. ${vm.objectiveText} complete.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialog);
                vm.nextPuzzle();
              },
              child: const Text('Next Puzzle'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialog);
                vm.resetCurrentPuzzle();
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      );
    }
  }
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Consumer<PuzzleController>(
        builder: (context, vm, _) {
          final total = vm.totalPuzzleCatalogCount;
          final solved = vm.solvedCount;
          final remaining = total - solved;
          final progressPercent = total == 0 ? 0.0 : solved / total;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text('Solved: $solved / $total'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progressPercent),
                      const SizedBox(height: 8),
                      Text('Remaining: $remaining'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By Difficulty',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (vm.progressByDifficulty.isEmpty)
                        const Text('No data yet.'),
                      ...vm.progressByDifficulty.entries.map(
                        (entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key),
                          trailing: Text(
                            '${entry.value.solved}/${entry.value.total}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By Pack',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (vm.progressByPack.isEmpty)
                        const Text('No data yet.'),
                      ...vm.progressByPack.entries.map(
                        (entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key),
                          trailing: Text(
                            '${entry.value.solved}/${entry.value.total}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PuzzleController extends ChangeNotifier {
  PuzzleController({PuzzleRepository? repository})
      : _repository = repository ?? PuzzleRepository();

  static const String _solvedIdsStorageKey = 'solved_puzzle_ids_v1';

  final PuzzleRepository _repository;
  final math.Random _random = math.Random();

  late chess.Chess _game;
  late chess.Color _solverColor;

  List<Puzzle> _allPuzzles = <Puzzle>[];
  List<Puzzle> _puzzles = <Puzzle>[];
  List<String> _lineUci = <String>[];
  int _plyIndex = 0;
  int _puzzleIndex = 0;

  bool _dialogShown = false;
  bool _isAtEndOfList = false;
  bool _isLoading = true;
  bool _isPuzzleSolved = false;
  bool _isRefreshingPacks = false;
  bool _isInstallingPack = false;
  String? _installingPackId;

  String _statusText = 'Loading puzzles...';
  ISet<Shape>? _shapes;
  dc.NormalMove? _lastMove;

  List<PackIndexItem> _availablePacks = <PackIndexItem>[];
  List<InstalledPack> _installedPacks = <InstalledPack>[];
  Set<int> _solvedPuzzleIds = <int>{};

  bool get isLoading => _isLoading;
  bool get isPuzzleSolved => _isPuzzleSolved;
  bool get isInCheck => _game.in_check;
  bool get dialogShown => _dialogShown;
  bool get isAtEndOfList => _isAtEndOfList;
  String get statusText => _statusText;
  String get fen => _game.fen;
  ISet<Shape>? get shapes => _shapes;
  dc.NormalMove? get lastMove => _lastMove;
  int get currentPuzzleNumber => _puzzles.isEmpty ? 0 : _puzzleIndex + 1;
  int get totalPuzzles => _puzzles.length;
  int get solvedCount =>
      _allPuzzles.where((puzzle) => _solvedPuzzleIds.contains(puzzle.id)).length;
  int get totalPuzzleCatalogCount => _allPuzzles.length;
  bool get hasNextPuzzle => _puzzleIndex < _puzzles.length - 1;
  Puzzle? get currentPuzzle =>
      _puzzleIndex < _puzzles.length ? _puzzles[_puzzleIndex] : null;
  int get currentLineStep =>
      _lineUci.isEmpty ? 0 : math.min(_plyIndex + 1, _lineUci.length);
  int get totalLinePly => _lineUci.length;
  bool get canShowHint =>
      !_isLoading && !_isPuzzleSolved && _plyIndex < _lineUci.length;

  bool get isRefreshingPacks => _isRefreshingPacks;
  bool get isInstallingPack => _isInstallingPack;
  String? get installingPackId => _installingPackId;
  List<PackIndexItem> get availablePacks => List.unmodifiable(_availablePacks);
  List<InstalledPack> get installedPacks => List.unmodifiable(_installedPacks);

  Map<String, ({int solved, int total})> get progressByDifficulty {
    final map = <String, ({int solved, int total})>{};
    for (final puzzle in _allPuzzles) {
      final key = puzzle.difficulty;
      final old = map[key] ?? (solved: 0, total: 0);
      map[key] = (
        solved: old.solved + (_solvedPuzzleIds.contains(puzzle.id) ? 1 : 0),
        total: old.total + 1,
      );
    }
    return map;
  }

  Map<String, ({int solved, int total})> get progressByPack {
    final map = <String, ({int solved, int total})>{};
    for (final puzzle in _allPuzzles) {
      final key = puzzle.packId;
      final old = map[key] ?? (solved: 0, total: 0);
      map[key] = (
        solved: old.solved + (_solvedPuzzleIds.contains(puzzle.id) ? 1 : 0),
        total: old.total + 1,
      );
    }
    return map;
  }

  String get objectiveText {
    final moves = currentPuzzle?.movesToSolve ?? 1;
    return 'Mate in $moves';
  }

  dc.Side get sideToMove =>
      _game.turn == chess.Color.WHITE ? dc.Side.white : dc.Side.black;

  PlayerSide get playerSide {
    if (_isPuzzleSolved || _isLoading) return PlayerSide.none;
    if (_game.turn != _solverColor) return PlayerSide.none;
    return _solverColor == chess.Color.WHITE
        ? PlayerSide.white
        : PlayerSide.black;
  }

  ValidMoves get validMoves => _buildValidMoves();

  Future<void> initialize() async {
    _isLoading = true;
    _statusText = 'Loading puzzles...';
    _dialogShown = false;
    _isAtEndOfList = false;
    notifyListeners();

    await _loadProgress();
    await _reloadAllPuzzles(resetIndex: true);
    await refreshPackCatalog(silent: true);

    if (_puzzles.isEmpty) {
      _statusText =
          _solvedPuzzleIds.isNotEmpty
              ? 'All puzzles solved. Reset progress to play again.'
              : 'No puzzles found. Please check your puzzle data.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    await resetCurrentPuzzle();
  }

  Future<void> refreshPackCatalog({bool silent = false}) async {
    if (!silent) {
      _isRefreshingPacks = true;
      notifyListeners();
    }

    try {
      _installedPacks = await _repository.listInstalledPacks();
      _availablePacks = await _repository.fetchAvailablePacks();
    } catch (_) {
      if (!silent) {
        _statusText =
            'Could not refresh pack catalog. Verify your pack index URL.';
      }
    } finally {
      _isRefreshingPacks = false;
      notifyListeners();
    }
  }

  bool isPackInstalled(String packId) {
    return _installedPacks.any((pack) => pack.id == packId);
  }

  Future<void> installPack(PackIndexItem pack) async {
    if (_isInstallingPack) return;

    _isInstallingPack = true;
    _installingPackId = pack.id;
    _statusText = 'Installing ${pack.name}...';
    notifyListeners();

    try {
      await _repository.installPack(pack);
      await _reloadAllPuzzles();
      await refreshPackCatalog(silent: true);
      _statusText = '${pack.name} installed. Puzzles added to rotation.';
    } catch (_) {
      _statusText = 'Failed to install ${pack.name}. Please try again.';
    } finally {
      _isInstallingPack = false;
      _installingPackId = null;
      notifyListeners();
    }
  }

  Future<void> removePack(String packId) async {
    if (_isInstallingPack) return;

    _isInstallingPack = true;
    _installingPackId = packId;
    _statusText = 'Removing pack...';
    notifyListeners();

    try {
      await _repository.removePack(packId);
      await _reloadAllPuzzles();
      await refreshPackCatalog(silent: true);
      _statusText = 'Pack removed.';
    } catch (_) {
      _statusText = 'Failed to remove pack.';
    } finally {
      _isInstallingPack = false;
      _installingPackId = null;
      notifyListeners();
    }
  }

  Future<void> resetCurrentPuzzle() async {
    if (_puzzles.isEmpty) return;

    _isLoading = true;
    _statusText = 'Loading puzzle...';
    notifyListeners();

    _resetPuzzlePosition();
    _lineUci = List<String>.from(currentPuzzle!.lineUci);
    _plyIndex = 0;

    _isLoading = false;
    _statusText = _progressStatus();
    notifyListeners();
  }

  Future<void> nextPuzzle() async {
    if (_puzzles.isEmpty) {
      _isAtEndOfList = true;
      _statusText = 'All puzzles solved. Reset progress to play again.';
      notifyListeners();
      return;
    }

    if (hasNextPuzzle) {
      _puzzleIndex++;
      _dialogShown = false;
      _isAtEndOfList = false;
      await resetCurrentPuzzle();
    } else {
      _isAtEndOfList = true;
      _dialogShown = false;
      notifyListeners();
    }
  }

  Future<void> onUserMove(dc.Move move, {bool? viaDragAndDrop}) async {
    if (_isLoading || _isPuzzleSolved || move is! dc.NormalMove) {
      return;
    }

    if (_plyIndex >= _lineUci.length) {
      _statusText = 'This puzzle line is already complete.';
      notifyListeners();
      return;
    }

    final expected = _lineUci[_plyIndex];
    if (move.uci != expected) {
      _statusText = 'Not the expected move in this line. Try again or use Hint.';
      _flashHint();
      notifyListeners();
      return;
    }

    if (!_applyUci(expected)) {
      _statusText = 'Could not apply move from puzzle line. Reset the puzzle.';
      notifyListeners();
      return;
    }

    _plyIndex++;
    _shapes = null;

    if (_plyIndex >= _lineUci.length) {
      _completePuzzle();
      notifyListeners();
      return;
    }

    _playForcedReplies();

    if (!_isPuzzleSolved) {
      _statusText = _progressStatus();
    }
    notifyListeners();
  }

  void showHint() {
    if (!canShowHint) return;

    final fromSquare = dc.Square.parse(_lineUci[_plyIndex].substring(0, 2));
    if (fromSquare == null) return;

    _shapes = ISet<Shape>({
      Circle(
        color: Colors.greenAccent,
        orig: fromSquare,
        scale: 0.85,
      ),
    });
    _statusText = 'Hint: move the piece from ${fromSquare.name.toUpperCase()}.';
    notifyListeners();
  }

  void markDialogShown() {
    _dialogShown = true;
  }

  void _playForcedReplies() {
    while (_plyIndex < _lineUci.length && _game.turn != _solverColor) {
      final reply = _lineUci[_plyIndex];
      if (!_applyUci(reply)) {
        _statusText = 'Invalid reply in puzzle line. Please reset this puzzle.';
        return;
      }
      _plyIndex++;

      if (_plyIndex >= _lineUci.length) {
        _completePuzzle();
        return;
      }
    }
  }

  void _completePuzzle() {
    _isPuzzleSolved = true;

    final id = currentPuzzle?.id;
    if (id != null && !_solvedPuzzleIds.contains(id)) {
      _solvedPuzzleIds.add(id);
      _saveProgress();
    }

    _statusText = _game.in_checkmate
        ? 'Perfect. That is checkmate.'
        : 'Line complete. Great solving.';
  }

  String _progressStatus() {
    final moves = currentPuzzle?.movesToSolve ?? 1;
    return 'Solve in $moves moves. Step $currentLineStep/$totalLinePly.';
  }

  bool _applyUci(String uci) {
    if (uci.length < 4) return false;

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length >= 5 ? uci.substring(4, 5) : null;

    final moved = _game.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    if (!moved) {
      return false;
    }

    final fromSquare = dc.Square.parse(from);
    final toSquare = dc.Square.parse(to);
    if (fromSquare != null && toSquare != null) {
      _lastMove = dc.NormalMove(from: fromSquare, to: toSquare, promotion: null);
    }
    return true;
  }

  void _flashHint() {
    showHint();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (_isPuzzleSolved) return;
      _shapes = null;
      notifyListeners();
    });
  }

  ValidMoves _buildValidMoves() {
    if (_game.turn != _solverColor || _isPuzzleSolved) {
      return IMap(<dc.Square, ISet<dc.Square>>{});
    }

    final moves = _game.moves({'asObjects': true}) as List<chess.Move>;
    final map = <dc.Square, Set<dc.Square>>{};

    for (final m in moves) {
      final from = dc.Square.parse(m.fromAlgebraic);
      final to = dc.Square.parse(m.toAlgebraic);
      if (from == null || to == null) continue;
      map.putIfAbsent(from, () => <dc.Square>{}).add(to);
    }

    return IMap(
      map.map((from, dests) => MapEntry(from, ISet<dc.Square>(dests))),
    );
  }

  void _resetPuzzlePosition() {
    if (_puzzleIndex >= _puzzles.length) {
      _isAtEndOfList = true;
      return;
    }

    final currentFen = _puzzles[_puzzleIndex].fen;
    _game = chess.Chess.fromFEN(currentFen);
    _solverColor = _game.turn;
    _isPuzzleSolved = false;
    _lastMove = null;
    _shapes = null;
  }

  Future<void> _reloadAllPuzzles({bool resetIndex = false}) async {
    final currentPuzzleId = currentPuzzle?.id;
    _allPuzzles = await _repository.loadAllPuzzles();
    _puzzles = _allPuzzles
        .where((puzzle) => !_solvedPuzzleIds.contains(puzzle.id))
        .toList();

    if (_puzzles.isEmpty) {
      _puzzleIndex = 0;
      _isAtEndOfList = true;
      return;
    }

    if (resetIndex || currentPuzzleId == null) {
      _puzzles.shuffle(_random);
      _puzzleIndex = 0;
    } else {
      final idx = _puzzles.indexWhere((p) => p.id == currentPuzzleId);
      _puzzleIndex = idx >= 0 ? idx : 0;
    }

    _isAtEndOfList = _puzzleIndex >= _puzzles.length - 1;
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> resetProgress() async {
    _solvedPuzzleIds = <int>{};
    await _saveProgress();

    _isLoading = true;
    _statusText = 'Progress reset. Reloading puzzles...';
    notifyListeners();

    await _reloadAllPuzzles(resetIndex: true);
    if (_puzzles.isEmpty) {
      _statusText = 'No puzzles found. Please check your puzzle data.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    await resetCurrentPuzzle();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_solvedIdsStorageKey) ?? <String>[];
    _solvedPuzzleIds = values.map(int.parse).toSet();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _solvedIdsStorageKey,
      _solvedPuzzleIds.map((id) => id.toString()).toList(),
    );
  }
}
