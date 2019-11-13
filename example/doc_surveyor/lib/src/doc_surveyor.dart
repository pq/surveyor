// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/dart/element/inheritance_manager3.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:path/path.dart' as path;
import 'package:surveyor/src/analysis.dart';
import 'package:surveyor/src/driver.dart';
import 'package:surveyor/src/visitors.dart';

Future<DocStats> analyzeDocs(String packageFolder, {bool silent =  true}) async {
  final pubspec = path.join(packageFolder, 'pubspec.yaml');
  if (!File(pubspec).existsSync()) {
    throw Exception('File not found: $pubspec');
  }

  final driver = Driver.forArgs([packageFolder]);
  driver.forceSkipInstall = false;
  driver.excludedPaths = ['example', 'test'];
  driver.showErrors = true;
  driver.resolveUnits = true;
  driver.silent = silent;
  final visitor = _Visitor();
  driver.visitor = visitor;

  await driver.analyze();

  return visitor.stats;
}

class DocStats {
  int publicMemberCount = 0;
  final List<SourceLocation> undocumentedMemberLocations = <SourceLocation>[];
}

class SourceLocation {
  final String displayName;
  final Source source;
  final int line;
  final int column;
  SourceLocation(this.displayName, this.source, this.line, this.column);

  String get _bullet => !Platform.isWindows ? '•' : '-';

  String asString() =>
      '$displayName $_bullet ${source.fullName} $_bullet $line:$column';
}

class _Visitor extends RecursiveAstVisitor
    implements PreAnalysisCallback, AstContext {
  bool isInLibFolder;

  AnalysisContext context;

  InheritanceManager3 inheritanceManager;

  String filePath;

  LineInfo lineInfo;

  Set<Element> apiElements;

  DocStats stats = DocStats();

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

    stats.publicMemberCount++;

    if (node.documentationComment == null && !isOverridingMember(node)) {
      final location = lineInfo.getLocation(node.offset);
      if (location != null) {
        stats.undocumentedMemberLocations.add(SourceLocation(
            node.declaredElement.displayName,
            node.declaredElement.source,
            location.lineNumber,
            location.columnNumber));
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
