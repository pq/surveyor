import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:surveyor/src/common.dart';

main(List<String> args) async {
  final dir = args[0];

  var count = 0;
  final dart2 = VersionConstraint.parse('>=2.0.0');

  final packages = Directory(dir).listSync().toList();
  for (var package in packages) {
    try {
      final pubspec = PubspecFile('${package.path}/pubspec.yaml');
      final yaml = pubspec.yaml;
      final sdkVersion = yaml['environment']['sdk'];
      final constraint = VersionConstraint.parse(sdkVersion);

      if (!constraint.allowsAny(dart2)) {
        print('removing: $package ($sdkVersion)');
        await package.delete(recursive: true);
        ++count;
      }
    } catch (_) {
      // Ignore.
    }
  }

  print('Removed: $count packages.');
}
