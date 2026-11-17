import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.prefixText,
    this.maxLines = 1,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final String? prefixText;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label, prefixText: prefixText),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {this.icon = Icons.inbox_outlined, super.key});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.empty,
    super.key,
  });
  final AsyncSnapshot<T> value;
  final Widget Function(T) data;
  final Widget? empty;
  @override
  Widget build(BuildContext context) {
    if (value.hasError) return Center(child: Text('Error: ${value.error}'));
    if (!value.hasData) return const Center(child: CircularProgressIndicator());
    return data(value.requireData);
  }
}
