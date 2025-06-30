import 'package:flutter/material.dart';
import 'package:guardian/views/main_app/widgets/alert_button.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AlertButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Alerta enviada (placeholder)!')),
          );
        },
      ),
    );
  }
}
