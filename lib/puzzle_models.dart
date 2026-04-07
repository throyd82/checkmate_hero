enum PuzzleMode { line }

class Puzzle {
  final int id;
  final String name;
  final String fen;
  final String difficulty;
  final PuzzleMode mode;
  final int movesToSolve;
  final List<String> lineUci;
  final String packId;

  const Puzzle({
    required this.id,
    required this.name,
    required this.fen,
    required this.difficulty,
    required this.mode,
    required this.movesToSolve,
    required this.lineUci,
    required this.packId,
  });

  factory Puzzle.fromJson(
    Map<String, dynamic> json, {
    String packId = 'core',
  }) {
    final line =
        (json['lineUci'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
    final legacySolutionUci = json['solutionUci']?.toString();
    final solvedLine =
        line ??
        (legacySolutionUci != null && legacySolutionUci.isNotEmpty
            ? <String>[legacySolutionUci]
            : <String>[]);

    if (solvedLine.isEmpty) {
      throw FormatException('Puzzle ${json['id']} has no lineUci/solutionUci');
    }

    final modeRaw = json['mode']?.toString() ?? 'line';
    final mode = modeRaw == 'line' ? PuzzleMode.line : PuzzleMode.line;
    final movesToSolve =
        json['movesToSolve'] as int? ?? ((solvedLine.length + 1) ~/ 2);

    return Puzzle(
      id: json['id'] as int,
      name: json['name'] as String,
      fen: json['fen'] as String,
      difficulty: json['difficulty'] as String? ?? 'Beginner',
      mode: mode,
      movesToSolve: movesToSolve,
      lineUci: solvedLine,
      packId: json['packId'] as String? ?? packId,
    );
  }
}

class PackIndexItem {
  final String id;
  final String name;
  final String version;
  final int puzzleCount;
  final String url;
  final String sha256;

  const PackIndexItem({
    required this.id,
    required this.name,
    required this.version,
    required this.puzzleCount,
    required this.url,
    required this.sha256,
  });

  factory PackIndexItem.fromJson(Map<String, dynamic> json) {
    return PackIndexItem(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      puzzleCount: json['puzzleCount'] as int,
      url: json['url'] as String,
      sha256: json['sha256'] as String,
    );
  }
}

class InstalledPack {
  final String id;
  final String name;
  final String version;
  final int puzzleCount;

  const InstalledPack({
    required this.id,
    required this.name,
    required this.version,
    required this.puzzleCount,
  });

  factory InstalledPack.fromJson(Map<String, dynamic> json) {
    return InstalledPack(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      puzzleCount: json['puzzleCount'] as int,
    );
  }
}
