#!/bin/bash

# Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e


if [ "$SURVEYOR_BOT" = "format" ]; then
  echo "Checking source formatting..."
  dartfmt -n --set-exit-if-changed example lib tool

else
  echo "Analyzing sources..."

  # Verify that the libraries are error free.
  dartanalyzer --fatal-warnings --fatal-infos \
    example \
    lib

  echo ""

  # Run the tests.
  # dart --enable-asserts test/all.dart

fi
