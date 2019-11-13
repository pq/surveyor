import 'dart:io';
import 'package:path/path.dart' as pathutil;
import 'package:yaml/yaml.dart' as yaml;

class Package {
  static final _Installer _installer = _Installer();

  final Directory dir;
  Package(String path) : dir = Directory(path);

  Map<String, dynamic> get dependencies {
    final deps = pubspec['dependencies']?.value;
    if (deps is yaml.YamlMap) {
      return deps.nodes
          .map((k, v) => MapEntry<String, dynamic>(k.toString(), v));
    }
    return {};
  }

  File get packagesFile => File(pathutil.join(dir.path, '.packages'));

  Map<dynamic, yaml.YamlNode> get pubspec {
    final file = pubspecFile;
    if (file.existsSync()) {
      try {
        return (yaml.loadYaml(file.readAsStringSync()) as yaml.YamlMap).nodes;
      } on yaml.YamlException {
        // Warn?
      }
    }
    return <dynamic, yaml.YamlNode>{};
  }

  File get pubspecFile => File(pathutil.join(dir.path, 'pubspec.yaml'));

  Future<bool> installDependencies({bool force = false}) async {
    if (!force && _installer.hasDependenciesInstalled(this)) {
      return false;
    }

    await _installer.installDependencies(this);
    return true;
  }
}

class _Installer {
  bool hasDependenciesInstalled(Package package) =>
      package.dir.existsSync() && package.packagesFile.existsSync();

  Future<ProcessResult> installDependencies(Package package) async {
    final sourcePath = package.dir.path;
    if (!package.dir.existsSync()) {
      print('Unable to install dependencies: $sourcePath does not exist');
      return null;
    }
    if (!package.pubspecFile.existsSync()) {
      return null;
    }

    if (package.dependencies?.containsKey('flutter') == true) {
      print(
          'Running "flutter packages get" in ${pathutil.basename(sourcePath)}');
      return Process.run('flutter', ['packages', 'get'],
          workingDirectory: sourcePath, runInShell: true);
    }

    print('Running "pub get" in ${pathutil.basename(sourcePath)}');
    return Process.run('pub', ['get'],
        workingDirectory: sourcePath, runInShell: true);
  }
}
