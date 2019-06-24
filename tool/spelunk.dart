import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart' show Parser;
import 'package:analyzer/src/string_source.dart' show StringSource;

main(List<String> args) {
  if (args.length != 1) {
    throw Exception('Provide a path to a file to spelunk');
  }

  Spelunker(args[0]).spelunk();
}

class Spelunker {
  final String path;
  final IOSink sink;

  Spelunker(this.path, {IOSink sink}) : sink = sink ?? stdout;

  void spelunk() {
    var contents = File(path).readAsStringSync();

    var errorListener = _ErrorListener();

    var reader = CharSequenceReader(contents);
    var stringSource = StringSource(contents, path);
    var featureSet = FeatureSet.fromEnableFlags([]);
    var scanner = Scanner(stringSource, reader, errorListener)
      ..configureFeatures(featureSet);
    var startToken = scanner.tokenize();

    errorListener.throwIfErrors();

    var parser =
        Parser(stringSource, errorListener, featureSet: featureSet);
    var node = parser.parseCompilationUnit(startToken);

    errorListener.throwIfErrors();

    var visitor = _SourceVisitor(sink);
    node.accept(visitor);
  }
}

class _SourceVisitor extends GeneralizingAstVisitor {
  int indent = 0;

  final IOSink sink;

  _SourceVisitor(this.sink);

  String asString(AstNode node) =>
      typeInfo(node.runtimeType) + ' [${node.toString()}]';

  List<CommentToken> getPrecedingComments(Token token) {
    var comments = <CommentToken>[];
    var comment = token.precedingComments;
    while (comment is CommentToken) {
      comments.add(comment);
      comment = comment.next;
    }
    return comments;
  }

  String getTrailingComment(AstNode node) {
    var successor = node.endToken.next;
    if (successor != null) {
      var precedingComments = successor.precedingComments;
      if (precedingComments != null) {
        return precedingComments.toString();
      }
    }
    return '';
  }

  String typeInfo(Type type) => type.toString();

  @override
  visitNode(AstNode node) {
    write(node);

    ++indent;
    node.visitChildren(this);
    --indent;
    return null;
  }

  write(AstNode node) {
    //EOL comments
    var comments = getPrecedingComments(node.beginToken);
    comments.forEach((c) => sink.writeln('${"  " * indent}$c'));

    sink.writeln(
        '${"  " * indent}${asString(node)} ${getTrailingComment(node)}');
  }
}

class _ErrorListener implements AnalysisErrorListener {
  final errors = <AnalysisError>[];

  @override
  void onError(AnalysisError error) {
    errors.add(error);
  }

  void throwIfErrors() {
    if (errors.isNotEmpty) {
      throw Exception(errors);
    }
  }
}
