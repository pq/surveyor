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

import 'dart:collection';
import 'dart:io';

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
void main(List<String> args) async {
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
  final String parent;
  final String child;

  TwoGram(DartType parent, DartType child)
      : parent = parent?.element?.name ?? 'null',
        child = child?.element?.name ?? 'null';

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
  final Map<TwoGram, int> map = <TwoGram, int>{};

  void add(TwoGram twoGram) {
    map.update(twoGram, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  String toString() {
    final sb = StringBuffer();
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (var entry in entries) {
      sb.writeln('${entry.key}, ${entry.value}');
    }
    return sb.toString();
  }
}

class WidgetCollector extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback {
  final TwoGrams twoGrams = TwoGrams();
  final Map<DartType, int> widgets = <DartType, int>{};
  final ListQueue<DartType> enclosingWidgets = ListQueue<DartType>();

  String dirName;
  WidgetCollector();

  @override
  void postAnalysis(SurveyorContext context, DriverCommands _) {
    write2Grams();
    writeWidgetCounts();
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool subDir, DriverCommands commandCallback}) {
    dirName = path.basename(context.analysisContext.contextRoot.root.path);
    print("Analyzing '$dirName'...");
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.staticType;
    if (isWidgetType(type)) {
      widgets.update(type, (v) => v + 1, ifAbsent: () => 1);

      final parent =
          enclosingWidgets.isNotEmpty ? enclosingWidgets.first : null;

      twoGrams.add(TwoGram(parent, type));

      enclosingWidgets.addFirst(type);

      // Visit children.
      super.visitInstanceCreationExpression(node);

      // Reset parent.
      enclosingWidgets.removeFirst();
    } else {
      super.visitInstanceCreationExpression(node);
    }
  }

  void write2Grams() {
    final fileName = '${dirName}_2gram.csv';
    print("Writing 2-Grams to '${path.basename(fileName)}'...");
    File(fileName).writeAsStringSync(twoGrams.toString());
  }

  void writeWidgetCounts() {
    final fileName = '${dirName}_widget.csv';
    print("Writing Widget counts to '${path.basename(fileName)}'...");
    final sb = StringBuffer();
    for (var entry in widgets.entries) {
      final type = entry.key;
      final isFlutterWidget = type.element.library.location.components[0]
          .startsWith('package:flutter/');
      final widgetType = isFlutterWidget ? 'flutter' : '*';
      sb.write('$type, ${entry.value}, $widgetType\n');
    }
    File(fileName).writeAsStringSync(sb.toString());
  }
}
