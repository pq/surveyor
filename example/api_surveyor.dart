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
/// dart example/api_surveyor.dart <source dir>
main(List<String> args) async {
  if (args.length == 1) {
    final dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  if (_debuglimit != null) {
    print('Limiting analysis to $_debuglimit packages.');
  }

  final stopwatch = Stopwatch()..start();

  final driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.showErrors = false;
  driver.resolveUnits = true;
  driver.visitor = ApiUseCollector();

  await driver.analyze();

  print(
      '(Elapsed time: ${Duration(milliseconds: stopwatch.elapsedMilliseconds)})');
}

int dirCount;

/// If non-zero, stops once limit is reached (for debugging).
int _debuglimit; //500;

class ApiUseCollector extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback, AstContext {
  int count = 0;
  int contexts = 0;
  String filePath;
  Folder currentFolder;
  LineInfo lineInfo;

  List<String> reports = <String>[];

  ApiUseCollector();

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    cmd.continueAnalyzing = _debuglimit == null || count < _debuglimit;
    // Reporting done in visitSimpleIdentifier.
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool subDir, DriverCommands commandCallback}) {
    if (subDir) {
      ++dirCount;
    }
    final contextRoot = context.analysisContext.contextRoot;
    currentFolder = contextRoot.root;
    final dirName = path.basename(contextRoot.root.path);

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
  visitMethodInvocation(MethodInvocation node) {
    var location;
    final name = node.methodName.name;
    if (name == 'transform' || name == 'pipe') {
      final type = node.realTarget?.staticType?.name;
      if (type == 'Stream') {
        location = lineInfo.getLocation(node.offset);
      }
    } else if (name == 'close') {
      final type = node.realTarget?.staticType?.name;
      if (type == 'HttpClientRequest') {
        location = lineInfo.getLocation(node.offset);
      }
    }

    if (location != null) {
      print(
          '${node.staticType.name}.$name: $filePath:${location.lineNumber}:${location.columnNumber}');
    }

    return super.visitMethodInvocation(node);
  }
}
