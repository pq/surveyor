import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:surveyor/src/driver.dart';

import 'common.dart';

abstract class AstContext {
  void setFilePath(String filePath);
  void setLineInfo(LineInfo lineInfo);
}

/// A simple visitor for analysis options files.
abstract class AnalysisOptionsVisitor {
  void visit(AnalysisOptionsFile file) {}
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

abstract class PostVisitCallback {
  void onVisitFinished();
}

abstract class PreAnalysisCallback {
  void preAnalysis(AnalysisContext context, {bool subDir, DriverCommands commandCallback});
}

abstract class PostAnalysisCallback {
  void postAnalysis(AnalysisContext context, DriverCommands commandCallback);
}

/// A simple visitor for pubspec files.
abstract class PubspecVisitor {
  void visit(PubspecFile file) {}
}
