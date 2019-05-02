
import 'dart:io';

import 'package:analyzer/dart/ast/visitor.dart';

import 'common.dart';

/// A simple visitor for analysis options files.
abstract class AnalysisOptionsVisitor {
  void visit(AnalysisOptionsFile file) {}
}

abstract class PostVisitCallback {
  void onVisitFinished();
}

class OptionsVisitor extends AnalysisOptionsVisitor {
  @override
  void visit(AnalysisOptionsFile options) {
    //print('>> visiting: ${options.file}');
  }
}

class PubspecVisitor extends PubspecFileVisitor {
  @override
  void visit(PubspecFile pubspec) {
//    print('>> visiting: ${pubspec.file}');
  }
}
/// A simple visitor for pubspec files.
abstract class PubspecFileVisitor {
  void visit(PubspecFile file) {}
}

/// A simple visitor for package roots.
abstract class PackageRootVisitor {
  void visit(Directory root) {}
}
