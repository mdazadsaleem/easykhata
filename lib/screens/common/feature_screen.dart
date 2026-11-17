import 'package:flutter/material.dart';

class FeatureScreen extends StatelessWidget {
  const FeatureScreen(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text('$title is ready.')),
  );
}
