// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

/// The animated demo on the upload page, a static page built with the
/// Stageshow kit into web/demo/. It is an illustration: not focusable and
/// hidden from screen readers (the Semantics label around it describes it).
Widget demoFrame({Key? key, required String src, required String title}) =>
    HtmlElementView.fromTagName(
      key: key,
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as html.IFrameElement;
        frame.src = src;
        frame.title = title;
        frame.setAttribute('aria-hidden', 'true');
        frame.setAttribute('tabindex', '-1');
        frame.setAttribute('loading', 'lazy');
        frame.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%'
          ..pointerEvents = 'none'
          ..background = 'transparent';
      },
    );
