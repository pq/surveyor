import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Looks for instances where "async" is used as an identifier
/// and would break were it made a keyword.
///
/// Run like so:
///
/// dart example/async_surveyor.dart <source dir>
main(List<String> args) async {
  if (args.length == 1) {
    final dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList();
    }
  }

  final driver = Driver.forArgs(args);
  driver.visitor = AsyncCollector();

  await driver.analyze();
}

class AsyncCollector extends RecursiveAstVisitor
    implements PostVisitCallback, PreAnalysisCallback, PostAnalysisCallback {
  AsyncCollector();

  @override
  void onVisitFinished() {
    // Reporting done in visitSimpleIdentifier.
  }

  @override
  void preAnalysis(AnalysisContext context) {
    String dirName = path.basename(context.contextRoot.root.path);
    print("Analyzing '$dirName'...");
  }

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'async') {
      final cu =
          node.staticElement.getAncestor((e) => e is CompilationUnitElement);
      final lineInfo = LineInfo.fromContent(cu.source.contents.data);
      final location = lineInfo.getLocation(node.offset);
      print(
          "found 'async' • ${cu.source.fullName}:${location.lineNumber}:${location.columnNumber}");
    }
    return super.visitSimpleIdentifier(node);
  }

  @override
  void postAnalysis(AnalysisContext context) {
    // Reporting done in visitSimpleIdentifier.
  }
}
