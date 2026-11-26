import 'package:flutter/widgets.dart';

/// Outside the browser (tests on the Dart VM) the animated demo is a blank
/// box of the same size.
Widget demoFrame({Key? key, required String src, required String title}) =>
    SizedBox.expand(key: key);
