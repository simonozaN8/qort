import 'package:flutter_test/flutter_test.dart';

import 'generate_app_icon.dart' as icon_gen;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates launcher icon PNG assets', () async {
    await icon_gen.generateAppIcons();
  });
}
