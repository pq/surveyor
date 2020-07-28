//  Copyright 2020 Google LLC
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

/// Looks for a few specific API uses.
///
/// Run like so:
///
/// dart example/annotation_surveyor.dart <source dir>
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

  if (_debugLimit != null) {
    print('Limiting analysis to $_debugLimit packages.');
  }

  var collector = AnnotationUseCollector();

  var stopwatch = Stopwatch()..start();

  var driver = Driver.forArgs(args);
  driver.forceSkipInstall = true;
  driver.showErrors = false;
  driver.resolveUnits = true;
  driver.visitor = collector;

  await driver.analyze();

  stopwatch.stop();

  var duration = Duration(milliseconds: stopwatch.elapsedMilliseconds);
  var aliasCount = collector.aliasCount;
  var typeCount = collector.genericFunctionType.alias;
  var parameterCount = collector.parameterCount;
  var parameterWithMetadataCount = collector.parameterWithMetadataCount;
  var percent = collector.parameterPercents;

  print('(Elapsed time: $duration)');
  print('');
  print('$percent of parameters in function type aliases have annotations');
  print('');
  print('Found $aliasCount function type aliases');
  print('Found $typeCount generic function types not in aliases');
  print('Found $parameterCount parameters in those aliases and function types');
  print('Found $parameterWithMetadataCount parameters with annotations');
  print('');
  print('Notes:');
  print('- Numbers are for all function types, and are followed by a');
  print('  breakdown with the numbers for old-style function type aliases');
  print('  first, followed by the numbers for generic function type aliases,');
  print('  followed by the numbers for generic function types outside of');
  print('  aliases (when appropriate).');
}

int dirCount;

/// If non-zero, stops once limit is reached (for debugging).
int _debugLimit; //500;

class AnnotationUseCollector extends RecursiveAstVisitor<void>
    implements PreAnalysisCallback, PostAnalysisCallback, AstContext {
  int count = 0;
  String filePath;
  LineInfo lineInfo;
  Folder currentFolder;

  _Counts functionTypeAlias = _Counts();
  _Counts genericTypeAlias = _Counts();
  _Counts genericFunctionType = _Counts();

  AnnotationUseCollector();

  String get aliasCount {
    var function = functionTypeAlias.alias;
    var generic = genericTypeAlias.alias;
    return '${function + generic} ($function, $generic)';
  }

  String get parameterCount {
    var function = functionTypeAlias.parameter;
    var generic = genericTypeAlias.parameter;
    var type = genericFunctionType.parameter;
    return '${function + generic + type} ($function, $generic, $type)';
  }

  String get parameterPercents {
    String percent(int numerator, int denominator) {
      if (denominator == 0) {
        return '0.00';
      }
      var percent = numerator / denominator;
      return ((percent * 10000).truncate() / 100).toStringAsFixed(2);
    }

    var functionNumerator = functionTypeAlias.parameterWithMetadata;
    var functionDenominator = functionTypeAlias.parameter;
    var functionPercent = percent(functionNumerator, functionDenominator);

    var genericNumerator = genericTypeAlias.parameterWithMetadata;
    var genericDenominator = genericTypeAlias.parameter;
    var genericPercent = percent(genericNumerator, genericDenominator);

    var typeNumerator = genericFunctionType.parameterWithMetadata;
    var typeDenominator = genericFunctionType.parameter;
    var typePercent = percent(typeNumerator, typeDenominator);

    var totalNumerator = functionNumerator + typeNumerator + genericNumerator;
    var totalDenominator =
        functionDenominator + typeDenominator + genericDenominator;
    var totalPercent = percent(totalNumerator, totalDenominator);

    return '$totalPercent% ($functionPercent%, $genericPercent%, $typePercent%)';
  }

  String get parameterWithMetadataCount {
    var function = functionTypeAlias.parameterWithMetadata;
    var generic = genericTypeAlias.parameterWithMetadata;
    var type = genericFunctionType.parameterWithMetadata;
    return '${function + generic + type} ($function, $generic, $type)';
  }

  @override
  void postAnalysis(SurveyorContext context, DriverCommands cmd) {
    cmd.continueAnalyzing = _debugLimit == null || count < _debugLimit;
    // Reporting done in visitSimpleIdentifier.
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool subDir, DriverCommands commandCallback}) {
    if (subDir) {
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
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    functionTypeAlias.countParameters(node.parameters.parameters);
    return super.visitFunctionTypeAlias(node);
  }

  @override
  void visitGenericFunctionType(GenericFunctionType node) {
    if (node.parent is! GenericTypeAlias) {
      genericFunctionType.countParameters(node.parameters.parameters);
    }
    super.visitGenericFunctionType(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    genericTypeAlias.countParameters(node.functionType.parameters.parameters);
    return super.visitGenericTypeAlias(node);
  }
}

class _Counts {
  /// The number of type aliases that were visited.
  int alias = 0;

  /// The number of parameters in type aliases that were visited.
  int parameter = 0;

  /// The number of parameters in type aliases that were visited that had
  /// annotations associated with them.
  int parameterWithMetadata = 0;

  _Counts();

  void countParameters(List<FormalParameter> parameters) {
    alias++;
    parameter += parameters.length;
    for (var parameter in parameters) {
      if (parameter.metadata.isNotEmpty) {
        parameterWithMetadata++;
      }
    }
  }
}
