import 'package:bednbite/bridge/bridge_scripts.dart';
import 'package:bednbite/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthUser round-trips through localStorage JSON', () {
    const user = AuthUser(
      userId: 7,
      companyId: 3,
      propertyId: 12,
      name: 'Asha',
      email: 'asha@example.com',
      role: 'admin',
      roleId: 'system_super_admin',
      status: 'active',
    );
    final decoded = AuthUser.decode(user.encode());
    expect(decoded.userId, 7);
    expect(decoded.propertyId, 12);
    expect(decoded.email, 'asha@example.com');
  });

  test('auth injection script embeds values safely', () {
    final js = BridgeScripts.authInjectionJs(
      token: 'a"b',
      userJson: '{"x":1}',
      permsJson: '["guest.view"]',
      origin: 'https://app.bednbite.com',
    );
    expect(js.contains("location.origin !== \"https://app.bednbite.com\""), true);
    expect(js.contains('auth_token'), true);
    // The double-quote in the token must be escaped, not raw.
    expect(js.contains('a"b'), false);
  });
}
