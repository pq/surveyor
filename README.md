# 📐 surveyor
Tools for surveying Dart packages


## Examples

### Surveying Widget Use


```
> dart bin/example/survey_widgets.dart <path_to_project>

```

will analyze the project at the given path and present a list of found `Widget` child-parent 2-Grams.

A sample run produces:

```
2 Grams:
Column->Container : 1
Column->null : 1
Container->Row : 1
Expanded->Column : 1
FlareActor->Container : 1
FlareActor->GestureDetector : 1
FlareActor->Scaffold : 1
GestureDetector->Expanded : 1
HomePage->null : 1
MaterialApp->null : 1
PageView->Scaffold : 1
Row->GestureDetector : 1
Scaffold->Column : 1
Text->Column : 5
```

(Note that by default package dependencies will only be installed if a `.packages` file is absent from the project under analysis.  If you want to make sure package dependencies are (re)installed, run with the `--force-install` option.)
