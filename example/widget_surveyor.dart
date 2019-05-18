import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/analysis.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Gathers and displays widget 2-grams.
///
/// Run like so:
///
/// dart example/widget_surveyor.dart <source dir>
main(List<String> args) async {
  if (args.length == 1) {
    final dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList();
    }
  }

  final driver = Driver.forArgs(args);
  driver.visitor = WidgetCollector();

  await driver.analyze();
}

class TwoGram implements Comparable<TwoGram> {
  String parent;
  String child;

  TwoGram(DartType parent, DartType child)
      : parent = parent?.name ?? 'null',
        child = child?.name ?? 'null';

  @override
  int get hashCode => parent.hashCode * 13 + child.hashCode;

  @override
  bool operator ==(other) =>
      other is TwoGram && other.child == child && other.parent == parent;

  @override
  int compareTo(TwoGram other) =>
      parent.compareTo(other.parent) * 2 + child.compareTo(other.child);

  @override
  String toString() => '$parent -> $child';
}

class TwoGrams {
  Map<TwoGram, int> map = <TwoGram, int>{};

  void add(TwoGram twoGram) {
    map.update(twoGram, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  String toString() {
    var sb = StringBuffer();
    for (var entry in map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))) {
      sb.writeln('${entry.key}, ${entry.value}');
    }
    return sb.toString();
  }
}

class WidgetCollector extends RecursiveAstVisitor
    implements PostVisitCallback, PreAnalysisCallback, PostAnalysisCallback {
  TwoGrams twoGrams = TwoGrams();
  Map<String, int> widgets = <String, int>{};

  ListQueue<DartType> enclosingWidgets = ListQueue<DartType>();

  String dirName;
  WidgetCollector();

  @override
  void onVisitFinished() {
    // todo (pq): write summary info.
  }

  @override
  visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.staticType;
    if (isWidgetType(type)) {
      widgets.update(type.name, (v) => v + 1, ifAbsent: () => 1);

      DartType parent =
          enclosingWidgets.isNotEmpty ? enclosingWidgets.first : null;

      twoGrams.add(TwoGram(parent, type));

      enclosingWidgets.addFirst(type);

      // Visit children.
      super.visitInstanceCreationExpression(node);

      // Reset parent.
      enclosingWidgets.removeFirst();
    }
  }

  @override
  void preAnalysis(AnalysisContext context) {
    dirName = path.basename(context.contextRoot.root.path);
    print("Analyzing '$dirName'...");
  }

  @override
  void postAnalysis(AnalysisContext context) {
    write2Grams();
    writeWidgetCounts();
  }

  void write2Grams() {
    final fileName = '${dirName}_2gram.csv';
    print('Writing 2-Grams to "${path.basename(fileName)}"...');
    File(fileName).writeAsStringSync(twoGrams.toString());
  }

  void writeWidgetCounts() {
    final fileName = '${dirName}_widget.csv';
    print('Writing Widget counts to "${path.basename(fileName)}"...');
    final sb = StringBuffer();

    widgets.entries.forEach((entry) {
      sb.write('${entry.key}, ${entry.value}\n');
    });
    File(fileName).writeAsStringSync(sb.toString());
  }
}
