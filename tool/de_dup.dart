import 'dart:io';

/// Find and delete duplicate packages in a directory.
main(List<String> args) async {
  final dir = args[0];

  final seen = <String, String>{};

  final packages = Directory(dir).listSync().map((f) => f.path).toList()
    ..sort();
  for (var package in packages) {
    // cache/flutter_util-0.0.1 => flutter_util
    var name = package.split('/').last.split('-').first;
    var previous = seen[name];
    if (previous != null) {
      print('deleting $previous, favoring $package');
      Directory(previous).deleteSync(recursive: true);
    }
    seen[name] = package;
  }
}
