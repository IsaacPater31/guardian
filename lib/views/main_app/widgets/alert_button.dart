import 'package:flutter/material.dart';

class AlertButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AlertButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(40),
        elevation: 6,
      ),
      child: const Icon(Icons.warning, color: Colors.white, size: 48),
    );
  }
}
