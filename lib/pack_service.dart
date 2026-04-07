import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'puzzle_models.dart';

class PackService {
  PackService({
    http.Client? client,
    this.packIndexUrl,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? packIndexUrl;

  Future<List<PackIndexItem>> fetchAvailablePacks() async {
    if (packIndexUrl == null || packIndexUrl!.isEmpty) {
      return <PackIndexItem>[];
    }

    final uri = Uri.parse(packIndexUrl!);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'Failed to fetch pack index: HTTP ${response.statusCode}',
      );
    }

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (parsed['packs'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return items.map(PackIndexItem.fromJson).toList();
  }

  Future<List<InstalledPack>> listInstalledPacks() async {
    final root = await _packsRoot();
    if (!await root.exists()) {
      return <InstalledPack>[];
    }

    final packs = <InstalledPack>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File('${entity.path}${Platform.pathSeparator}manifest.json');
      if (!await manifestFile.exists()) continue;
      try {
        final jsonMap = jsonDecode(await manifestFile.readAsString())
            as Map<String, dynamic>;
        packs.add(InstalledPack.fromJson(jsonMap));
      } catch (_) {
        // Ignore malformed pack folders.
      }
    }

    return packs;
  }

  Future<List<Puzzle>> loadInstalledPackPuzzles() async {
    final root = await _packsRoot();
    if (!await root.exists()) {
      return <Puzzle>[];
    }

    final puzzles = <Puzzle>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File('${entity.path}${Platform.pathSeparator}manifest.json');
      final puzzleFile = File('${entity.path}${Platform.pathSeparator}puzzles.json');
      if (!await manifestFile.exists() || !await puzzleFile.exists()) continue;

      try {
        final manifest = jsonDecode(await manifestFile.readAsString())
            as Map<String, dynamic>;
        final packId = manifest['id'] as String? ?? 'unknown-pack';
        final data = jsonDecode(await puzzleFile.readAsString()) as List<dynamic>;
        for (final item in data) {
          puzzles.add(Puzzle.fromJson(item as Map<String, dynamic>, packId: packId));
        }
      } catch (_) {
        // Skip malformed packs.
      }
    }

    return puzzles;
  }

  Future<void> installPack(PackIndexItem pack) async {
    final response = await _client.get(Uri.parse(pack.url));
    if (response.statusCode != 200) {
      throw StateError('Failed to download pack: HTTP ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    final digest = sha256.convert(bytes).toString();
    if (digest.toLowerCase() != pack.sha256.toLowerCase()) {
      throw StateError('Pack checksum mismatch for ${pack.id}');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final root = await _packsRoot();
    await root.create(recursive: true);

    final tempDir = Directory(
      '${root.path}${Platform.pathSeparator}.${pack.id}.tmp',
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    for (final file in archive.files) {
      final outPath = '${tempDir.path}${Platform.pathSeparator}${file.name}';
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    final manifestFile = File('${tempDir.path}${Platform.pathSeparator}manifest.json');
    final puzzlesFile = File('${tempDir.path}${Platform.pathSeparator}puzzles.json');
    if (!await manifestFile.exists() || !await puzzlesFile.exists()) {
      await tempDir.delete(recursive: true);
      throw StateError('Pack ${pack.id} missing manifest.json or puzzles.json');
    }

    final finalDir = Directory('${root.path}${Platform.pathSeparator}${pack.id}');
    if (await finalDir.exists()) {
      await finalDir.delete(recursive: true);
    }
    await tempDir.rename(finalDir.path);
  }

  Future<void> removePack(String packId) async {
    final root = await _packsRoot();
    final dir = Directory('${root.path}${Platform.pathSeparator}$packId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<Directory> _packsRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory('${docsDir.path}${Platform.pathSeparator}packs');
  }

  void dispose() {
    _client.close();
  }
}
