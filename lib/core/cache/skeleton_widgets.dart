import 'package:flutter/material.dart';

class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key, this.cardCount = 4});
  final int cardCount;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: cardCount,
    itemBuilder: (_, i) => const Card(
      margin: EdgeInsets.all(8),
      child: SizedBox(height: 100),
    ),
  );
}
