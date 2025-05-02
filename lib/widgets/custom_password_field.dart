import 'package:flutter/material.dart';
import '../services/input_service.dart';

class CustomPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final String? errorText;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;
  final void Function(String)? onChanged;
  final bool autofocus;

  const CustomPasswordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.labelText,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.onEditingComplete,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<CustomPasswordField> createState() => _CustomPasswordFieldState();
}

class _CustomPasswordFieldState extends State<CustomPasswordField> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _isObscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      style: const TextStyle(color: Colors.white),
      onTap: () {
        if (!widget.focusNode.hasFocus) {
          widget.focusNode.requestFocus();
        }
      },
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: (_) {
        if (widget.onEditingComplete != null) {
          widget.onEditingComplete!();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      onChanged: widget.onChanged,
      decoration: InputService.getPasswordInputDecoration(
        labelText: widget.labelText,
        isObscure: _isObscure,
        toggleObscure: () {
          setState(() {
            _isObscure = !_isObscure;
          });
        },
        errorText: widget.errorText,
      ),
    );
  }
} 