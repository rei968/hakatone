import 'dart:io';

/// Finds a file under database/ whether the server runs from backend/ or from the repo root.
File findDatabaseFile(String relativePath) {
  const roots = ['database', 'backend/database'];
  for (final root in roots) {
    final file = File('$root/$relativePath');
    if (file.existsSync()) return file;
  }
  throw StateError('$relativePath not found under $roots (cwd: ${Directory.current.path})');
}
