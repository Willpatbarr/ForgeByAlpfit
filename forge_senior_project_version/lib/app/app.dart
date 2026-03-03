import 'package:flutter/material.dart';
import 'package:forge_senior_project_version/core/constants/app_text_styles.dart';
import 'router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Forge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Poppins',
        textTheme: _buildTextTheme(),
      ),
      routerConfig: router,
    );
  }

  static TextTheme _buildTextTheme() {
    const base = TextStyle(fontFamily: 'Poppins', fontWeight: AppTextStyles.bodyWeight);
    return TextTheme(
      displayLarge: base.copyWith(fontSize: 32, fontWeight: AppTextStyles.titleWeight),
      displayMedium: base.copyWith(fontSize: 28, fontWeight: AppTextStyles.titleWeight),
      displaySmall: base.copyWith(fontSize: 24, fontWeight: AppTextStyles.titleWeight),
      headlineLarge: base.copyWith(fontSize: AppTextStyles.titleSize + 2, fontWeight: AppTextStyles.titleWeight),
      headlineMedium: base.copyWith(fontSize: AppTextStyles.titleSize, fontWeight: AppTextStyles.titleWeight),
      headlineSmall: base.copyWith(fontSize: AppTextStyles.subtitleSize, fontWeight: AppTextStyles.subtitleWeight),
      titleLarge: base.copyWith(fontSize: AppTextStyles.titleSize, fontWeight: AppTextStyles.titleWeight),
      titleMedium: base.copyWith(fontSize: AppTextStyles.bodySize, fontWeight: AppTextStyles.bodyWeight),
      titleSmall: base.copyWith(fontSize: AppTextStyles.bodySmallSize, fontWeight: AppTextStyles.bodySmallWeight),
      bodyLarge: base.copyWith(fontSize: AppTextStyles.bodySize, fontWeight: AppTextStyles.bodyWeight),
      bodyMedium: base.copyWith(fontSize: AppTextStyles.bodySmallSize, fontWeight: AppTextStyles.bodySmallWeight),
      bodySmall: base.copyWith(fontSize: AppTextStyles.captionSize, fontWeight: AppTextStyles.captionWeight),
      labelLarge: base.copyWith(fontSize: AppTextStyles.bodySmallSize, fontWeight: AppTextStyles.bodySmallWeight),
      labelMedium: base.copyWith(fontSize: AppTextStyles.captionSize, fontWeight: AppTextStyles.captionWeight),
      labelSmall: base.copyWith(fontSize: 10, fontWeight: AppTextStyles.captionWeight),
    );
  }
}
