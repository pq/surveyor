//  Copyright 2019 Google LLC
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
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Looks for a few specific API uses.
///
/// Run like so:
///
/// dart run example/api_surveyor.dart <source dir>
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

  var stopwatch = Stopwatch()..start();

  var driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.showErrors = false;
  driver.resolveUnits = true;
  driver.visitor = ApiUseCollector();

  await driver.analyze();

  print(
      '(Elapsed time: ${Duration(milliseconds: stopwatch.elapsedMilliseconds)})');
}

int dirCount = 0;

/// If non-zero, stops once limit is reached (for debugging).
int _debugLimit = 0; //500;

class ApiUseCollector extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback, AstContext {
  int count = 0;
  int contexts = 0;
  String? filePath;
  Folder? currentFolder;
  LineInfo? lineInfo;

  List<String> reports = <String>[];

  ApiUseCollector();

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    var debugLimit = _debugLimit;
    cmd.continueAnalyzing = debugLimit == 0 || count < debugLimit;
    // Reporting done in visitSimpleIdentifier.
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
  void visitMethodInvocation(MethodInvocation node) {
    var lineInfo = this.lineInfo;
    if (lineInfo == null) return;

    CharacterLocation? location;
    var name = node.methodName.name;
    if (name == 'transform' || name == 'pipe') {
      var type = node.realTarget?.staticType?.element?.name;
      if (type == 'Stream') {
        location = lineInfo.getLocation(node.offset);
      }
    } else if (name == 'close') {
      var type = node.realTarget?.staticType?.element?.name;
      if (type == 'HttpClientRequest') {
        location = lineInfo.getLocation(node.offset);
      }
    }

    if (location != null) {
      print(
          '${node.staticType?.element?.name}.$name: $filePath:${location.lineNumber}:${location.columnNumber}');
    }

    super.visitMethodInvocation(node);
  }
}
