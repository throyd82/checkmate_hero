import 'dart:convert';

import 'package:flutter/services.dart';

import 'pack_service.dart';
import 'puzzle_models.dart';

class PuzzleRepository {
  PuzzleRepository({PackService? packService, String? packIndexUrl})
      : _packService =
            packService ??
            PackService(
              packIndexUrl: packIndexUrl ??
                  const String.fromEnvironment('CHECKMATE_PACK_INDEX'),
            );

  final PackService _packService;

  Future<List<Puzzle>> loadAllPuzzles() async {
    final corePuzzles = await _loadCorePuzzles();
    final installedPackPuzzles = await _packService.loadInstalledPackPuzzles();
    return <Puzzle>[...corePuzzles, ...installedPackPuzzles];
  }

  Future<List<PackIndexItem>> fetchAvailablePacks() {
    return _packService.fetchAvailablePacks();
  }

  Future<List<InstalledPack>> listInstalledPacks() {
    return _packService.listInstalledPacks();
  }

  Future<void> installPack(PackIndexItem pack) {
    return _packService.installPack(pack);
  }

  Future<void> removePack(String packId) {
    return _packService.removePack(packId);
  }

  Future<List<Puzzle>> _loadCorePuzzles() async {
    final jsonString = await rootBundle.loadString('assets/puzzles.json');
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((item) => Puzzle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void dispose() {
    _packService.dispose();
  }
}
