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

import 'package:pub_semver/pub_semver.dart';
import 'package:surveyor/src/common.dart';

void main(List<String> args) async {
  var dir = args[0];

  var count = 0;
  var dart2 = VersionConstraint.parse('>=2.0.0');

  var packages = Directory(dir).listSync().toList();
  for (var package in packages) {
    try {
      var pubspec = PubspecFile('${package.path}/pubspec.yaml');
      var yaml = pubspec.yaml;
      var sdkVersion = yaml['environment']['sdk'];
      var constraint = VersionConstraint.parse(sdkVersion);

      if (!constraint.allowsAny(dart2)) {
        print('removing: $package ($sdkVersion)');
        await package.delete(recursive: true);
        ++count;
      }
    } catch (_) {
      // Ignore.
    }
  }

  print('Removed: $count packages.');
}
