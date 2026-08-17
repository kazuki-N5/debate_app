import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class FastPageScrollPhysics extends PageScrollPhysics {
  const FastPageScrollPhysics({super.parent});

  @override
  FastPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FastPageScrollPhysics(parent: buildParent(ancestor));
  }

  // フリック（スワイプ）と判定される速度のハードルを極限まで下げる
  @override
  Tolerance get tolerance => const Tolerance(
        velocity: 1.0, // ほぼ0の速度でもスワイプと判定し、完全に抵抗なしで次へ行く
        distance: 0.1, // 距離の判定も少しシャープに戻す
      );

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,       // 適度に軽く
        stiffness: 600.0, // バネが強すぎて強制的に戻される感覚を和らげる
        ratio: 1,      // 振動を抑える
      );
}
