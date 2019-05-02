import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';


final _client = http.Client();

Future<String> getBody(String url) async => (await getResponse(url)).body;

Future<http.Response> getResponse(String url) async => _client.get(url);

int toInt(Object value) {
  if (value is int) {
    return value;
  }
  try {
    return int.parse(value);
  } on FormatException catch (e) {
    print('expected int value but got "$value": ${e.message}');
    rethrow;
  }
}

double toDouble(Object value) {
  if (value is double) {
    return value;
  }
  try {
    return double.parse(value);
  } on FormatException catch (e) {
    print('expected double value but got "$value": ${e.message}');
    rethrow;
  }
}


class AnalysisOptionsFile {
  final File file;

  /// Can throw a [FormatException] if yaml is malformed.
  YamlMap get yaml => _yaml ??= _readYamlFromString(contents);

  String get contents => _contents ??= file.readAsStringSync();
  String _contents;

  YamlMap _yaml;

  AnalysisOptionsFile(String path) : file = File(path);
}



class PubspecFile {
  final File file;

  /// Can throw a [FormatException] if yaml is malformed.
  YamlMap get yaml => _yaml ??= _readYamlFromString(contents);

  String get contents => _contents ??= file.readAsStringSync();
  String _contents;

  YamlMap _yaml;

  PubspecFile(String path) : file = File(path);
}

YamlMap _readYamlFromString(String optionsSource) {
  if (optionsSource == null) {
    return new YamlMap();
  }
  try {
    YamlNode doc = loadYamlNode(optionsSource);
    if (doc is YamlMap) {
      return doc;
    }
    return new YamlMap();
  } on YamlException catch (e) {
    throw new FormatException(e.message, e.span);
  } catch (e) {
    throw new FormatException('Unable to parse YAML document.');
  }
}

class CommandLineOptions {
  /// Emit output in a verbose mode.
  final bool verbose;

  /// Use ANSI color codes for output.
  final bool color;

  /// Force installation of package dependencies.
  final bool forceInstall;

  CommandLineOptions({this.verbose = false, this.color = false, this.forceInstall = false});

  CommandLineOptions.fromArgs(ArgResults args)
      : this(verbose: args['verbose'], color: args['color'], forceInstall: args['force-install']);
}
