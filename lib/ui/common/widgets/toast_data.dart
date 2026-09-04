import 'package:flutter/material.dart';

class ToastData {
  const ToastData(
    this.key,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
  );

  final Key key;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
}
