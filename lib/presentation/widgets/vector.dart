import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Vector extends StatelessWidget {
  final String asset;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Color? color;
  final BlendMode blend;
  final String? package;
  final String? semanticsLabel;

  const Vector(
    this.asset, {
    super.key,
    this.height,
    this.width,
    this.color,
    this.fit = BoxFit.contain,
    this.blend = BlendMode.srcIn,
    this.package,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: ColorFilter.mode(color ?? Theme.of(context).iconTheme.color!, blend),
      package: package,
      semanticsLabel: semanticsLabel,
    );
  }
}
