import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/features/links/pending_link.dart';

const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz012345-_';

PendingLink? parse(
  String link, {
  bool dev = true,
  Set<String> hosts = const {},
}) => parseAppLink(Uri.parse(link), allowDevScheme: dev, trustedHosts: hosts);

void main() {
  test('dev scheme links map to reset and invite', () {
    expect(
      parse('teia-dev://reset-password?token=$token')?.kind,
      LinkKind.resetPassword,
    );
    expect(parse('teia-dev://join-space?token=$token')?.kind, LinkKind.invite);
    expect(parse('teia-dev://join-space?token=$token')?.token, token);
  });

  test('dev scheme is refused outside dev builds', () {
    expect(parse('teia-dev://reset-password?token=$token', dev: false), isNull);
  });

  test('https links are accepted only from trusted hosts on the web paths', () {
    const hosts = {'app.example.com'};
    expect(
      parse('https://app.example.com/auth?token=$token', hosts: hosts)?.kind,
      LinkKind.resetPassword,
    );
    expect(
      parse(
        'https://app.example.com/join-space?token=$token',
        hosts: hosts,
      )?.kind,
      LinkKind.invite,
    );
    expect(
      parse('https://evil.example.net/auth?token=$token', hosts: hosts),
      isNull,
    );
    expect(
      parse('http://app.example.com/auth?token=$token', hosts: hosts),
      isNull,
    );
    expect(
      parse('https://app.example.com:8443/auth?token=$token', hosts: hosts),
      isNull,
    );
    expect(
      parse('https://user@app.example.com/auth?token=$token', hosts: hosts),
      isNull,
    );
    expect(
      parse('https://app.example.com/settings?token=$token', hosts: hosts),
      isNull,
    );
  });

  test(
    'rejects missing, duplicated, short or malformed tokens and unknown destinations',
    () {
      for (final link in [
        'teia-dev://reset-password',
        'teia-dev://reset-password?token=short',
        'teia-dev://reset-password?token=$token&token=$token',
        'teia-dev://reset-password?token=${'x' * 300}',
        'teia-dev://reset-password?token=abc%20def%3Cscript%3Eabcdefgh',
        'teia-dev://unknown?token=$token',
        'teia-dev://home',
      ]) {
        expect(parse(link), isNull, reason: link);
      }
    },
  );

  test('pasted text accepts a bare token or a link of the right kind only', () {
    expect(tokenFromPastedText('  $token  ', LinkKind.resetPassword), token);
    expect(
      tokenFromPastedText(
        'http://localhost:5174/auth?token=$token',
        LinkKind.resetPassword,
      ),
      token,
    );
    expect(
      tokenFromPastedText(
        'https://any.example/join-space?token=$token',
        LinkKind.invite,
      ),
      token,
    );
    expect(
      tokenFromPastedText(
        'https://any.example/join-space?token=$token',
        LinkKind.resetPassword,
      ),
      isNull,
    );
    expect(tokenFromPastedText('not a link', LinkKind.invite), isNull);
  });
}
