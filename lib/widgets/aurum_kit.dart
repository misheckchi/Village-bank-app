import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

/// Standard surface: navy gradient, 1px gold-tinted hairline, radius 20,
/// deep soft shadow. Set [hero] for the balance card (stronger border + halo).
class AurumCard extends StatelessWidget {
  const AurumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.hero = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: hero ? const Color(0x66C9A24B) : const Color(0x26C9A24B),
          width: hero ? 1.2 : 1,
        ),
        boxShadow: hero ? AppShadows.cardGold : AppShadows.card,
      ),
      child: child,
    );
  }
}

/// Primary CTA: gold gradient, midnight label, gold drop-shadow.
/// Tap state = darker gradient + scale 0.98 (deliberate, no ripple).
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final bool expand;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _down = false;

  bool get _enabled => !widget.loading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: !_enabled && !widget.loading
                  ? AppGradients.disabled
                  : _down
                      ? AppGradients.goldPressed
                      : AppGradients.gold,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _enabled ? AppShadows.gold : null,
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: AppColors.midnight),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: AppColors.midnight),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: _enabled ? AppColors.midnight : AppColors.faint,
                        ),
                      ),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: transparent with gold hairline; press fills gold @ 8%.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _down ? const Color(0x14C9A24B) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: enabled ? const Color(0x59C9A24B) : AppColors.hairline,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 18,
                    color: enabled ? AppColors.gold : AppColors.faint),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.gold : AppColors.faint,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Text field wired to the theme's filled InputDecoration.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
    this.autofillHints,
    this.textInputAction,
    this.hintText,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final String? hintText;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      cursorColor: AppColors.gold,
      style: GoogleFonts.manrope(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ivory),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
