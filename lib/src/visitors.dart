import 'dart:io';

import 'common.dart';

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

/// A simple visitor for pubspec files.
abstract class PubspecVisitor {
  void visit(PubspecFile file) {}
}
