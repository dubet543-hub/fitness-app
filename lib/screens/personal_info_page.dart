import 'package:flutter/material.dart';
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    Navigator.pop(context, {'name': fullName, 'email': _emailCtrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('PERSONAL INFO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: const IconThemeData(color: kTextPrimary),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Avatar ───────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kAccent, width: 2),
                      color: kCard,
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: kAccent, shape: BoxShape.circle,
                        border: Border.all(color: kBg, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Fields ───────────────────────────────────────────
            const _FieldLabel('FIRST NAME'),
            const SizedBox(height: 6),
            _FormField(
              controller: _firstNameCtrl,
              hint: 'First name',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            const _FieldLabel('LAST NAME'),
            const SizedBox(height: 6),
            _FormField(
              controller: _lastNameCtrl,
              hint: 'Last name',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            const _FieldLabel('EMAIL'),
            const SizedBox(height: 6),
            _FormField(
              controller: _emailCtrl,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),

            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 32),
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
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2),
  );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({required this.controller, required this.hint, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: kTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kAccent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
