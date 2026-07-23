import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/legal_pages.dart';

// ── Consent controls ────────────────────────────────────────────────────────
//
// Shared by every place the user has to actively agree to something before
// continuing: the sign-in form, the create-account form, and the one-off gate
// shown to already-signed-in users after a legal update.

/// A square tick box with a label, styled to match the sign-in form. Tapping
/// anywhere on the row toggles it.
class ConsentTickBox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Rendered to the right of the box — plain [Text] or a [RichText] with
  /// tappable links.
  final Widget label;

  const ConsentTickBox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: value ? kAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? kAccent : kTextSecondary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: value ? Icon(Icons.check_rounded, size: 14, color: kOnAccent) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: label),
        ],
      ),
    );
  }
}

/// The mandatory "I have read and agree to the Terms & Conditions and Privacy
/// Policy" tick box, with both documents opening in place from the label.
class LegalAgreementCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const LegalAgreementCheckbox({super.key, required this.value, required this.onChanged});

  @override
  State<LegalAgreementCheckbox> createState() => _LegalAgreementCheckboxState();
}

class _LegalAgreementCheckboxState extends State<LegalAgreementCheckbox> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms   = TapGestureRecognizer()..onTap = () => _open(const TermsPage());
    _privacy = TapGestureRecognizer()..onTap = () => _open(const PrivacyPolicyPage());
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final link = TextStyle(color: kAccent, fontWeight: FontWeight.w700);
    return ConsentTickBox(
      value: widget.value,
      onChanged: widget.onChanged,
      label: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.45),
          children: [
            const TextSpan(text: 'I have read and agree to the '),
            TextSpan(text: 'Terms & Conditions', style: link, recognizer: _terms),
            const TextSpan(text: ' and '),
            TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}

/// The explicit opt-in for recording physical metrics, sleep, and fatigue.
/// Deliberately separate from the legal agreement above so consent to tracking
/// is given (and can be withheld) on its own.
class TrackingConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const TrackingConsentCheckbox({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ConsentTickBox(
      value: value,
      onChanged: onChanged,
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'I agree to SolidCore recording my physical metrics, sleep, and fatigue.',
            style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.45),
          ),
          const SizedBox(height: 3),
          Text(
            'Optional. You can change this any time in Privacy & Security.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Compact confirmation shown on the sign-in form once the current version of
/// the documents has already been accepted — acceptance is one-time, so the
/// tick box is not asked for again unless [kLegalVersion] is bumped.
class LegalAcceptedNotice extends StatefulWidget {
  final DateTime? acceptedAt;
  const LegalAcceptedNotice({super.key, this.acceptedAt});

  @override
  State<LegalAcceptedNotice> createState() => _LegalAcceptedNoticeState();
}

class _LegalAcceptedNoticeState extends State<LegalAcceptedNotice> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms   = TapGestureRecognizer()..onTap = () => _open(const TermsPage());
    _privacy = TapGestureRecognizer()..onTap = () => _open(const PrivacyPolicyPage());
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final at = widget.acceptedAt;
    final link = TextStyle(color: kAccent, fontWeight: FontWeight.w700);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_outlined, size: 16, color: kAccent),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
              children: [
                TextSpan(text: at == null ? 'Accepted — ' : 'Accepted on ${_fmt(at)} — '),
                TextSpan(text: 'Terms', style: link, recognizer: _terms),
                const TextSpan(text: ' · '),
                TextSpan(text: 'Privacy', style: link, recognizer: _privacy),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
