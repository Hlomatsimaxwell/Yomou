import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:yomou/core/theme/amoled.dart';

/// The single shared search bar look used across the app: a rounded pill with
/// a leading search icon, a hint/text field, and an optional clear button.
///
/// Use [YomouSearchBar.tappable] for a non-editable bar that opens a search
/// screen, and [YomouSearchBar.text] for a real input field.
class YomouSearchBar extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final bool autofocus;
  final VoidCallback? onTap;
  final bool clearVisible;
  final VoidCallback? onClear;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;
  final double height;

  const YomouSearchBar.tappable({
    super.key,
    required this.hintText,
    required this.onTap,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.height = 56,
  })  : controller = null,
        onChanged = null,
        onSubmitted = null,
        textInputAction = TextInputAction.search,
        autofocus = false,
        clearVisible = false,
        onClear = null;

  const YomouSearchBar.text({
    super.key,
    required this.hintText,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.search,
    this.autofocus = false,
    this.clearVisible = false,
    this.onClear,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.height = 56,
  }) : onTap = null;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white70 : Colors.black54;
    final hintColor = dark ? Colors.white54 : Colors.black54;
    final fieldColor = dark ? Colors.white : const Color(0xFF1C1B1F);

    Widget field;
    if (controller != null) {
      field = TextField(
        controller: controller,
        autofocus: autofocus,
        style: TextStyle(color: fieldColor, fontSize: 16),
        cursorColor: fieldColor,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: hintColor, fontSize: 16),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      );
    } else {
      field = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          hintText,
          style: TextStyle(color: hintColor, fontSize: 16),
        ),
      );
    }

    Widget child = Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(MdiIcons.magnify, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: field,
            ),
          ),
        ),
        if (clearVisible)
          IconButton(
            icon: Icon(MdiIcons.close, color: iconColor, size: 20),
            onPressed: onClear,
          )
        else if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: trailing,
          )
        else
          const SizedBox(width: 16),
      ],
    );

    if (onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return Container(
      margin: margin,
      height: height,
      decoration: BoxDecoration(
        color: dark ? amoled(context, 0xFF2C2C2E) : const Color(0xFFEBEFEF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}