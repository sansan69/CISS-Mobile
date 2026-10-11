import 'package:flutter/material.dart';

class ModuleUnavailableScreen extends StatelessWidget {
  const ModuleUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Not available')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "This feature isn't enabled for your account.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
