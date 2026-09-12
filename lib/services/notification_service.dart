import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static Future<void> init() async {
    // Initialization logic if needed
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
