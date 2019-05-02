

import 'dart:io';


import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;


class _Installer {

  Future<ProcessResult> installDependencies(Package package) async {
    final sourcePath = package.dir.path;
    if (!package.dir.existsSync()) {
      print(
          'Unable to install dependencies: $sourcePath does not exist');
      return null;
    }

    if (package.dependencies?.containsKey('flutter') == true) {
      print('Running "flutter packages get" in ${path.basename(sourcePath)}');
      return Process.run('flutter', ['packages', 'get'],
          workingDirectory: sourcePath);
    }

    //TODO: recurse and run pub get in example dirs.
    print('Running "pub get" in ${path.basename(sourcePath)}');
    return Process.run('pub', ['get'], workingDirectory: sourcePath);
  }

  bool hasDependenciesInstalled(Package package) {
    var sourceDir = package.dir;
    return sourceDir.existsSync() &&
        File('${sourceDir.path}/.packages').existsSync();
  }

}


class Package {
  static final _Installer _installer = _Installer();

  final Directory dir;
  Package(String path) : dir = Directory(path);

  Future<bool> installDependencies({bool force : false}) async {
    if (!force && _installer.hasDependenciesInstalled(this)) {
      return false;
    }

    await _installer.installDependencies(this);
    return true;
  }
  
  @override
  Map<dynamic, yaml.YamlNode> get pubspec {
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      try {
        return (yaml.loadYaml(pubspecFile.readAsStringSync()) as yaml.YamlMap)
            .nodes;
      } on yaml.YamlException {
        // Warn?
      }
    }
    return <dynamic, yaml.YamlNode>{};
  }

  Map<String, dynamic> get dependencies {
    final deps = pubspec['dependencies']?.value;
    if (deps is yaml.YamlMap) {
      return deps.nodes
          .map((k, v) => MapEntry<String, dynamic>(k.toString(), v));
    }
    return {};
  }
}


