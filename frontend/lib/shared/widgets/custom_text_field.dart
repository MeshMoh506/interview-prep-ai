// lib/shared/widgets/custom_text_field.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final int maxLines;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.maxLines = 1,
  });

  @override
  State<CustomTextField> createState() => _S();
}

class _S extends State<CustomTextField> {
  final _focus = FocusNode();
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _focused
              ? [
                  BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : []),
      child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          focusNode: _focus,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.ink),
          decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: _focused ? AppTheme.surface : const Color(0xFFF9FAFB),
              labelStyle: TextStyle(
                  color: _focused ? AppTheme.primary : AppTheme.inkLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              hintStyle:
                  const TextStyle(color: AppTheme.inkLight, fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.danger)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.danger, width: 2)))));
}
