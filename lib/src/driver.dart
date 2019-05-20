import 'dart:io' as io;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/generated/engine.dart'
    show AnalysisEngine, AnalysisErrorInfo, AnalysisErrorInfoImpl;
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/install.dart';

import 'analysis.dart';
import 'common.dart';
import 'visitors.dart';

class Driver {
  final CommandLineOptions options;

  /// Hook to contribute a custom AST visitor.
  AstVisitor visitor;

  /// Hook to contribute custom options analysis.
  OptionsVisitor optionsVisitor;

  /// Hook to contribute custom pubspec analysis.
  PubspecVisitor pubspecVisitor;

  bool showErrors = true;

  bool resolveUnits = true;

  final List<String> sources;

  Driver(ArgResults argResults)
      : options = CommandLineOptions.fromArgs(argResults),
        sources = argResults.rest
            .map((p) => path.normalize(io.File(p).absolute.path))
            .toList();

  factory Driver.forArgs(List<String> args) {
    var argParser = ArgParser()
      ..addFlag('verbose', abbr: 'v', help: 'verbose output.')
      ..addFlag('force-install', help: 'force package (re)installation.')
      ..addFlag('skip-install', help: 'skip package install checks.')
      ..addFlag('color', help: 'color output.');
    var argResults = argParser.parse(args);
    return Driver(argResults);
  }

  bool forceSkipInstall = false;

  bool get forcePackageInstall => options.forceInstall;

  bool get skipPackageInstall => forceSkipInstall || options.skipInstall;

  Future analyze({bool forceInstall}) => _analyze(sources);

  /// Hook to influence context before analysis.
  void preAnalyze(AnalysisContext context) {
    if (visitor is PreAnalysisCallback) {
      (visitor as PreAnalysisCallback).preAnalysis(context);
    }
  }

  /// Hook to influence context before analysis.
  void postAnalyze(AnalysisContext context) {
    if (visitor is PostAnalysisCallback) {
      (visitor as PostAnalysisCallback).postAnalysis(context);
    }
  }

  /// Hook for custom error filtering.
  bool showError(AnalysisError element) => true;

  Future _analyze(List<String> sourceDirs, {bool forceInstall}) async {
    if (sourceDirs.isEmpty) {
      print('Specify one or more files and directories.');
      return;
    }
    ResourceProvider resourceProvider = PhysicalResourceProvider.INSTANCE;
    List<ErrorsResult> results =
        await _analyzeFiles(resourceProvider, sourceDirs);
    print('Finished.');
    if (showErrors) {
      _printAnalysisResults(results);
    }
  }

  Future<List<ErrorsResult>> _analyzeFiles(
      ResourceProvider resourceProvider, List<String> analysisRoots) async {
    // Ensure dependencies are installed.
    if (!skipPackageInstall) {
      print('Checking dependencies...');
      for (String dir in analysisRoots) {
        await Package(dir).installDependencies(force: forcePackageInstall);
      }
    } else {
      print('(Skipped dependency checks.)');
    }

    // Analyze.
    print('Analyzing...');

    final results = <ErrorsResult>[];
    for (var root in analysisRoots) {
      AnalysisContextCollection collection = new AnalysisContextCollection(
          includedPaths: [root], resourceProvider: resourceProvider);
      for (AnalysisContext context in collection.contexts) {
        preAnalyze(context);

        for (String filePath in context.contextRoot.analyzedFiles()) {
          if (AnalysisEngine.isDartFileName(filePath)) {
            if (showErrors) {
              ErrorsResult result =
                  await context.currentSession.getErrors(filePath);
              if (result.errors.isNotEmpty) {
                results.add(result);
              }
            }

            // todo (pq): move this up and collect errors from the resolved result.
            try {
              final result = resolveUnits
                  ? await context.currentSession.getResolvedUnit(filePath)
                  : await context.currentSession.getParsedUnit(filePath);
              if (visitor != null) {
                if (visitor is AstContext) {
                  AstContext astContext = visitor as AstContext;
                  astContext.setLineInfo(result.lineInfo);
                  astContext.setFilePath(filePath);
                }
                if (result is ParsedUnitResult) {
                  result.unit.accept(visitor);
                } else if (result is ResolvedUnitResult) {
                  result.unit.accept(visitor);
                }
              }
            } catch (e) {
              print('Exception caught analyzling: $filePath');
              print(e.toString());
            }
          }

          if (optionsVisitor != null) {
            if (AnalysisEngine.isAnalysisOptionsFileName(filePath)) {
              optionsVisitor.visit(AnalysisOptionsFile(filePath));
            }
          }

          if (pubspecVisitor != null) {
            if (path.basename(filePath) == 'pubspec.yaml') {
              pubspecVisitor.visit(PubspecFile(filePath));
            }
          }
        }

        await pumpEventQueue(times: 512);

        postAnalyze(context);
      }
    }

    if (visitor is PostVisitCallback) {
      (visitor as PostVisitCallback).onVisitFinished();
    }

    return results;
  }

  void _printAnalysisResults(List<ErrorsResult> results) {
    List<AnalysisErrorInfo> infos = <AnalysisErrorInfo>[];
    for (ErrorsResult result in results) {
      final errors = result.errors.where(showError).toList();
      if (errors.isNotEmpty) {
        infos.add(new AnalysisErrorInfoImpl(errors, result.lineInfo));
      }
    }
    AnalysisStats stats = new AnalysisStats();
    HumanErrorFormatter formatter =
        new HumanErrorFormatter(io.stdout, options, stats);
    formatter.formatErrors(infos);
    formatter.flush();
    stats.print();
  }
}
