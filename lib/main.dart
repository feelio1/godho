import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/naver_map_config.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isNaverMapConfigured) {
    await FlutterNaverMap().init(
      clientId: naverMapClientId,
      onAuthFailed: (ex) => debugPrint('Naver Map auth failed: $ex'),
    );
  }

  runApp(const ProviderScope(child: PetClinicCheckApp()));
}

class PetClinicCheckApp extends StatelessWidget {
  const PetClinicCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '펫병원체크',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MainShell(),
    );
  }
}
