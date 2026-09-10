import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      final targetOS = input.config.code.targetOS;
      if (targetOS == OS.windows ||
          targetOS == OS.linux ||
          targetOS == OS.macOS) {
        final builder = RustBuilder(
          assetName: "src/hunspell_service.dart",
        );
        await builder.run(input: input, output: output);
      }
    }
  });
}
