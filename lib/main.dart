import 'dart:convert';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'game_service.dart';

/// Represents a single chess puzzle from the puzzles.json file.
class Puzzle {
  final int id;
  final String name;
  final String fen;
  final String solution;
  final String difficulty;

  Puzzle({
    required this.id,
    required this.name,
    required this.fen,
    required this.solution,
    required this.difficulty,
  });

  /// Factory constructor to create a Puzzle from JSON
  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as int,
      name: json['name'] as String,
      fen: json['fen'] as String,
      solution: json['solution'] as String,
      difficulty: json['difficulty'] as String,
    );
  }
}

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
      ),
      body: Consumer<PuzzleController>(
        builder: (context, vm, _) {
          // Show success dialog when puzzle is solved
          if (vm.isPuzzleSolved && !vm._dialogShown) {
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
                  Text(
                    vm.statusText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final boardSize = math.min(
                constraints.maxWidth - 24,
                constraints.maxHeight - 220,
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
                          if (vm.currentPuzzle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                vm.currentPuzzle!.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700],
                                    ),
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
                      children: [
                        FilledButton.icon(
                          onPressed: vm.showHint,
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

  void _showSuccessDialog(BuildContext context, PuzzleController vm) {
    if (vm._dialogShown) return;
    vm._markDialogShown();

    // Check if at end of list
    if (vm._isAtEndOfList || !vm.hasNextPuzzle) {
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
          content: const Text('Checkmate! You found the solution.'),
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

class PuzzleController extends ChangeNotifier {
  PuzzleController({GameService? gameService})
    : _gameService = gameService ?? GameService();

  final GameService _gameService;
  late chess.Chess _game;

  List<Puzzle> _puzzles = [];
  int _puzzleIndex = 0;
  bool _dialogShown = false;
  bool _isAtEndOfList = false;
  String? _bestMove;
  bool _isLoading = true;
  bool _isPuzzleSolved = false;
  String _statusText = 'Loading puzzles...';
  ISet<Shape>? _shapes;
  dc.NormalMove? _lastMove;

  bool get isLoading => _isLoading;
  bool get isPuzzleSolved => _isPuzzleSolved;
  bool get isInCheck => _game.in_check;
  String get statusText => _statusText;
  String get fen => _game.fen;
  ISet<Shape>? get shapes => _shapes;
  dc.NormalMove? get lastMove => _lastMove;
  int get currentPuzzleNumber => _puzzleIndex + 1;
  int get totalPuzzles => _puzzles.length;
  bool get hasNextPuzzle => _puzzleIndex < _puzzles.length - 1;
  Puzzle? get currentPuzzle => _puzzleIndex < _puzzles.length ? _puzzles[_puzzleIndex] : null;

  dc.Side get sideToMove =>
      _game.turn == chess.Color.WHITE ? dc.Side.white : dc.Side.black;

  PlayerSide get playerSide {
    if (_isPuzzleSolved) return PlayerSide.none;
    return _game.turn == chess.Color.WHITE ? PlayerSide.white : PlayerSide.none;
  }

  ValidMoves get validMoves => _buildValidMoves();

  /// Load puzzles from the assets/puzzles.json file
  Future<List<Puzzle>> loadPuzzles() async {
    try {
      final jsonString = await rootBundle.loadString('assets/puzzles.json');
      final jsonList = json.decode(jsonString) as List<dynamic>;
      _puzzles = jsonList
          .map((item) => Puzzle.fromJson(item as Map<String, dynamic>))
          .toList();
      return _puzzles;
    } catch (e) {
      debugPrint('Error loading puzzles: $e');
      _statusText = 'Error loading puzzles. Please restart.';
      notifyListeners();
      return [];
    }
  }

  /// Mark the success dialog as shown to prevent multiple dialogs
  void _markDialogShown() {
    _dialogShown = true;
  }

  /// Reset only the current puzzle without changing the puzzle index
  Future<void> resetCurrentPuzzle() async {
    _isLoading = true;
    _statusText = 'Loading puzzle...';
    _resetPuzzlePosition();
    notifyListeners();

    await _gameService.init();
    _bestMove = await _gameService.findBestMove(_game.fen, movetime: 400);

    _isLoading = false;
    final puzzleName = currentPuzzle?.name ?? 'Puzzle';
    _statusText = 'White to move. Find the checkmate in one.';
    notifyListeners();
  }

  /// Move to the next puzzle in the loaded list
  Future<void> nextPuzzle() async {
    if (hasNextPuzzle) {
      _puzzleIndex++;
      _dialogShown = false;
      _isAtEndOfList = false;
      await resetCurrentPuzzle();
    } else {
      // At the end of the list
      _isAtEndOfList = true;
      _dialogShown = false;
      notifyListeners();
    }
  }

  /// Initialize the app with the first puzzle from loaded list
  Future<void> initialize() async {
    _isLoading = true;
    _statusText = 'Loading puzzles...';
    _puzzleIndex = 0;
    _dialogShown = false;
    _isAtEndOfList = false;
    notifyListeners();

    // Load puzzles from JSON
    await loadPuzzles();

    if (_puzzles.isEmpty) {
      _statusText = 'No puzzles found. Please check assets/puzzles.json';
      _isLoading = false;
      notifyListeners();
      return;
    }

    await resetCurrentPuzzle();
  }

  Future<void> onUserMove(dc.Move move, {bool? viaDragAndDrop}) async {
    if (_isLoading || _isPuzzleSolved || move is! dc.NormalMove) {
      return;
    }

    final expectedMove =
        _bestMove ?? await _gameService.findBestMove(_game.fen, movetime: 400);
    _bestMove = expectedMove;

    if (expectedMove == null) {
      _statusText = 'Engine could not evaluate this position. Try reset.';
      notifyListeners();
      return;
    }

    if (move.uci != expectedMove) {
      _statusText = 'Not the best move. Try again or press Hint.';
      _flashHint();
      notifyListeners();
      return;
    }

    final moved = _game.move({
      'from': move.from.name,
      'to': move.to.name,
      if (move.promotion != null) 'promotion': move.promotion!.letter,
    });

    if (!moved) {
      _statusText = 'Illegal move in this position. Try another move.';
      notifyListeners();
      return;
    }

    _lastMove = dc.NormalMove(
      from: move.from,
      to: move.to,
      promotion: move.promotion,
    );
    _shapes = null;

    if (_game.in_checkmate) {
      _isPuzzleSolved = true;
      _statusText = 'Perfect. That is checkmate.';
    } else {
      _statusText = 'Best move found, but this puzzle expects mate in one.';
    }
    notifyListeners();
  }

  void showHint() {
    if (_bestMove == null) return;

    final fromSquare = dc.Square.parse(_bestMove!.substring(0, 2));
    if (fromSquare == null) return;

    _shapes = ISet<Shape>({
      Circle(
        color: Colors.greenAccent,
        orig: fromSquare,
        scale: 0.85,
      ),
    });
    _statusText =
        'Hint: move the piece from ${fromSquare.name.toUpperCase()}.';
    notifyListeners();
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

  /// Reset to the current puzzle's starting position from loaded list
  void _resetPuzzlePosition() {
    if (_puzzleIndex >= _puzzles.length) {
      _isAtEndOfList = true;
      return;
    }
    
    final currentFen = _puzzles[_puzzleIndex].fen;
    _game = chess.Chess.fromFEN(currentFen);
    _isPuzzleSolved = false;
    _bestMove = null;
    _lastMove = null;
    _shapes = null;
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }
}
