import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/source/line_info.dart';

import 'common.dart';
import 'driver.dart';

/// A simple visitor for analysis options files.
abstract class AnalysisOptionsVisitor {
  void visit(AnalysisOptionsFile file) {}
}

abstract class AstContext {
  void setFilePath(String filePath);
  void setLineInfo(LineInfo lineInfo);
}

/// Hook for custom error reporting.
abstract class ErrorReporter {
  void reportError(AnalysisResultWithErrors result);
}

class OptionsVisitor extends AnalysisOptionsVisitor {
  @override
  void visit(AnalysisOptionsFile options) {
    //print('>> visiting: ${options.file}');
  }
}

/// A simple visitor for package roots.
abstract class PackageRootVisitor {
  void visit(Directory root) {}
}

abstract class PostAnalysisCallback {
  void postAnalysis(AnalysisContext context, DriverCommands commandCallback);
}

abstract class PostVisitCallback {
  void onVisitFinished();
}

abstract class PreAnalysisCallback {
  void preAnalysis(AnalysisContext context,
      {bool subDir, DriverCommands commandCallback});
}

/// A simple visitor for pubspec files.
abstract class PubspecVisitor {
  void visit(PubspecFile file) {}
}
