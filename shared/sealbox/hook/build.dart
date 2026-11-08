import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// Builds the Rust library for the target with cargo, or takes a prebuilt one
/// from `prebuilt/<rust triple>/` when that holds it, for machines without Rust.
void main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  final code = input.config.code;
  final triple = _rustTriple(code);
  final library = code.targetOS.dylibFileName('sealbox');
  final rust = input.packageRoot.resolve('rust/');

  final prebuilt = input.packageRoot.resolve('prebuilt/$triple/$library');
  final built = switch (File.fromUri(prebuilt).existsSync()) {
    true => prebuilt,
    false => await _cargo(input, code, triple, rust, library),
  };

  output.assets.code.add(
    CodeAsset(package: input.packageName, name: 'src/native.dart', linkMode: DynamicLoadingBundled(), file: built),
  );
  output.dependencies.addAll([
    rust.resolve('Cargo.toml'),
    rust.resolve('Cargo.lock'),
    rust.resolve('rust-toolchain.toml'),
    ...Directory.fromUri(rust.resolve('src/')).listSync(recursive: true).whereType<File>().map((file) => file.uri),
  ]);
});

Future<Uri> _cargo(BuildInput input, CodeConfig code, String triple, Uri rust, String library) async {
  final home = Platform.environment['HOME'] ?? '';
  final cargoHome = Platform.environment['CARGO_HOME'] ?? '$home/.cargo';
  final cargo = '$cargoHome/bin/cargo';
  if (!File(cargo).existsSync()) {
    throw Exception(
      'sealbox needs Rust to build for $triple: install it with rustup (https://rustup.rs), '
      'or put a prebuilt $library in prebuilt/$triple/.',
    );
  }

  // Nothing is inherited: Xcode's SDKROOT, for one, breaks linking cargo's own
  // build scripts for the host.
  final environment = {
    'HOME': home,
    'PATH': '$cargoHome/bin:/usr/bin:/bin:/usr/sbin:/sbin',
    'CARGO_HOME': cargoHome,
    'CARGO_TARGET_DIR': rust.resolve('target/').toFilePath(),
    'RUSTUP_HOME': ?Platform.environment['RUSTUP_HOME'],
    if (code.targetOS == OS.android) ..._androidLinker(code, triple),
  };

  final result = await Process.run(
    cargo,
    ['build', '--release', '--lib', '--locked', '--target', triple],
    workingDirectory: rust.toFilePath(),
    environment: environment,
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw Exception('cargo failed for $triple:\n${result.stdout}\n${result.stderr}');
  }
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
