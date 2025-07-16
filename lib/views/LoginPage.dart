import 'package:debate_project/provider/app_config_provider.dart';
import 'package:debate_project/provider/app_config_service.dart';
import 'package:debate_project/provider/appstate_provider.dart';
import 'package:debate_project/provider/setting_provider.dart';
import 'package:debate_project/provider/user.dart'; // あなたのプロジェクトに合わせてください
import 'package:debate_project/view_model/Paypage_view_model.dart';
import 'package:debate_project/view_model/start_error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'; // flutter_hooksをインポート
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showErrorDialogFlag = useState<bool>(false);
    final showMainatenanceDialogFlag = useState<bool>(false);
    final showforceupdateDialogFlag = useState<bool>(false);
    final startnotifier = ref.read(startProvider.notifier);
    final inapppurchase = ref.read(inAppPurchaseManagerProvider.notifier);

    Future<void> attemptInit() async {
      await inapppurchase.initInAppPurchase();
      await ref.read(settingsProvider.notifier).loadSettings();
      final usernotifier = ref.read(userProvider.notifier);
      try {
        final appstate =
            await ref.read(appStateProvider.notifier).loadVersion();
        print(appstate);
        if (appstate == AppStatus.error) {
          FlutterNativeSplash.remove();
          showErrorDialogFlag.value = true;
          return;
        } else if (appstate == AppStatus.forceUpdate) {
          FlutterNativeSplash.remove();
          showforceupdateDialogFlag.value = true;
          return;
        } else if (appstate == AppStatus.maintenance) {
          FlutterNativeSplash.remove();
          showMainatenanceDialogFlag.value = true;
          return;
        } else if (appstate == AppStatus.optionalUpdate) {
          ref.read(optionalboolProvider.notifier).state = true;
        } else if (appstate == AppStatus.normal) {
        } else {
          FlutterNativeSplash.remove();
          showErrorDialogFlag.value = true;
          return;
        }

        await usernotifier.signinandname();
      } catch (e) {
        FlutterNativeSplash.remove();
        if (context.mounted) {
          showErrorDialogFlag.value = true;
        }
      }
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          attemptInit();
        }
      });
      return null;
    }, const []);

    useEffect(() {
      if (showMainatenanceDialogFlag.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && showMainatenanceDialogFlag.value) {
            showMainatenanceDialogFlag.value = false;
            startnotifier.showMaintenanceDialog(context, () {
              attemptInit();
            }, ref.read(appConfigProvider)?.maintenanceMessage ?? 'メンテナンス中です');
          }
        });
      }
      return null;
    }, [showMainatenanceDialogFlag.value]);

    useEffect(() {
      if (showErrorDialogFlag.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && showErrorDialogFlag.value) {
            showErrorDialogFlag.value = false;
            startnotifier.showErrorDialog(context, () {
              attemptInit();
            });
          }
        });
      }
      return null;
    }, [showErrorDialogFlag.value]);

    useEffect(() {
      if (showforceupdateDialogFlag.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && showforceupdateDialogFlag.value) {
            showforceupdateDialogFlag.value = false;
            startnotifier.showforceUpdateDialog(context);
          }
        });
      }
      return null;
    }, [showforceupdateDialogFlag.value]);

    return const Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: SizedBox(
          width: 230,
          height: 230,
          child: Image(
            image: AssetImage('assets/images/debateimage.png'),
          ),
        ),
      ),
    );
  }
}
