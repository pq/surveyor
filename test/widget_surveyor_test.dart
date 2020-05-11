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
  group('widget counts', () {
    test('basic_app', () async {
      var results = await analyze('test/data/basic_app');
      expect(results.length, 1);
      var counts = results[0].widgetCounts;
      expect(counts, containsPair('package:basic_app/main.dart#MyApp', 1));
      expect(counts,
          containsPair('package:flutter/src/material/app.dart#MaterialApp', 1));
      expect(
          counts,
          containsPair(
              'package:flutter/src/material/scaffold.dart#Scaffold', 1));
    });
  });
}

Future<List<AnalysisResult>> analyze(String path, {Logger log}) async {
  var driver = Driver.forArgs([path]);
  var collector = WidgetCollector(log ?? Logger.standard());
  driver.visitor = collector;
  await driver.analyze();
  return collector.results.toList();
}
