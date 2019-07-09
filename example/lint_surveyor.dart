import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
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
/// dart example/lint_surveyor.dart <source dir>
main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  if (args.length == 1) {
    final dir = args[0];
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

  final driver = Driver.forArgs(args);
  driver.visitor = AnalysisAdvisor();
  driver.showErrors = true;

  driver.lints = [CustomLint()];

  await driver.analyze();

  print(
      '(Elapsed time: ${Duration(milliseconds: stopwatch.elapsedMilliseconds)})');
}

int dirCount;

/// If non-null, stops once limit is reached (for debugging).
int _debuglimit; // = 300;

class AnalysisAdvisor extends SimpleAstVisitor
    implements
        PreAnalysisCallback,
        PostAnalysisCallback,
        PostVisitCallback,
        ErrorReporter {
  int count = 0;

  AnalysisStats stats;
  HumanErrorFormatter formatter;

  AnalysisAdvisor() {
    stats = AnalysisStats();
    formatter = HumanErrorFormatter(stdout, stats);
  }

  @override
  void onVisitFinished() {
    stats.print();
  }

  @override
  void postAnalysis(AnalysisContext context, DriverCommands cmd) {
    cmd.continueAnalyzing = _debuglimit == null || count < _debuglimit;
  }

  @override
  void preAnalysis(AnalysisContext context,
      {bool subDir, DriverCommands commandCallback}) {
    if (subDir) {
      ++dirCount;
    }
    final root = context.contextRoot.root;
    String dirName = path.basename(root.path);
    if (subDir) {
      // Qualify.
      dirName = '${path.basename(root.parent.path)}/$dirName';
    }
    print("Analyzing '$dirName' • [${++count}/$dirCount]...");
  }

  @override
  void reportError(AnalysisResultWithErrors result) {
    final errors = result.errors.where(showError).toList();
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
  void registerNodeProcessors(NodeLintRegistry registry,
      [LinterContext context]) {
    final visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor {
  final LintRule rule;

  _Visitor(this.rule);

  @override
  visitMethodInvocation(MethodInvocation node) {
    bool isDartCore(MethodInvocation node) =>
        node.methodName.staticElement?.library?.name == 'dart.core';

    if (node.methodName.name == 'print' && isDartCore(node)) {
      rule.reportLint(node.methodName);
    }
  }
}
