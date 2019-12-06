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

/// Find and delete duplicate packages in a directory.
void main(List<String> args) async {
  final dir = args[0];

  final seen = <String, String>{};

  final packages = Directory(dir).listSync().map((f) => f.path).toList()
    ..sort();
  for (var package in packages) {
    // cache/flutter_util-0.0.1 => flutter_util
    var name = package.split('/').last.split('-').first;
    var previous = seen[name];
    if (previous != null) {
      print('deleting $previous, favoring $package');
      Directory(previous).deleteSync(recursive: true);
    }
    seen[name] = package;
  }
}
