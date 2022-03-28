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

// ignore_for_file: deprecated_member_use, unused_local_variable

import 'dart:convert';
import 'dart:io';

void main() {
  var x = FileMode.append;
  var y = int.parse('9', onError: (source) => 0);
  var f = File('')..writeAsStringSync(jsonDecode(''));
  print(f.length());

  var c = HttpClientResponseCompressionState.compressed;

  print(JsonUtf8Encoder.DEFAULT_BUFFER_SIZE);
  print(exitCode);
}

class A extends Object {
  @override
  String toString() => '';
}
