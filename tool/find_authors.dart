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

import 'dart:convert';

import 'package:surveyor/src/common.dart';

/// Find package authors.
void main(List<String> args) async {
  var packages = [
    '_discoveryapis_commons',
    'alpha',
    'angel_cli',
    'angel_orm_generator',
    'angular',
    'angular_aria',
    'angular_bloc',
    'angular_dart_ui_bootstrap',
    'ansi_color_palette',
    'appengine',
    'args',
    'asset_pack',
    'async',
    'build_runner',
    'buildbucket',
    'chessboard',
    'codable',
    'code_builder',
    'csp_fixer',
    'cupid',
    'dart2_constant',
    'dart_browser_loader',
    'dartlr',
    'dartmon',
    'dataset',
    'deny',
    'devtools',
    'dilithium',
    'discoveryapis_generator',
    'disposable',
    'expire_cache',
    'fake_async',
    'fancy_syntax',
    'floor_generator',
    'flutter_flux',
    'flutter_wordpress',
    'force_elements',
    'front_end',
    'google_adsense_v1_1_api',
    'google_adsense_v1_api',
    'google_compute_v1beta14_api',
    'google_latitude_v1_api',
    'google_maps',
    'google_plus_widget',
    'googleapis',
    'googleapis_beta',
    'gorgon',
    'html_builder',
    'html_components',
    'http',
    'ice_code_editor',
    'ice_code_editor_experimental',
    'intl',
    'iris',
    'js_wrapping',
    'kernel',
    'kourim',
    'libpq93_bindings',
    'mandrill_api',
    'example',
    'mobx',
    'ngx_core',
    'node_webkit',
    'nuxeo_automation',
    'over_react',
    'play_phaser',
    'play_pixi',
    'plummbur_kruk',
    'pool',
    'pref_gen',
    'pub_proxy_server',
    'quiver',
    'rails_ujs',
    'rate_limit',
    'reflutter_generator',
    'remote_services',
    'rosetta_generator',
    'simple_auth_generator',
    'socket_io_client',
    'socket_io_common_client',
    'solitaire',
    'streamy',
    'superlu',
    'teaolive',
    'test_api',
    'three',
    'uix',
    'universal_html',
    'universal_io',
    'vint',
    'web_ui',
    'webapper',
    'webdriver',
    'webui_tasks',
    'wui_builder',
    'zx',
  ];

  for (var p in packages) {
    var json = jsonDecode(await getBody('https://pub.dev/api/packages/$p'));
    var details = hasDartAuthor(json)
        ? ' (Dart)'
        : hasFlutterAuthor(json) ? ' (Flutter)' : '';
    print('$p$details');
  }
}

bool hasDartAuthor(json) {
  var latest = json['latest'];
  var author = latest['pubspec']['author'];
  return author?.contains('Dart Team') == true;
}

bool hasFlutterAuthor(json) {
  var latest = json['latest'];
  var author = latest['pubspec']['author'];
  return author?.contains('Flutter Team') == true;
}
