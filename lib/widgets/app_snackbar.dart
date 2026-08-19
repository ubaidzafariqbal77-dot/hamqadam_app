import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Consistent, friendly snackbars. Never surfaces raw exceptions.
class AppSnackbar {
  const AppSnackbar._();

  static void _show(String message, Color color, IconData icon) {
    // An empty message would show an icon and a blank bar — worse than nothing.
    // Callers pass server text straight through, which is sometimes empty.
    if (message.trim().isEmpty) return;
    if (Get.isSnackbarOpen) Get.closeAllSnackbars();
    Get.rawSnackbar(
      messageText: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white, size: AppDimensions.iconMd),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      borderRadius: AppRadius.md,
      margin: const EdgeInsets.all(AppSpacing.md),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 350),
    );
  }

  static void success(String message) =>
      _show(message, AppColors.success, Icons.check_circle_rounded);

  static void error(String message) => _show(message, AppColors.error, Icons.error_rounded);

  static void info(String message) => _show(message, AppColors.info, Icons.info_rounded);
}
