import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';

class PersonalInfoPage extends StatefulWidget {
  final String name;
  final String email;

  const PersonalInfoPage({super.key, required this.name, required this.email});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final parts      = widget.name.trim().split(' ');
    _firstNameCtrl = TextEditingController(text: parts.isNotEmpty ? parts[0] : '');
    _lastNameCtrl  = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _emailCtrl     = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    if (f.isEmpty) return '?';
    return (f[0] + (l.isNotEmpty ? l[0] : '')).toUpperCase();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(name: fullName); // persists to backend + cache
      if (!mounted) return;
      Navigator.pop(context, {'name': fullName, 'email': _emailCtrl.text.trim()});
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Personal info'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () { hapticConfirm(); _save(); },
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
          children: [
            // ── Avatar ───────────────────────────────────────────
            Center(
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderBright, width: 1),
                  color: kCard,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Fields ───────────────────────────────────────────
            const _FieldLabel('First name'),
            _FormField(
              controller: _firstNameCtrl,
              hint: 'First name',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('Last name'),
            _FormField(
              controller: _lastNameCtrl,
              hint: 'Last name',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('Email'),
            _FormField(
              controller: _emailCtrl,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              enabled: false,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Email can\'t be changed here — contact support to update it.',
                  style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.4)),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () { hapticConfirm(); _save(); },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
    ),
  );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;

  const _FormField({required this.controller, required this.hint, this.keyboardType, this.validator, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    // Filled kCard, radius 12 and hairline borders come from the theme; only
    // the read-only state is tuned so it reads as clearly non-editable.
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      style: TextStyle(fontSize: 16, color: enabled ? kTextPrimary : kTextSecondary),
      decoration: InputDecoration(
        hintText: hint,
        fillColor: enabled ? kCard : kCardAlt,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
          borderSide: const BorderSide(color: kBorder, width: 0.6),
        ),
      ),
    );
  }
}
