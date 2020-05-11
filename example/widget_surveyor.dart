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
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:corpus/corpus.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/analysis.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Gathers and displays widget counts and 2-grams.
///
/// Run like so:
///
///     dart example/widget_surveyor.dart <source dir>
///
/// Results are output in a file `results.json`.  To get a summary
/// of the results, pass `results.json` and optionally a corpus `index.json` as
/// sole arguments to the surveyor:
///
///     dart example/widget_surveyor.dart results.json [index.json]
///
void main(List<String> args) async {
  var log = Logger.verbose();
  log.stdout('Surveying...');

  if (args.isNotEmpty) {
    if (args[0] == 'results.json') {
      // Disable tracing and timestamps.
      log = Logger.standard();
      log.stdout('Parsing results...');
      var results = ResultsReader().parse();
      var indexFile = checkForIndexFile(args);
      summarizeResults(results, indexFile, log);
      return;
    }
  }

  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      log.trace("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList();
    }
  }

  var collector = WidgetCollector(log);

  var driver = Driver.forArgs(args);
  driver.visitor = collector;

  await driver.analyze();

  log.stdout('Writing results.json...');
  var results =
      JsonEncoder.withIndent('  ').convert(collector.results.toJson());
  File('results.json').writeAsStringSync(results);
  log.stdout('Done');
}

IndexFile checkForIndexFile(List<String> args) {
  if (args.length == 2) {
    var filePath = args[1];
    if (path.basename(filePath) == 'index.json') {
      return IndexFile(filePath)..readSync();
    }
  }
  return null;
}

void summarizeResults(
    AnalysisResults results, IndexFile indexFile, Logger log) {
  var projectCount = 0;
  var skipCount = 0;
  var totals = <String, WidgetOccurrence>{};
  for (var result in results) {
    var entries = result.widgetCounts.entries;
    if (entries.isNotEmpty) {
      ++projectCount;
    } else {
      ++skipCount;
    }
    for (var count in entries) {
      totals.update(count.key,
          (v) => WidgetOccurrence(v.occurrences + count.value, v.projects + 1),
          ifAbsent: () => WidgetOccurrence(count.value, 1));
    }
  }

  log.stdout('Total projects: $projectCount ($skipCount skipped)');
  log.stdout('');

  var sorted = totals.entries.toList()
    ..sort((c1, c2) => c2.value.occurrences - c1.value.occurrences);
  String padClass(String s) => s.padRight(34, ' ');
  String padCount(String s) => s.padLeft(7, ' ');
  String padPercent(String s) => s.padLeft(21, ' ');
  log.stdout(
      '| ${padClass("class - (F)lutter")} |   count | % containing projects |');
  log.stdout(
      '------------------------------------------------------------------------');

  for (var e in sorted) {
    var key = e.key;
    var inFlutter = key.startsWith('package:flutter/') ? ' (F)' : '';
    var name = '${key.split('#')[1]}$inFlutter';
    var count = e.value;
    var percent = (count.projects / projectCount).toStringAsFixed(2);
    log.stdout(
        '| ${padClass(name)} | ${padCount(count.occurrences.toString())} | ${padPercent(percent)} |');
//    log.stdout('$key,${count.occurrences.toString()},$percent');
  }
  log.stdout(
      '------------------------------------------------------------------------');
}

class AnalysisResult {
  final String appName;
  final Map<String, int> widgetCounts;

  AnalysisResult(this.appName, this.widgetCounts);

  AnalysisResult.fromJson(Map<String, dynamic> json)
      : appName = json['name'],
        widgetCounts = {} {
    var map = json['widgets'];
    for (var entry in map.entries) {
      widgetCounts[entry.key] = entry.value as int;
    }
  }

  Map<String, dynamic> toJson() => {'name': appName, 'widgets': widgetCounts};
}

// bug?
// ignore: prefer_mixin
class AnalysisResults with IterableMixin<AnalysisResult> {
  final List<AnalysisResult> _results = [];

  AnalysisResults();

  AnalysisResults.fromJson(Map<String, dynamic> json) {
    var entries = json['details'];
    for (var entry in entries) {
      add(AnalysisResult.fromJson(entry));
    }
  }

  @override
  Iterator<AnalysisResult> get iterator => _results.iterator;

  void add(AnalysisResult result) {
    _results.add(result);
  }

  Map<String, dynamic> toJson() => {
        // Summary?
        // ...
        // Details.
        'details': [for (var result in _results) result.toJson()]
      };
}

class ResultsReader {
  AnalysisResults parse() {
    var json = jsonDecode(File('results.json').readAsStringSync());
    return AnalysisResults.fromJson(json);
  }
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
    var sb = StringBuffer();
    var entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (var entry in entries) {
      sb.writeln('${entry.key}, ${entry.value}');
    }
    return sb.toString();
  }
}

class WidgetCollector extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback {
//  var TwoGrams twoGrams = TwoGrams();
  final Map<String, int> widgets = <String, int>{};
//  var ListQueue<DartType> enclosingWidgets = ListQueue<DartType>();

  final results = AnalysisResults();
  final Logger log;

  String dirName;

  WidgetCollector(this.log);

  String getSignature(DartType type) {
    var uri = type.element.library.location;
    var name = type.element.displayName;
    return '$uri#$name';
  }

  @override
  void postAnalysis(SurveyorContext context, DriverCommands _) {
//    write2Grams();
    writeWidgetCounts();
    widgets.clear();
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool subDir, DriverCommands commandCallback}) {
    dirName = path.basename(context.analysisContext.contextRoot.root.path);
    log.stdout("Analyzing '$dirName'...");
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var type = node.staticType;
    if (isWidgetType(type)) {
      var signature = getSignature(type);
      widgets.update(signature, (v) => v + 1, ifAbsent: () => 1);

//      var parent =
//          enclosingWidgets.isNotEmpty ? enclosingWidgets.first : null;
//
//      twoGrams.add(TwoGram(parent, type));
//
//      enclosingWidgets.addFirst(type);
//
//      // Visit children.
//      super.visitInstanceCreationExpression(node);
//
//      // Reset parent.
//      enclosingWidgets.removeFirst();
    } else {
      super.visitInstanceCreationExpression(node);
    }
  }

//  void write2Grams() {
//    var fileName = '${dirName}_2gram.csv';
//    log.trace("Writing 2-Grams to '${path.basename(fileName)}'...");
//    //File(fileName).writeAsStringSync(twoGrams.toString());
//  }

  void writeWidgetCounts() {
//    var fileName = '${dirName}_widget.csv';
//    log.trace("Writing Widget counts to '${path.basename(fileName)}'...");
//    var sb = StringBuffer();
//    for (var entry in widgets.entries) {
//      var typeUri = entry.key;
//      var isFlutterWidget = typeUri.startsWith('package:flutter/');
//      var widgetType = isFlutterWidget ? 'flutter' : '*';
//      sb.writeln('$typeUri, ${entry.value}, $widgetType');
//    }
//    //TMP
//    print(sb.toString());
//    //File(fileName).writeAsStringSync(sb.toString());

    results.add(AnalysisResult(dirName, Map.from(widgets)));
  }
}

class WidgetOccurrence {
  int occurrences;
  int projects;
  WidgetOccurrence(this.occurrences, this.projects);
}
