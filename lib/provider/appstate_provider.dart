import 'package:hooks_riverpod/hooks_riverpod.dart';

final optionalboolProvider = StateProvider<bool>((ref) => false);
final forceboolProvider = StateProvider<bool>((ref) => false);
final maintenanceboolProvider = StateProvider<bool>((ref) => false);

final reviewProvider = StateProvider<bool>((ref) => false);