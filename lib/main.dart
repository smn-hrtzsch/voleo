import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/voleo_app.dart';

void main() {
  runApp(const ProviderScope(child: VoleoApp()));
}
