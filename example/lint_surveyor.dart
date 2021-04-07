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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisErrorInfoImpl;
import 'package:analyzer/src/lint/linter.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/analysis.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Lints specified projects with a defined set of lints.
///
/// Run like so:
///
/// dart run example/lint_surveyor.dart <source dir>
void main(List<String> args) async {
  var stopwatch = Stopwatch()..start();

  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");

      args = Directory(dir)
          .listSync()
          .where(
              (f) => !path.basename(f.path).startsWith('.') && f is Directory)
          .map((f) => f.path)
          .toList()
            ..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  if (_debuglimit != null) {
    print('Limiting analysis to $_debuglimit packages.');
  }

  var driver = Driver.forArgs(args);
  driver.visitor = AnalysisAdvisor();
  driver.showErrors = true;

  driver.lints = [
    // Add a custom rule.
    CustomLint(),
    // And/or specify ones defined in the linter.
    // CamelCaseTypes(),
  ];

  await driver.analyze();

  print(
      '(Elapsed time: ${Duration(milliseconds: stopwatch.elapsedMilliseconds)})');
}

int dirCount = 0;

/// If non-null, stops once limit is reached (for debugging).
int? _debuglimit; // = 300;

class AnalysisAdvisor extends SimpleAstVisitor
    implements
        PreAnalysisCallback,
        PostAnalysisCallback,
        PostVisitCallback,
        ErrorReporter {
  int count = 0;

  AnalysisStats stats;
  late HumanErrorFormatter formatter;

  AnalysisAdvisor() : stats = AnalysisStats() {
    formatter = HumanErrorFormatter(stdout, stats);
  }

  @override
  void onVisitFinished() {
    stats.print();
  }

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    var debugLimit = _debuglimit;
    cmd.continueAnalyzing = debugLimit == null || count < debugLimit;
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool? subDir, DriverCommands? commandCallback}) {
    subDir ??= false;
    if (subDir) {
      ++dirCount;
    }
    var root = context.analysisContext.contextRoot.root;
    var dirName = path.basename(root.path);
    if (subDir) {
      // Qualify.
      dirName = '${path.basename(root.parent2.path)}/$dirName';
    }
    print("Analyzing '$dirName' • [${++count}/$dirCount]...");
  }

  @override
  void reportError(AnalysisResultWithErrors result) {
    var errors = result.errors.where(showError).toList();
    if (errors.isEmpty) {
      return;
    }
    formatter.formatErrors([AnalysisErrorInfoImpl(errors, result.lineInfo)]);
    formatter.flush();
  }

  //Only show lints.
  bool showError(AnalysisError error) => error.errorCode.type == ErrorType.LINT;
}

/// Sample content.  Replace w/ custom logic.
class CustomLint extends LintRule implements NodeLintRule {
  static const _desc = r'Avoid `print` calls in production code.';
  static const _details = r'''
**DO** avoid `print` calls in production code.

**BAD:**
```
void f(int x) {
  print('debug: $x');
  ...
}
```
''';
  CustomLint()
      : super(
            name: 'avoid_print',
            description: _desc,
            details: _details,
            group: Group.errors);

  @override
  void registerNodeProcessors(
      NodeLintRegistry registry, LinterContext context) {
    var visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor {
  final LintRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    bool isDartCore(MethodInvocation node) =>
        node.methodName.staticElement?.library?.name == 'dart.core';

    if (node.methodName.name == 'print' && isDartCore(node)) {
      rule.reportLint(node.methodName);
    }
  }
}
