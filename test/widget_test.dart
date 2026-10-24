import 'package:flutter_test/flutter_test.dart';
import 'package:pledge/services/api.dart';

void main() {
  test('partner link is built from the app base URL', () {
    expect(partnerLink('abc123'), endsWith('/confirm/abc123'));
  });
}
