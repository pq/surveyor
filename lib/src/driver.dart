import 'dart:io' as io;

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisEngine, AnalysisOptionsImpl;
import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer/src/services/lint.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/install.dart';

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

  List<Linter> _lints;

  bool forceSkipInstall = false;

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

  bool get forcePackageInstall => options.forceInstall;

  List<Linter> get lints => _lints;

  /// Hook to contribute custom lint rules.
  set lints(List<Linter> lints) {
    // Ensure lints are registered
    for (var lint in lints) {
      Registry.ruleRegistry.register(lint);
    }
    _lints = lints;
  }

  bool get skipPackageInstall => forceSkipInstall || options.skipInstall;

  Future analyze({bool forceInstall}) => _analyze(sources);

  /// Hook to influence context post analysis.
  void postAnalyze(AnalysisContext context, DriverCommands callback) {
    if (visitor is PostAnalysisCallback) {
      (visitor as PostAnalysisCallback).postAnalysis(context, callback);
    }
  }

  /// Hook to influence context before analysis.
  void preAnalyze(AnalysisContext context, {bool subDir}) {
    if (visitor is PreAnalysisCallback) {
      (visitor as PreAnalysisCallback).preAnalysis(context, subDir: subDir);
    }
  }

  Future _analyze(List<String> sourceDirs, {bool forceInstall}) async {
    if (sourceDirs.isEmpty) {
      print('Specify one or more files and directories.');
      return;
    }
    ResourceProvider resourceProvider = PhysicalResourceProvider.INSTANCE;
    await _analyzeFiles(resourceProvider, sourceDirs);
    print('Finished.');
  }

  Future _analyzeFiles(
      ResourceProvider resourceProvider, List<String> analysisRoots) async {
    if (skipPackageInstall) {
      print('(Skipping dependency checks.)');
    }

    // Analyze.
    print('Analyzing...');

    final cmd = DriverCommands();

    for (var root in analysisRoots) {
      if (cmd.continueAnalyzing) {
        AnalysisContextCollection collection = AnalysisContextCollection(
            includedPaths: [root], resourceProvider: resourceProvider);

        for (AnalysisContext context in collection.contexts) {
          // Add custom lints.
          if (lints != null) {
            var definedRules = context.analysisOptions.lintRules;
            var options = context.analysisOptions as AnalysisOptionsImpl;
            options.lintRules = definedRules.toList()..addAll(lints);
            options.lint = true;
          }
          final dir = context.contextRoot.root.path;
          final package = Package(dir);
          // Ensure dependencies are installed.
          if (!skipPackageInstall) {
            await package.installDependencies(force: forcePackageInstall);
          }

          // Skip analysis if no .packages.
          if (!package.packagesFile.existsSync()) {
            print('No .packages in $dir (skipping analysis)');
            continue;
          }

          preAnalyze(context, subDir: dir != root);

          for (String filePath in context.contextRoot.analyzedFiles()) {
            if (AnalysisEngine.isDartFileName(filePath)) {
              try {
                final result = resolveUnits
                    ? await context.currentSession.getResolvedUnit(filePath)
                    : await context.currentSession.getParsedUnit(filePath);

                if (visitor != null) {
                  if (visitor is ErrorReporter) {
                    (visitor as ErrorReporter).reportError(result);
                  }
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
                print('Exception caught analyzing: $filePath');
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
          postAnalyze(context, cmd);
        }
      }
    }

    if (visitor is PostVisitCallback) {
      (visitor as PostVisitCallback).onVisitFinished();
    }
  }
}

class DriverCommands {
  bool continueAnalyzing = true;
}
