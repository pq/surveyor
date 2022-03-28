//  Copyright 2022 Google LLC
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

import 'package:test/test.dart';

import '../example/core_lib_use_surveyor.dart';

main() async {
  var occurrences = await survey(['test_data/core_lib_use_surveyor']);
  var data = occurrences.data['core_lib_use_surveyor']!;

  void expectSymbols(String library, List<String> symbols) {
    test(library, () {
      expect(data[library], unorderedEquals(symbols));
    });
  }

  expectSymbols('dart.convert', [
    'JsonUtf8Encoder', // class, referenced via static field
    'jsonDecode' // top-level function
  ]);

  expectSymbols('dart.core', [
    'parse',
    'print',
    'override', // annotation
    'Object',
    'String',
  ]);

  expectSymbols('dart._http', [
    'HttpClientResponseCompressionState' // enum
  ]);

  expectSymbols('dart.io', [
    'FileMode', 'File', // classes
    'exitCode', // top-level variable
  ]);

  // todo(pq): no mixins in core libs?
}
