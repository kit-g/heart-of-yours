import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// Builds the Rust library for the target with cargo. A machine without Rust
/// takes a prebuilt one from `prebuilt/<rust triple>/` instead, and only then:
/// where cargo is there, the source is what ships, never a library that may
/// be older than it. macOS and Linux build hosts only.
void main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  if (Platform.isWindows) {
    throw UnsupportedError('sealbox builds on macOS and Linux hosts; Windows is not one yet');
  }
  final code = input.config.code;
  final triple = _rustTriple(code);
  final library = code.targetOS.dylibFileName('sealbox');
  final rust = input.packageRoot.resolve('rust/');
  final prebuilt = input.packageRoot.resolve('prebuilt/$triple/$library');

  final built = switch (_tools()) {
    final String tools => await _cargo(code, triple, rust, library, tools),
    null when File.fromUri(prebuilt).existsSync() => prebuilt,
    null => throw Exception(
      'sealbox needs Rust to build for $triple: install it with rustup (https://rustup.rs), '
      'or put a prebuilt $library in prebuilt/$triple/.',
    ),
  };

  output.assets.code.add(
    CodeAsset(package: input.packageName, name: 'src/native.dart', linkMode: DynamicLoadingBundled(), file: built),
  );
  output.dependencies.addAll([
    rust.resolve('Cargo.toml'),
    rust.resolve('Cargo.lock'),
    rust.resolve('rust-toolchain.toml'),
    ...Directory.fromUri(rust.resolve('src/')).listSync(recursive: true).whereType<File>().map((file) => file.uri),
    // added, replaced or removed, a prebuilt changes what ships
    prebuilt,
  ]);
});

String get _cargoHome => Platform.environment['CARGO_HOME'] ?? '${Platform.environment['HOME'] ?? ''}/.cargo';

/// Where cargo and rustup are, when they are installed: rustup's own place, or
/// Homebrew's, whose rustup puts nothing in it. GitHub's macOS images have only
/// the latter since November 2026.
String? _tools() {
  return [
    '$_cargoHome/bin',
    '/opt/homebrew/opt/rustup/bin',
    '/usr/local/opt/rustup/bin',
  ].where((each) => ['cargo', 'rustup'].every((tool) => File('$each/$tool').existsSync())).firstOrNull;
}

/// What cargo and rustup need to reach crates.io and the toolchains through
/// whatever network the machine has: proxies and certificate settings.
const _network = [
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'NO_PROXY',
  'ALL_PROXY',
  'http_proxy',
  'https_proxy',
  'no_proxy',
  'all_proxy',
  'SSL_CERT_FILE',
  'SSL_CERT_DIR',
  'CARGO_HTTP_CAINFO',
  'CARGO_HTTP_PROXY',
  'CARGO_REGISTRIES_CRATES_IO_PROTOCOL',
  'RUSTUP_DIST_SERVER',
  'RUSTUP_UPDATE_ROOT',
  'RUSTUP_HOME',
];

Future<Uri> _cargo(CodeConfig code, String triple, Uri rust, String library, String tools) async {
  final home = Platform.environment['HOME'] ?? '';

  // Built rather than inherited: Xcode's SDKROOT, for one, breaks linking
  // cargo's own build scripts for the host. Only the network settings come
  // through, so a machine behind a proxy can still fetch crates and targets.
  final environment = {
    'HOME': home,
    'PATH': '$tools:/usr/bin:/bin:/usr/sbin:/sbin',
    'CARGO_HOME': _cargoHome,
    'CARGO_TARGET_DIR': rust.resolve('target/').toFilePath(),
    for (final name in _network)
      if (Platform.environment[name] case final String value) name: value,
    if (code.targetOS == OS.android) ..._androidLinker(code, triple),
  };

  Future<void> run(String tool, List<String> arguments) async {
    final result = await Process.run(
      '$tools/$tool',
      arguments,
      workingDirectory: rust.toFilePath(),
      environment: environment,
      includeParentEnvironment: false,
    );
    if (result.exitCode != 0) {
      throw Exception('$tool failed for $triple:\n${result.stdout}\n${result.stderr}');
    }
  }

  // the pinned toolchain's standard library for this target only: a host that
  // never builds for a phone never downloads one
  await run('rustup', ['target', 'add', triple]);
  await run('cargo', ['build', '--release', '--lib', '--locked', '--target', triple]);
  return rust.resolve('target/$triple/release/$library');
}

/// The NDK's clang for this target and API level, next to the C compiler the
/// build hands every hook.
Map<String, String> _androidLinker(CodeConfig code, String triple) {
  final compiler = code.cCompiler?.compiler;
  if (compiler == null) throw Exception('sealbox: no C compiler configured for Android');
  final clangTriple = switch (triple) {
    'armv7-linux-androideabi' => 'armv7a-linux-androideabi',
    final other => other,
  };
  final linker = compiler.resolve('$clangTriple${code.android.targetNdkApi}-clang').toFilePath();
  return {'CARGO_TARGET_${triple.toUpperCase().replaceAll('-', '_')}_LINKER': linker};
}

String _rustTriple(CodeConfig code) => switch ((code.targetOS, code.targetArchitecture)) {
  (OS.iOS, Architecture.arm64) => switch (code.iOS.targetSdk) {
    IOSSdk.iPhoneSimulator => 'aarch64-apple-ios-sim',
    _ => 'aarch64-apple-ios',
  },
  (OS.iOS, Architecture.x64) => 'x86_64-apple-ios',
  (OS.android, Architecture.arm64) => 'aarch64-linux-android',
  (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
  (OS.android, Architecture.x64) => 'x86_64-linux-android',
  (OS.android, Architecture.ia32) => 'i686-linux-android',
  (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
  (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
  (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
  (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
  final other => throw UnsupportedError('sealbox has no build for $other'),
};
