import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'village_bank_system_channel';
  static const String channelName = 'Village Bank System Notifications';
  static const String channelDescription = 'Real-time alerts for deposits, loans, repayments, and updates.';

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );
  }

  static Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? false;
  }

  static Future<bool> hasPromptedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_prompted') ?? false;
  }

  static Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    await prefs.setBool('notifications_prompted', true);
  }

  static Future<void> requestOSPermission() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  static Future<bool?> showPermissionDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1E1E24),
          title: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: Color(0xFFBB86FC), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable Notifications?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'Would you like to receive instant push alerts for deposit approvals, loan disbursements, repayments, and updates?',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () async {
                await setNotificationEnabled(false);
                Navigator.of(ctx).pop(false);
              },
              child: const Text('Not Now', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBB86FC),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await setNotificationEnabled(true);
                await requestOSPermission();
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
    bool isError = false,
  }) async {
    final enabled = await isNotificationEnabled();
    if (!enabled) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Village Bank Alert',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    try {
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing system notification: $e');
    }

    // Dual display: Also show floating in-app snackbar
    showNotification(
      title: title,
      body: body,
      isError: isError,
    );
  }

  static void showNotification({
    required String title,
    required String body,
    bool isError = false,
  }) {
    final context = messengerKey.currentContext;
    if (context == null) return;

    // Play distinct sounds based on the status
    if (isError) {
      playErrorSound();
    } else {
      playTransactionSound();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isError ? Colors.redAccent : const Color(0xFF2D2D35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.notifications_active_outlined,
                color: isError ? Colors.white : const Color(0xFFBB86FC),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> playTransactionSound() async {
    try {
      // Modern "Success" pattern: Triple click with rising haptic intensity
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
      
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();

      await Future.delayed(const Duration(milliseconds: 150));
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Sound Error: $e');
    }
  }

  static Future<void> playErrorSound() async {
    try {
      // Modern "Error" pattern: Double sharp vibration
      await HapticFeedback.vibrate();
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Sound Error: $e');
    }
  }

  static Future<void> playClickSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Sound Error: $e');
    }
  }
}
