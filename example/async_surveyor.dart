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
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  final driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.visitor = AsyncCollector();

  await driver.analyze();
}

int dirCount;

class AsyncCollector extends RecursiveAstVisitor
    implements PostVisitCallback, PreAnalysisCallback, PostAnalysisCallback, AstContext {
  int count = 0;
  String filePath;
  LineInfo lineInfo;

  List<String> reports = <String>[];

  AsyncCollector();

  @override
  void onVisitFinished() {
    print("Found ${reports.length} 'async's:");
    reports.forEach(print);
  }

  @override
  void preAnalysis(AnalysisContext context) {
    String dirName = path.basename(context.contextRoot.root.path);
    print("Analyzing '$dirName' • [${++count}/$dirCount] ...");
  }

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'async') {
      final location = lineInfo.getLocation(node.offset);
      final report = '$filePath:${location.lineNumber}:${location.columnNumber}';
      reports.add(report);
      print(
          "found 'async' • $report");
    }
    return super.visitSimpleIdentifier(node);
  }

  @override
  void postAnalysis(AnalysisContext context) {
    // Reporting done in visitSimpleIdentifier.
  }

  @override
  void setLineInfo(LineInfo lineInfo) {
    this.lineInfo = lineInfo;
  }

  @override
  void setFilePath(String filePath) {
    this.filePath = filePath;
  }
}
