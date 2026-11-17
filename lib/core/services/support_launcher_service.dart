import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportLauncherService {
  static const supportEmail = 'support@smartkhata.app';
  static const _whatsAppNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP_NUMBER',
  );

  Future<Map<String, String>> privacySafeDeviceInfo() async {
    final package = await PackageInfo.fromPlatform();
    final platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    return {
      'appVersion': package.version,
      'buildNumber': package.buildNumber,
      'platform': platform,
      'operatingSystem': kIsWeb ? 'web' : Platform.operatingSystem,
      'locale': WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
    };
  }

  Future<bool> openWhatsApp() async {
    final info = await privacySafeDeviceInfo();
    final message =
        'Hello Smart Khata Support,\n\n'
        'I need help with the app.\n\n'
        'App: ${info['appVersion']} (${info['buildNumber']})\n'
        'Platform: ${info['platform']}';
    final number = _whatsAppNumber.replaceAll(RegExp(r'\D'), '');
    final uri = number.isEmpty
        ? Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}')
        : Uri.parse(
            'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
          );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openEmail({String subject = 'Smart Khata Support'}) async {
    final info = await privacySafeDeviceInfo();
    final body =
        '\n\n'
        '--- App information ---\n'
        'Version: ${info['appVersion']} (${info['buildNumber']})\n'
        'Platform: ${info['platform']}\n'
        'OS: ${info['operatingSystem']}\n'
        'Locale: ${info['locale']}';
    return launchUrl(
      Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: {'subject': subject, 'body': body},
      ),
    );
  }

  Future<String> appVersion() async {
    final package = await PackageInfo.fromPlatform();
    return '${package.version}+${package.buildNumber}';
  }
}
