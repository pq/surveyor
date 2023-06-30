//  Copyright 2022 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Collects data about core library use.
///
/// Run like so:
///
///     dart run example/core_lib_use_surveyor.dart <source dir>
void main(List<String> args) async {
  if (args.length == 1) {
    var arg = args[0];
    if (arg.endsWith('.json')) {
      print("Parsing occurrence data in '$arg'...");
      var occurrences = Occurrences.fromFile(arg);
      displayOccurrences(occurrences);
      return;
    }
  }

  if (_debugLimit != 0) {
    print('Limiting analysis to $_debugLimit packages.');
  }

  await survey(args, displayTiming: true);
  displayOccurrences(occurrences);

  var file = 'example/core_lib_use_surveyor/occurrences.json';
  print('Writing occurrence data to $file');
  occurrences.toFile(file);
}

int dirCount = 0;

var occurrences = Occurrences();

/// If non-zero, stops once limit is reached (for debugging).
int _debugLimit = 10; //500;

void displayOccurrences(Occurrences occurrences) {
  print(occurrences.data);
}

Future<Occurrences> survey(List<String> args,
    {bool displayTiming = false}) async {
  if (args.length == 1) {
    var dir = args[0];

    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  var driver = Driver.forArgs(args)..visitor = LibraryUseCollector();
  await driver.analyze(displayTiming: displayTiming);

  return occurrences;
}

class LibraryUseCollector extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback {
  int count = 0;
  late String dirName;

  void add({required String? library, required String symbol}) {
    occurrences.add(dirName, library: library!, symbol: symbol);
  }

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    cmd.continueAnalyzing = _debugLimit == 0 || count < _debugLimit;
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool? subDir, DriverCommands? commandCallback}) {
    if (subDir ?? false) {
      ++dirCount;
    }
    var contextRoot = context.analysisContext.contextRoot;
    dirName = path.basename(contextRoot.root.path);

    print("Analyzing '$dirName' • [${++count}/$dirCount]...");

    occurrences.init(dirName);
  }

  void visitMethod(MethodInvocation node) {
    var libraryName = node.methodName.staticElement?.library?.name;
    if (libraryName?.startsWith('dart.') ?? false) {
      var typeName = node.realTarget?.staticType?.element?.name;
      var id = typeName ?? node.methodName.name;
      occurrences.add(dirName, library: libraryName!, symbol: id);
    }
  }

  void visitProperty(PropertyAccessorElement element) {
    var libraryName = element.library.name;
    if (libraryName.startsWith('dart.')) {
      if (element.variable is TopLevelVariableElement) {
        add(library: libraryName, symbol: element.name);
      }
    }
  }

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    var parent = node.parent;
    if (parent is MethodInvocation) {
      visitMethod(parent);
    } else if (parent is NamedType) {
      visitTypeElement(parent.element);
    } else if (parent is PrefixedIdentifier) {
      var element = node.staticElement;
      if (element is ClassElement) {
        visitTypeElement(element);
      }
    } else {
      var element = node.staticElement;
      if (element is PropertyAccessorElement) {
        visitProperty(element);
      }
    }
    return super.visitSimpleIdentifier(node);
  }

  void visitType(NamedType type) {
    var element = type.element;
    if (element == null) return;
    var typeName = element.name;
    if (typeName == null) return;
    var libraryName = element.library?.name;
    if (libraryName?.startsWith('dart.') ?? false) {
      add(library: libraryName, symbol: typeName);
    }
  }

  void visitTypeElement(Element? element) {
    if (element == null) return;

    var typeName = element.name;
    if (typeName == null) return;

    var libraryName = element.library?.name;
    if (libraryName?.startsWith('dart.') ?? false) {
      add(library: libraryName, symbol: typeName);
    }
  }
}

class Occurrences {
  final Map<String, Map<String, List<String>>> data = {};

  Occurrences();

  factory Occurrences.fromFile(String path) =>
      Occurrences.fromJson(File(path).readAsStringSync());

  Occurrences.fromJson(String json) {
    Map<String, dynamic> decoded = jsonDecode(json);
    for (var e in decoded.entries) {
      var entries = (e.value as Map).map((key, value) => MapEntry(
          key as String, (value as List).map((e) => e as String).toList()));
      data[e.key] = entries;
    }
  }

  void add(String package, {required String library, required String symbol}) {
    data[package]!.update(library, (symbols) => symbols..addIfAbsent(symbol),
        ifAbsent: () => [symbol]);
  }

  void init(String package) {
    data[package] = {};
  }

  File toFile(String path) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(toJson());

  String toJson() => JsonEncoder.withIndent('  ').convert(data);
}

extension on List<String> {
  void addIfAbsent(String value) {
    if (!contains(value)) add(value);
  }
}
