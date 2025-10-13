import 'package:flutter/material.dart';
import 'package:guardian/generated/l10n/app_localizations.dart';

class ComunidadesView extends StatelessWidget {
  const ComunidadesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.communities,
        style: const TextStyle(fontSize: 24, color: Colors.black54),
      ),
    );
  }
}
