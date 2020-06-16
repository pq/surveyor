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

import 'package:cli_util/cli_logging.dart';
import 'package:surveyor/src/driver.dart';
import 'package:test/test.dart';

import '../example/widget_surveyor.dart';

Future<void> main() async {
  group('widget survey', () {
    test('basic_app', () async {
      var result = await analyze('test/data/basic_app');
      var refs = result.widgetReferences;
      expectContains(
        refs,
        {
          'package:basic_app/main.dart#MyApp': ['lib/main.dart:3:23'],
          'package:flutter/src/material/app.dart#MaterialApp': [
            'lib/main.dart:8:12'
          ],
          'package:basic_app/main.dart#MyHomePage': ['lib/main.dart:13:13'],
          'package:flutter/src/material/scaffold.dart#Scaffold': [
            'lib/main.dart:38:13'
          ],
          'package:flutter/src/material/app_bar.dart#AppBar': [
            'lib/main.dart:39:15'
          ],
          'package:flutter/src/widgets/text.dart#Text': [
            'lib/main.dart:40:16',
            'lib/main.dart:46:13',
            'lib/main.dart:49:13',
            'lib/main.dart:53:13'
          ],
          'package:flutter/src/widgets/basic.dart#Center': [
            'lib/main.dart:42:13'
          ],
          'package:flutter/src/widgets/basic.dart#Column': [
            'lib/main.dart:43:16'
          ],
          'package:flutter/src/material/floating_action_button.dart#FloatingActionButton':
              ['lib/main.dart:59:29'],
          'package:flutter/src/widgets/icon.dart#Icon': ['lib/main.dart:62:16']
        },
      );
      expect(0, result.routeCount);
    });
    test('route_app', () async {
      var result = await analyze('test/data/route_app');
      var refs = result.widgetReferences;
      expectContains(
        refs,
        {
          'package:flutter/src/material/app.dart#MaterialApp': [
            'lib/main.dart:4:10',
            'lib/main.dart:58:10'
          ],
          'package:route_app/main.dart#FirstScreen': ['lib/main.dart:11:25'],
          'package:route_app/main.dart#SecondScreen': ['lib/main.dart:13:31'],
          'package:flutter/src/material/scaffold.dart#Scaffold': [
            'lib/main.dart:21:12',
            'lib/main.dart:40:12',
            'lib/main.dart:67:12',
            'lib/main.dart:89:12'
          ],
          'package:flutter/src/material/app_bar.dart#AppBar': [
            'lib/main.dart:22:15',
            'lib/main.dart:41:15',
            'lib/main.dart:68:15',
            'lib/main.dart:90:15'
          ],
          'package:flutter/src/widgets/text.dart#Text': [
            'lib/main.dart:23:16',
            'lib/main.dart:27:18',
            'lib/main.dart:42:16',
            'lib/main.dart:49:18',
            'lib/main.dart:69:16',
            'lib/main.dart:73:18',
            'lib/main.dart:91:16',
            'lib/main.dart:98:18'
          ],
          'package:flutter/src/widgets/basic.dart#Center': [
            'lib/main.dart:25:13',
            'lib/main.dart:44:13',
            'lib/main.dart:71:13',
            'lib/main.dart:93:13'
          ],
          'package:flutter/src/material/raised_button.dart#RaisedButton': [
            'lib/main.dart:26:16',
            'lib/main.dart:45:16',
            'lib/main.dart:72:16',
            'lib/main.dart:94:16'
          ],
          'package:route_app/main.dart#FirstRoute': ['lib/main.dart:60:11'],
          'package:route_app/main.dart#SecondRoute': ['lib/main.dart:77:55']
        },
      );
      expect(3, result.routeCount);
    });
  });
}

Future<AnalysisResult> analyze(String path, {Logger log}) async {
  var driver = Driver.forArgs([path]);
  var collector = WidgetCollector(log ?? Logger.standard(), path);
  driver.visitor = collector;
  await driver.analyze();
  var results = collector.results.toList();
  expect(results, hasLength(1));
  return results[0];
}

void expectContains(
    Map<String, List<String>> m1, Map<String, List<String>> m2) {
  for (var e in m2.entries) {
    expect(m1, containsPair(e.key, e.value));
  }
}
