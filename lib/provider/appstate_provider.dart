// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:hooks_riverpod/hooks_riverpod.dart';

final optionalboolProvider = StateProvider<bool>((ref) => false);
final forceboolProvider = StateProvider<bool>((ref) => false);
final maintenanceboolProvider = StateProvider<bool>((ref) => false);

final reviewProvider = StateProvider<bool>((ref) => false);
