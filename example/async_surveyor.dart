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

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Looks for instances where "async" is used as an identifier
/// and would break were it made a keyword.
///
/// Run like so:
///
/// dart run example/async_surveyor.dart <source dir>
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

  if (_debuglimit != null) {
    print('Limiting analysis to $_debuglimit packages.');
  }

  var driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.showErrors = false;
  driver.resolveUnits = false;
  driver.visitor = AsyncCollector();

  await driver.analyze();
}

int dirCount = 0;

/// If non-zero, stops once limit is reached (for debugging).
int? _debuglimit; //500;

class AsyncCollector extends RecursiveAstVisitor
    implements
        PostVisitCallback,
        PreAnalysisCallback,
        PostAnalysisCallback,
        AstContext {
  int count = 0;
  int contexts = 0;
  String? filePath;
  late Folder currentFolder;
  LineInfo? lineInfo;
  Set<Folder> contextRoots = <Folder>{};

  // id: inDecl, notInDecl
  Map<String, Occurrences> occurrences = <String, Occurrences>{
    'async': Occurrences(),
    'await': Occurrences(),
    'yield': Occurrences(),
  };

  List<String> reports = <String>[];

  AsyncCollector();

  @override
  void onVisitFinished() {
    print(
        'Found ${reports.length} occurrences in ${contextRoots.length} packages:');
    reports.forEach(print);

    for (var o in occurrences.entries) {
      var data = o.value;
      print('${o.key}: [${data.decls} decl, ${data.notDecls} ref]');
      data.packages.forEach(print);
    }
  }

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    var debugLimit = _debuglimit;
    cmd.continueAnalyzing = debugLimit == null || count < debugLimit;
    // Reporting done in visitSimpleIdentifier.
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool? subDir, DriverCommands? commandCallback}) {
    if (subDir ?? false) {
      ++dirCount;
    }
    var contextRoot = context.analysisContext.contextRoot;
    currentFolder = contextRoot.root;
    var dirName = path.basename(contextRoot.root.path);

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
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var lineInfo = this.lineInfo;
    if (lineInfo == null) return;

    var id = node.name;

    var occurrence = occurrences[id];
    if (occurrence != null) {
      if (node.inDeclarationContext()) {
        occurrence.decls++;
      } else {
        occurrence.notDecls++;
      }

      // cache/flutter_util-0.0.1 => flutter_util
      occurrence.packages
          .add(currentFolder.path.split('/').last.split('-').first);

      var location = lineInfo.getLocation(node.offset);
      var report = '$filePath:${location.lineNumber}:${location.columnNumber}';
      reports.add(report);
      var declDetail = node.inDeclarationContext() ? '(decl) ' : '';
      print("found '$id' $declDetail• $report");
      contextRoots.add(currentFolder);
      print(occurrences);
    }
    super.visitSimpleIdentifier(node);
  }
}

class Occurrences {
  int decls = 0;
  int notDecls = 0;
  Set<String> packages = <String>{};

  @override
  String toString() => '[$decls, $notDecls] : $packages';
}
