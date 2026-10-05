import 'document_preview_stub.dart'
    if (dart.library.html) 'document_preview_web.dart' as impl;

import 'package:flutter/widgets.dart';

/// Web PDF/HTML preview frame; null on non-web platforms.
Widget? buildWebDocumentFrame(String url) => impl.buildWebDocumentFrame(url);
