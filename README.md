# 📐 surveyor
Tools for surveying Dart packages.

[![Build Status](https://github.com/pq/surveyor/workflows/linter/badge.svg)](https://github.com/pq/surveyor/actions)

**Disclaimer:** This is not an officially supported Google product.

## Installing

These tools are best run from source.  To get the sources, clone the `surveyor` repo like this:

    $ git clone https://github.com/pq/surveyor.git

From there you can run the `examples`.

## Examples

### Surveying API Use

    dart example/api_surveyor.dart <path_to_project>

will analyze projects at the given path and identify uses of a few specific APIs.

### Surveying `async` Identifier Use

    dart example/async_surveyor.dart <path_to_project>

will analyze projects at the given path and identify places where `"async"` is used as a simple identifer.  These places would produce errors if `async` become a reserved keyword.

Note that this generates a lot of output.  To make sure none of it is lost, consider redirecting to a file.  For example:

    dart example/async_surveyor.dart  <path>  2>&1 | tee survey_out.txt

### Surveying Errors

    dart example/error_surveyor.dart <path_to_project>

will analyze projects at the given path, filtering for errors.

### Surveying Lint Rule Violations

    dart example/lint_surveyor.dart <path_to_project>

will analyze projects at the given path and identify violations of lint rules (custom rules or ones defined by `package:linter`).

### Surveying API Doc Scoring

    dart example/doc_surveyor/lib/main.dart <path_to_project>
 
will analyze the project at the given path flagging public members that are missing API docs.

A sample run produces output like this:

```
122 public members
Members without docs:
Void • <path-to-provider-repo>/packages/provider/lib/src/proxy_provider.dart • 107:1
NumericProxyProvider • <path-to-provider-repo>/packages/provider/lib/src/proxy_provider.dart • 177:1
Score: 0.98
```

### Surveying Widget Use

    dart example/widget_surveyor/widget_surveyor.dart <path_to_project>

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

## Related Work

See also [`package:pub_crawl`][pub_crawl], which can be used to fetch package sources for analysis from pub.

## Features and bugs

This is very much a work in progress.  Please file feature requests, bugs and any feedback in the [issue tracker][tracker].

Thanks!

[tracker]: https://github.com/pq/surveyor/issues
[pub_crawl]: https://github.com/pq/pub_crawl
