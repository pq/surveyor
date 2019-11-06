import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:surveyor/src/analysis.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

/// Looks for public members without API docs.
///
/// Run like so:
///
/// dart example/doc_surveyor.dart <source dir>
///
main(List<String> args) async {
  if (args.length == 1) {
    final dir = args[0];
    if (!File('$dir/pubspec.yaml').existsSync()) {
      final dirs = <String>[];
      print("Recursing into '$dir'...");
      for (var listing in Directory(dir).listSync()) {
        if (listing is Directory) {
          dirs.add(listing.path);
        }
      }
      args = dirs..sort();
      dirCount = args.length;
      print('(Found $dirCount subdirectories.)');
    }
  }

  if (_debuglimit != null) {
    print('Limiting analysis to $_debuglimit packages.');
  }

  final stopwatch = Stopwatch()..start();

  final driver = Driver.forArgs(args);
  driver.forceSkipInstall = false;
  driver.showErrors = true;
  driver.resolveUnits = true;
  driver.visitor = _Visitor();

  await driver.analyze();

  print(
      '(Elapsed time: ${Duration(milliseconds: stopwatch.elapsedMilliseconds)})');
}

int dirCount;

int elementsMissingDocs = 0;
int totalPublicElements = 0;

/// If non-zero, stops once limit is reached (for debugging).
int _debuglimit;

class _Visitor extends RecursiveAstVisitor
    implements PreAnalysisCallback, PostAnalysisCallback, AstContext {
  bool isInLibFolder;

  AnalysisContext context;

  InheritanceManager3 inheritanceManager;

  String filePath;

  LineInfo lineInfo;

  Set<Element> apiElements;

  _Visitor();

  bool check(Declaration node) {
    bool apiContains(Element element) {
      while (element != null) {
        if (!element.isPrivate && apiElements.contains(element)) {
          return true;
        }
        element = element.enclosingElement;
      }
      return false;
    }

    if (!apiContains(node.declaredElement)) {
      return false;
    }

    ++totalPublicElements;
    if (node.documentationComment == null && !isOverridingMember(node)) {
      ++elementsMissingDocs;

      final location = lineInfo.getLocation(node.offset);
      if (location != null) {
        final name = node.declaredElement.getExtendedDisplayName(null);
        print('$name: ${location.lineNumber}:${location.columnNumber}');
      }
      return true;
    }
    return false;
  }

  Element getOverriddenMember(Element member) {
    if (member == null) {
      return null;
    }

    // ignore: omit_local_variable_types
    ClassElement classElement =
        member.getAncestor((element) => element is ClassElement);
    if (classElement == null) {
      return null;
    }
    final libraryUri = classElement.library.source.uri;
    return inheritanceManager.getInherited(
      classElement.thisType,
      Name(libraryUri, member.name),
    );
  }

  bool isOverridingMember(Declaration node) =>
      getOverriddenMember(node.declaredElement) != null;

  @override
  void postAnalysis(SurveyorContext context, DriverCommands commandCallback) {
    print('------------------------------------------');
    print('$totalPublicElements public API elements');
    print('$elementsMissingDocs missing docs');

    final score =
        ((totalPublicElements - elementsMissingDocs) / totalPublicElements)
            .toStringAsFixed(2);
    print('Score: $score');

    print('------------------------------------------');
  }

  @override
  void preAnalysis(SurveyorContext context,
      {bool subDir, DriverCommands commandCallback}) {
    inheritanceManager = InheritanceManager3(context.typeSystem);
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
  visitClassDeclaration(ClassDeclaration node) {
    if (!isInLibFolder) return;

    if (isPrivate(node.name)) return;

    check(node);

    // Check methods
    final getters = <String, MethodDeclaration>{};
    final setters = <MethodDeclaration>[];

    // Non-getters/setters.
    final methods = <MethodDeclaration>[];

    // Identify getter/setter pairs.
    for (var member in node.members) {
      if (member is MethodDeclaration && !isPrivate(member.name)) {
        if (member.isGetter) {
          getters[member.name.name] = member;
        } else if (member.isSetter) {
          setters.add(member);
        } else {
          methods.add(member);
        }
      }
    }

    // Check all getters, and collect offenders along the way.
    final missingDocs = <MethodDeclaration>{};
    for (var getter in getters.values) {
      if (check(getter)) {
        missingDocs.add(getter);
      }
    }

    // But only setters whose getter is missing a doc.
    for (var setter in setters) {
      final getter = getters[setter.name.name];
      if (getter == null) {
        final libraryUri = node.declaredElement.library.source.uri;
        // Look for an inherited getter.
        final getter = inheritanceManager.getMember(
          node.declaredElement.thisType,
          Name(libraryUri, setter.name.name),
        );
        if (getter is PropertyAccessorElement) {
          if (getter.documentationComment != null) {
            continue;
          }
        }
        check(setter);
      } else if (missingDocs.contains(getter)) {
        check(setter);
      }
    }

    // Check remaining methods.
    methods.forEach(check);
  }

  @override
  visitClassTypeAlias(ClassTypeAlias node) {
    if (!isInLibFolder) return;

    if (!isPrivate(node.name)) {
      check(node);
    }
  }

  @override
  visitCompilationUnit(CompilationUnit node) {
    // Clear cached API elements.
    apiElements = <Element>{};

    final package = getPackage(node);
    // Ignore this compilation unit if it's not in the lib/ folder.
    isInLibFolder = isInLibDir(node, package);
    if (!isInLibFolder) return;

    final library = node.declaredElement.library;
    final namespaceBuilder = NamespaceBuilder();
    final exports = namespaceBuilder.createExportNamespaceForLibrary(library);
    final public = namespaceBuilder.createPublicNamespaceForLibrary(library);
    apiElements.addAll(exports.definedNames.values);
    apiElements.addAll(public.definedNames.values);

    final getters = <String, FunctionDeclaration>{};
    final setters = <FunctionDeclaration>[];

    // Check functions.

    // Non-getters/setters.
    final functions = <FunctionDeclaration>[];

    // Identify getter/setter pairs.
    for (var member in node.declarations) {
      if (member is FunctionDeclaration) {
        var name = member.name;
        if (!isPrivate(name) && name.name != 'main') {
          if (member.isGetter) {
            getters[member.name.name] = member;
          } else if (member.isSetter) {
            setters.add(member);
          } else {
            functions.add(member);
          }
        }
      }
    }

    // Check all getters, and collect offenders along the way.
    final missingDocs = <FunctionDeclaration>{};
    for (var getter in getters.values) {
      if (check(getter)) {
        missingDocs.add(getter);
      }
    }

    // But only setters whose getter is missing a doc.
    for (var setter in setters) {
      final getter = getters[setter.name.name];
      if (getter != null && missingDocs.contains(getter)) {
        check(setter);
      }
    }

    // Check remaining functions.
    functions.forEach(check);

    super.visitCompilationUnit(node);
  }

  @override
  visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!isInLibFolder) return;

    if (!inPrivateMember(node) && !isPrivate(node.name)) {
      check(node);
    }
  }

  @override
  visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    if (!isInLibFolder) return;

    if (!inPrivateMember(node) && !isPrivate(node.name)) {
      check(node);
    }
  }

  @override
  visitEnumDeclaration(EnumDeclaration node) {
    if (!isInLibFolder) return;

    if (!isPrivate(node.name)) {
      check(node);
    }
  }

  @override
  visitExtensionDeclaration(ExtensionDeclaration node) {
    if (!isInLibFolder) return;

    if (node.name == null || isPrivate(node.name)) {
      return;
    }

    check(node);

    // Check methods

    final getters = <String, MethodDeclaration>{};
    final setters = <MethodDeclaration>[];

    // Non-getters/setters.
    final methods = <MethodDeclaration>[];

    // Identify getter/setter pairs.
    for (var member in node.members) {
      if (member is MethodDeclaration && !isPrivate(member.name)) {
        if (member.isGetter) {
          getters[member.name.name] = member;
        } else if (member.isSetter) {
          setters.add(member);
        } else {
          methods.add(member);
        }
      }
    }

    // Check all getters, and collect offenders along the way.
    final missingDocs = <MethodDeclaration>{};
    for (var getter in getters.values) {
      if (check(getter)) {
        missingDocs.add(getter);
      }
    }

    // But only setters whose getter is missing a doc.
    for (var setter in setters) {
      final getter = getters[setter.name.name];
      if (getter != null && missingDocs.contains(getter)) {
        check(setter);
      }
    }

    // Check remaining methods.
    methods.forEach(check);
  }

  @override
  visitFieldDeclaration(FieldDeclaration node) {
    if (!isInLibFolder) return;

    if (!inPrivateMember(node)) {
      for (var field in node.fields.variables) {
        if (!isPrivate(field.name)) {
          check(field);
        }
      }
    }
  }

  @override
  visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (!isInLibFolder) return;

    if (!isPrivate(node.name)) {
      check(node);
    }
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    if (!isInLibFolder) return;

    for (var decl in node.variables.variables) {
      if (!isPrivate(decl.name)) {
        check(decl);
      }
    }
  }
}
