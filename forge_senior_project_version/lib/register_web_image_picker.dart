import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';

/// Registers [image_picker] for web when the generated registrant does not run
/// (some `flutter build web` / hosting setups hit MissingPluginException otherwise).
void registerWebImagePicker() {
  ImagePickerPlugin.registerWith(webPluginRegistrar);
}
