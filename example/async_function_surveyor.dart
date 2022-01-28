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
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:path/path.dart' as path;
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Collects data about async functions.
///
/// Run like so:
///
///     dart run example/async_function_surveyor.dart <source dir>
void main(List<String> args) async {
  if (_debugLimit != 0) {
    print('Limiting analysis to $_debugLimit packages.');
  }

  await survey(args);
}

int dirCount = 0;

/// If non-zero, stops once limit is reached (for debugging).
int _debugLimit = 0; //500;

Future<void> survey(List<String> args, {bool displayTiming = false}) async {
  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  var driver = Driver.forArgs(args)..visitor = AsyncFunctionSurveyor();
  await driver.analyze(displayTiming: displayTiming);
}

class AsyncFunctionSurveyor extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback {
  int count = 0;
  String? filePath;
  Folder? currentFolder;

  AsyncFunctionSurveyor();

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
  visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.declaredElement?.isAsynchronous ?? false) {
      var counter = AwaitCollector();
      node.accept(counter);
      print('${node.name}: ${counter.count}');
    }
  }
}

class AwaitCollector extends RecursiveAstVisitor {
  var count = 0;

  @override
  visitAwaitExpression(AwaitExpression node) {
    ++count;
    return super.visitAwaitExpression(node);
  }
}
