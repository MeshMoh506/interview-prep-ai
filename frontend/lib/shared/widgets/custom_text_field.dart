import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final int? maxLines;
  final void Function(String)? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText    = false,
    this.keyboardType   = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.maxLines       = 1,
    this.onChanged,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final hintColor   = isDark ? AppColors.darkInk40    : AppColors.lightInk40;

    return TextFormField(
      controller:    widget.controller,
      obscureText:   _obscure,
      keyboardType:  widget.keyboardType,
      validator:     widget.validator,
      maxLines:      _obscure ? 1 : widget.maxLines,
      onChanged:     widget.onChanged,
      style: TextStyle(
        color: isDark ? AppColors.darkInk : AppColors.lightInk,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText:  widget.hint,
        hintStyle: TextStyle(color: hintColor),
        filled:     true,
        fillColor:  fillColor,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: hintColor,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
      ),
    );
  }
}
