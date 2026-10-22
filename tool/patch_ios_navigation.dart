import 'dart:convert';
import 'dart:io';

/// Apply only our local GetX route fix; safe to run after every pub get.
void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final config = File('${root.path}/.dart_tool/package_config.json');
  final packages =
      (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
  final get = packages.cast<Map>().singleWhere(
    (package) => package['name'] == 'get',
  );
  final packageRoot = Directory.fromUri(
    config.uri.resolve(get['rootUri'] as String),
  );
  final patch = '${root.path}/lib/scripts/get/ios_navigation.patch';
  ProcessResult git(List<String> args) => Process.runSync(
    'git',
    ['apply', ...args, patch],
    workingDirectory: packageRoot.path,
  );
  if (git(['--reverse', '--check']).exitCode == 0) {
    stdout.writeln('iOS navigation patch already applied.');
    return;
  }
  final check = git(['--check']);
  if (check.exitCode != 0) {
    stderr.write(check.stderr);
    exitCode = 1;
    return;
  }
  final result = git([]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exitCode = 1;
    return;
  }
  stdout.writeln('Applied iOS navigation patch to the resolved GetX package.');
}
