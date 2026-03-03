import 'package:flutter/material.dart';

/// Global text sizes and weights. Reference these so you can change
/// the whole app from one place.
abstract class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Poppins';

  // ----- Font sizes -----
  static const double titleSize = 20;
  static const double subtitleSize = 18;
  static const double bodySize = 16;
  static const double bodySmallSize = 14;
  static const double captionSize = 12;
  static const double labelSmallSize = 10;

  // ----- Font weights (use normal for titles so they're larger, not bold) -----
  static const FontWeight titleWeight = FontWeight.normal;
  static const FontWeight subtitleWeight = FontWeight.normal;
  static const FontWeight bodyWeight = FontWeight.normal;
  static const FontWeight bodySmallWeight = FontWeight.normal;
  static const FontWeight captionWeight = FontWeight.normal;
  static const FontWeight semiBoldWeight = FontWeight.w600;
  static const FontWeight mediumWeight = FontWeight.w500;
  static const FontWeight lightWeight = FontWeight.w300;

  // ----- Pre-built TextStyle objects -----
  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: titleSize,
    fontWeight: titleWeight,
    color: Colors.black87,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: subtitleSize,
    fontWeight: subtitleWeight,
    color: Colors.black87,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: bodySize,
    fontWeight: bodyWeight,
    color: Colors.black87,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: bodySmallSize,
    fontWeight: bodySmallWeight,
    color: Colors.black87,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: captionSize,
    fontWeight: captionWeight,
    color: Colors.black54,
  );

  /// Use when you need a title style with a custom color (e.g. white on blue header).
  static TextStyle titleWithColor(Color color) => title.copyWith(color: color);

  /// Use when you need body with custom color.
  static TextStyle bodyWithColor(Color color) => body.copyWith(color: color);

  /// Use when you need bodySmall with custom color.
  static TextStyle bodySmallWithColor(Color color) =>
      bodySmall.copyWith(color: color);

  /// Use when you need subtitle with custom color (e.g. white on blue header).
  static TextStyle subtitleWithColor(Color color) =>
      subtitle.copyWith(color: color);

  /// Use when you need caption with custom color.
  static TextStyle captionWithColor(Color color) =>
      caption.copyWith(color: color);
}
