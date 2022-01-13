//  Copyright 2022 Google LLC
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

import 'dart:io';

import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/lint/registry.dart'; // ignore: implementation_imports
import 'package:path/path.dart' as path;
import 'package:surveyor/src/common.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Collects data about analysis options.
///
/// Run like so:
///
///     dart run example/options_surveyor.dart <source dir>
void main(List<String> args) async {
  if (args.length == 1) {
    var dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      print("Recursing into '$dir'...");
      args = Directory(dir).listSync().map((f) => f.path).toList()..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  if (_debugLimit != 0) {
    print('Limiting analysis to $_debugLimit packages.');
  }

  var driver = Driver.forArgs(args);
  //driver.forceSkipInstall = true;
  //driver.showErrors = true;
  //driver.resolveUnits = true;
  driver.visitor = OptionsVisitor();

  await driver.analyze(displayTiming: true);

  var optionsPercentage = (contextsWithOptions / count).toStringAsFixed(2);
  var lintsPercentage = (contextsWithLints / count).toStringAsFixed(2);

  var line = '----------------------------------------------------------------';

  print('');
  print(
      'Contexts w/ options: $contextsWithOptions / $count • [ $optionsPercentage ]');
  print(
      'Contexts w/ lints: $contextsWithLints / $count • [ $lintsPercentage ]');
  print('');

  print(line);
  print('LINT COUNTS: ---------------------------------------------------');
  print(line);
  printMap(lintCounts, width: line.length);
  print(line);
  print('INCLUDES: ------------------------------------------------------');
  print(line);
  printMap(includeCounts, width: line.length);

  print('(%s are relative to contexts w/ lints and then absolute count)');
  print('');
  print(line);
  print('LINTS w/ NO OCCURRENCES: ---------------------------------------');
  print(line);
  for (var rule in Registry.ruleRegistry.map((rule) => rule.name).toList()
    ..sort()) {
    if (!lintCounts.containsKey(rule)) {
      print(rule);
    }
  }
}

int contextsWithLints = 0;
int contextsWithOptions = 0;

int count = 0;
int dirCount = 0;

Map<String, int> includeCounts = <String, int>{};
Map<String, int> lintCounts = <String, int>{};

/// If non-zero, stops once limit is reached (for debugging).
int _debugLimit = 0; //500;

void printMap(Map<String, int> map, {required int width}) {
  var entries = map.entries.toList()
    ..sort((e1, e2) => (e2.value - e1.value) * 100 + e1.key.compareTo(e2.key));
  for (var entry in entries) {
    var value = entry.value;
    var absolutePercent = (value / count).toStringAsFixed(2);
    var relativePercent = (value / contextsWithLints).toStringAsFixed(2);
    var percents = '[$relativePercent | $absolutePercent]';
    var valueCount = '${entry.key}: $value •';
    print('$valueCount ${percents.padLeft(width - (valueCount.length + 1))}');
  }
  print('');
}

class OptionsVisitor extends SimpleAstVisitor
    implements
        AnalysisOptionsVisitor,
        PreAnalysisCallback,
        PostAnalysisCallback {
  bool isExampleDir = false;

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    if (isExampleDir) return;

    var debugLimit = _debugLimit;
    cmd.continueAnalyzing = debugLimit == 0 || count < debugLimit;

    var lintRules = context.analysisContext.analysisOptions.lintRules;
    if (lintRules.isNotEmpty) {
      ++contextsWithLints;
      for (var rule in lintRules) {
        lintCounts.increment(rule.name);
      }
    }
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool? subDir, DriverCommands? commandCallback}) {
    var contextRoot = context.analysisContext.contextRoot;
    var dirName = path.basename(contextRoot.root.path);

    isExampleDir = dirName == 'example';
    if (isExampleDir) return;

    if (subDir ?? false) {
      ++dirCount;
    }
    print("Analyzing '$dirName' • [${++count}/$dirCount]...");
  }

  @override
  void visit(AnalysisOptionsFile file) {
    if (isExampleDir) return;

    ++contextsWithOptions;

    var include = file.yaml['include'];
    if (include != null) {
      includeCounts.increment(include);
    }
  }
}

extension on Map<String, int> {
  void increment(String key) =>
      update(key, (value) => value + 1, ifAbsent: () => 1);
}
