# 📐 surveyor
Tools for surveying Dart packages.

[![Build Status](https://travis-ci.org/pq/surveyor.svg)](https://travis-ci.org/pq/surveyor)

## Installing

These tools are best run from source.  To get the sources, clone the `surveyor` repo like this:

    $ git clone https://github.com/pq/surveyor.git

From there you can run the `examples`.

## Examples

### Surveying API Use

    dart bin/example/api_surveyor.dart <path_to_project>

will analyze projects at the given path and identify uses of a few specific APIs.

### Surveying `async` Identifier Use

    dart bin/example/async_surveyor.dart <path_to_project>

will analyze projects at the given path and identify places where `"async"` is used as a simple identifer.  These places would produce errors if `async` become a reserved keyword.

Note that this generates a lot of output.  To make sure none of it is lost, consider redirecting to a file.  For example:

    dart example/async_surveyor.dart  <path>  2>&1 | tee survey_out.txt

### Surveying Errors

    dart bin/example/error_surveyor.dart <path_to_project>

will analyze projects at the given path, filtering for errors.

### Surveying Lint Rule Violations

    dart bin/example/lint_surveyor.dart <path_to_project>

will analyze projects at the given path and identify violations of lint rules (custom rules or ones defined by `package:linter`).

### Surveying Widget Use

    dart example/widget_surveyor.dart <path_to_project>

will analyze the project at the given path and present a list of found `Widget` child-parent 2-Grams.

A sample run produces a csv file with contents like this:

```
AppBar -> Text, 1
Center -> Column, 1
Column -> Text, 3
FloatingActionButton -> Icon, 1
MaterialApp -> MyHomePage, 1
Scaffold -> AppBar, 1
Scaffold -> Center, 1
Scaffold -> FloatingActionButton, 1
null -> MaterialApp, 1
null -> MyApp, 1
null -> Scaffold, 1
```

(Note that by default package dependencies will only be installed if a `.packages` file is absent from the project under analysis.  If you want to make sure package dependencies are (re)installed, run with the `--force-install` option.)

## Features and bugs

This is very much a work in progress.  Please file feature requests, bugs and any feedback in the [issue tracker][tracker].

Thanks!

[tracker]: https://github.com/pq/surveyor/issues
