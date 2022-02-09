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

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Looks for deprecated `dart:` library references.
///
/// Run like so:
///
/// dart run example/deprecated_api_surveyor.dart <source dir>
void main(List<String> args) async {
  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  if (_debugLimit != 0) {
    print('Limiting analysis to $_debugLimit packages.');
  }

  var driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.showErrors = false;
  driver.resolveUnits = true;
  driver.visitor = DeprecatedReferenceCollector();

  await driver.analyze(displayTiming: true, requirePackagesFile: false);

  print('# deprecated references: $deprecatedReferenceCount');
  print('# compilation units: $compilationUnitCount');
  print('');
  reports.forEach(print);
}

var compilationUnitCount = 0;
var deprecatedReferenceCount = 0;

int dirCount = 0;

var reports = <String>[];

/// If non-zero, stops once limit is reached (for debugging).
int _debugLimit = 0; //500;

class DeprecatedReferenceCollector extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback, AstContext {
  int count = 0;
  int contexts = 0;
  String? filePath;
  Folder? currentFolder;
  LineInfo? lineInfo;

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    var debugLimit = _debugLimit;
    cmd.continueAnalyzing = debugLimit == 0 || count < debugLimit;
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool? subDir, DriverCommands? commandCallback}) {
    if (subDir ?? false) {
      ++dirCount;
    }
    var contextRoot = context.analysisContext.contextRoot;
    currentFolder = contextRoot.root;
    var dirName = path.basename(contextRoot.root.path);

    print("Analyzing '$dirName' • [${++count}/$dirCount]...");
  }

  @override
  void setFilePath(String filePath) {
    this.filePath = filePath;
  }

  @override
  void setLineInfo(LineInfo lineInfo) {
    this.lineInfo = lineInfo;
  }

  @override
  visitCompilationUnit(CompilationUnit node) {
    ++compilationUnitCount;
    super.visitCompilationUnit(node);
  }

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.staticElement;
    if (element == null) return;
    if (!_isDeprecated(element)) return;
    if (!_isInDartLib(element)) return;

    if (lineInfo != null) {
      var name = '';
      var parent = node.parent;
      if (parent is PrefixedIdentifier) {
        name = '${parent.prefix.name}.';
      }
      name += element.displayName;

      var location = lineInfo!.getLocation(node.offset);
      reports.add('$name: $filePath:${location.lineNumber}:${location.columnNumber}');
    }

    ++deprecatedReferenceCount;
  }

  static bool _isDeprecated(Element element) {
    if (element is PropertyAccessorElement && element.isSynthetic) {
      return element.variable.hasDeprecated;
    }
    return element.hasDeprecated;
  }

  static bool _isInDartLib(Element element) {
    var name = element.library?.name;
    return name != null && name.startsWith('dart.');
  }
}
