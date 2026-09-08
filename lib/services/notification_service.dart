import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static Future<void> init() async {
    // No external init needed for built-in tools
  }

  static void showNotification({
    required String title,
    required String body,
    bool isError = false,
  }) {
    final context = messengerKey.currentContext;
    if (context == null) return;

    // Play sound and vibration
    playTransactionSound();

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
      // Alert is usually louder than click
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();

      // Attempt to play a second sound shortly after if supported
      Future.delayed(const Duration(milliseconds: 200), () {
        SystemSound.play(SystemSoundType.click);
      });
    } catch (e) {
      debugPrint('Sound Error: $e');
    }
  }
}
