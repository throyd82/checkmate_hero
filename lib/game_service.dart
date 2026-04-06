import 'dart:async';

import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';

/// Service that wraps Stockfish UCI communication.
class GameService {
  Stockfish? _engine;
  StreamSubscription<String>? _stderrSub;
  bool _initialized = false;

  // Serialize UCI command blocks so we never have overlapping reads on stdout.
  Future<void> _uciQueue = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _uciQueue = _uciQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Stockfish> _ensureEngine() async {
    _engine ??= await stockfishAsync();
    _stderrSub ??= _engine!.stderr.listen((_) {});
    return _engine!;
  }

  Future<void> init() {
    return _enqueue(_initInternal);
  }

  Future<void> _initInternal() async {
    if (_initialized) return;

    final engine = await _ensureEngine();

    final uciOk = _waitForLine(engine, (line) => line.trim() == 'uciok');
    engine.stdin = 'uci';
    await uciOk;

    await _sendIsReady(engine);
    _initialized = true;
  }

  Future<String?> findBestMove(String fen, {int movetime = 400}) {
    return _enqueue(() async {
      await _initInternal();
      final engine = await _ensureEngine();

      engine.stdin = 'ucinewgame';

      // UCI 'isready': after state-changing commands, wait for 'readyok'
      // so the engine has fully applied changes before we continue.
      await _sendIsReady(engine);

      engine.stdin = 'position fen $fen';

      final bestMoveLine = _waitForLine(
        engine,
        (line) => line.startsWith('bestmove '),
      );

      // UCI 'go': starts the search. Using movetime keeps puzzle checks fast
      // and deterministic by capping how long Stockfish thinks.
      engine.stdin = 'go movetime $movetime';

      final line = await bestMoveLine;
      final parts = line.split(' ');
      if (parts.length < 2 || parts[1] == '(none)') {
        return null;
      }
      return parts[1];
    });
  }

  Future<void> _sendIsReady(Stockfish engine) async {
    final readyFuture = _waitForLine(engine, (line) => line.trim() == 'readyok');
    engine.stdin = 'isready';
    await readyFuture;
  }

  Future<String> _waitForLine(
    Stockfish engine,
    bool Function(String line) predicate,
  ) async {
    final completer = Completer<String>();
    late final StreamSubscription<String> sub;
    sub = engine.stdout.listen((line) {
      if (!completer.isCompleted && predicate(line)) {
        completer.complete(line);
      }
    });

    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      await sub.cancel();
    }
  }

  void dispose() {
    _stderrSub?.cancel();
    _stderrSub = null;
    _engine?.dispose();
    _engine = null;
    _initialized = false;
  }
}
