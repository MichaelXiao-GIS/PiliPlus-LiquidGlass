/// Keep the registration token paired with the challenge that issued it.
typedef LoginChallenge = ({String gt, String challenge, String token});
typedef SmsCaptchaProof = ({
  String token,
  String challenge,
  String validate,
  String seccode,
});

LoginChallenge? readLoginChallenge(Object? data) {
  if (data
      case {
        'gee_gt': String gt,
        'gee_challenge': String challenge,
        'recaptcha_token': String token,
      }
      when gt.isNotEmpty && challenge.isNotEmpty && token.isNotEmpty) {
    return (gt: gt, challenge: challenge, token: token);
  }
  return null;
}

class GeetestFailure implements Exception {
  const GeetestFailure({this.registrationRejected = false});

  factory GeetestFailure.provider(Object? code, Object? detail) {
    final message = detail.toString().toLowerCase();
    return GeetestFailure(
      registrationRejected:
          code.toString() == '-21' ||
          message.contains('error_34') ||
          message.contains('captcha not found') ||
          message.contains('old challenge'),
    );
  }

  final bool registrationRejected;
  String get message =>
      registrationRejected ? '验证已失效，请重新获取验证码' : '人机验证加载失败，请稍后重试';
}

/// The SMS endpoint can return an obsolete registration. Ask the passport
/// service for one fresh registration and verify it before submitting the SMS.
Future<SmsCaptchaProof?> verifySmsChallenge({
  required LoginChallenge? initial,
  required Future<LoginChallenge?> Function() register,
  required Future<Map<String, dynamic>?> Function(String, String) verify,
}) async {
  var current = initial ?? await register();
  if (current == null) throw const GeetestFailure();
  Map<String, dynamic>? result;
  try {
    result = await verify(current.gt, current.challenge);
  } on GeetestFailure catch (error) {
    if (!error.registrationRejected || initial == null) rethrow;
    current = await register();
    if (current == null) throw const GeetestFailure();
    result = await verify(current.gt, current.challenge);
  }
  if (result == null) return null; // The user closed verification.
  if (result
      case {
        'geetest_challenge': String challenge,
        'geetest_validate': String validate,
        'geetest_seccode': String seccode,
      }
      when challenge.isNotEmpty && validate.isNotEmpty && seccode.isNotEmpty) {
    return (
      token: current.token,
      challenge: challenge,
      validate: validate,
      seccode: seccode,
    );
  }
  throw const GeetestFailure();
}
