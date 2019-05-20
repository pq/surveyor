# 📐 surveyor
Tools for surveying Dart packages

## Installing

These tools are best run from source.  To get the sources, clone the `suveyor` repo like this:

    $ git clone https://github.com/pq/surveyor.git

From there you can run the `examples`.

## Examples

### Surveying Widget Use

    dart bin/example/survey_widgets.dart <path_to_project>

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
