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

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart' show Parser;
import 'package:analyzer/src/string_source.dart' show StringSource;
import 'package:pub_semver/pub_semver.dart';

void main(List<String> args) {
  if (args.length != 1) {
    throw Exception('Provide a path to a file to spelunk');
  }

  Spelunker(args[0]).spelunk();
}

class Spelunker {
  final String path;
  final IOSink sink;

  Spelunker(this.path, {IOSink? sink}) : sink = sink ?? stdout;

  void spelunk() {
    var contents = File(path).readAsStringSync();

    var errorListener = _ErrorListener();

    var reader = CharSequenceReader(contents);
    var stringSource = StringSource(contents, path);
    var featureSet = FeatureSet.fromEnableFlags2(
      sdkLanguageVersion: Version.parse('2.12.0'),
      flags: [],
    );
    var scanner = Scanner(stringSource, reader, errorListener)
      ..configureFeatures(
        featureSet: featureSet,
        featureSetForOverriding: featureSet,
      );
    var startToken = scanner.tokenize();

    errorListener.throwIfErrors();

    var parser = Parser(stringSource, errorListener, featureSet: featureSet);
    var node = parser.parseCompilationUnit(startToken);

    errorListener.throwIfErrors();

    var visitor = _SourceVisitor(sink);
    node.accept(visitor);
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

class _SourceVisitor extends GeneralizingAstVisitor {
  int indent = 0;

  final IOSink sink;

  _SourceVisitor(this.sink);

  String asString(AstNode node) =>
      '${typeInfo(node.runtimeType)} [${node.toString()}]';

  Iterable<Token> getPrecedingComments(Token token) sync* {
    Token? comment = token.precedingComments;
    while (comment != null) {
      yield comment;
      comment = comment.next;
    }
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
  void visitNode(AstNode node) {
    write(node);

    ++indent;
    node.visitChildren(this);
    --indent;
    return;
  }

  void write(AstNode node) {
    //EOL comments
    var comments = getPrecedingComments(node.beginToken);
    for (var c in comments) {
      sink.writeln('${"  " * indent}$c');
    }
    sink.writeln(
        '${"  " * indent}${asString(node)} ${getTrailingComment(node)}');
  }
}
