import 'package:PiliPlus/pages/login/geetest/login_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const old = (gt: 'retired', challenge: 'old-challenge', token: 'old-token');
  const fresh = (gt: 'current', challenge: 'new-challenge', token: 'new-token');
  final missing = GeetestFailure.provider('-50', {
    'metadata': '{"error_code":"error_34"}',
  });

  test(
    'SMS retries a rejected registration with the complete fresh tuple',
    () async {
      final calls = <String>[];
      final result = await verifySmsChallenge(
        initial: old,
        register: () async {
          calls.add('register');
          return fresh;
        },
        verify: (gt, challenge) async {
          calls.add('$gt/$challenge');
          if (gt == old.gt) throw missing;
          return {
            'geetest_challenge': 'solved',
            'geetest_validate': 'validate',
            'geetest_seccode': 'seccode',
          };
        },
      );
      expect(calls, [
        'retired/old-challenge',
        'register',
        'current/new-challenge',
      ]);
      expect(result, (
        token: 'new-token',
        challenge: 'solved',
        validate: 'validate',
        seccode: 'seccode',
      ));
    },
  );

  test('closing the challenge does not submit a proof or reopen it', () async {
    final result = await verifySmsChallenge(
      initial: old,
      register: () => fail('unexpected refresh'),
      verify: (_, _) async => null,
    );
    expect(result, isNull);
  });

  test('a fresh registration failure stops after one refresh', () async {
    var registrations = 0;
    await expectLater(
      verifySmsChallenge(
        initial: old,
        register: () async {
          registrations++;
          return fresh;
        },
        verify: (_, _) async => throw missing,
      ),
      throwsA(isA<GeetestFailure>()),
    );
    expect(registrations, 1);
  });

  test('network errors and incomplete proofs cannot authorize SMS', () async {
    for (final fails in [true, false]) {
      await expectLater(
        verifySmsChallenge(
          initial: fresh,
          register: () => fail('unexpected refresh'),
          verify: (_, _) async {
            if (fails) throw GeetestFailure.provider('-1009', 'offline');
            return {'geetest_validate': 'incomplete'};
          },
        ),
        throwsA(isA<GeetestFailure>()),
      );
    }
    expect(readLoginChallenge({'gee_gt': 'g', 'gee_challenge': 'c'}), isNull);
  });
}
