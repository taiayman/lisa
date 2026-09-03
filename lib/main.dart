import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mona_lisa_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // status bar stays (painting behind it), nav bar hides, swipe up brings it back
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MonaLisaScreen(),
    ),
  );
}
