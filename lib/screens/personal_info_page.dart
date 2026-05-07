import 'package:flutter/material.dart';

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
  late TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

  String _selectedSport = 'Running';
  final _sports = ['Running', 'Cycling', 'Swimming', 'Triathlon', 'Weightlifting'];

  @override
  void initState() {
    super.initState();
    final parts = widget.name.trim().split(' ');
    _firstNameCtrl = TextEditingController(text: parts.isNotEmpty ? parts[0] : '');
    _lastNameCtrl  = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _emailCtrl     = TextEditingController(text: widget.email);
    _phoneCtrl     = TextEditingController(text: '+1 (555) 012-3456');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    Navigator.pop(context, {'name': fullName, 'email': _emailCtrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Personal info'),
        scrolledUnderElevation: 0,
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      (_firstNameCtrl.text.isNotEmpty ? _firstNameCtrl.text[0] : '?').toUpperCase(),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: cs.primary, shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _FieldGroup(children: [
              _Field(label: 'First name', controller: _firstNameCtrl,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              _Field(label: 'Last name', controller: _lastNameCtrl,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              _Field(label: 'Email', controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
              _Field(label: 'Phone', controller: _phoneCtrl, keyboardType: TextInputType.phone),
            ]),
            const SizedBox(height: 16),

            _FieldGroup(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sport', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSport,
                        isExpanded: true,
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                        items: _sports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedSport = v!),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  final List<Widget> children;
  const _FieldGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: List.generate(children.length, (i) => Column(
          children: [
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: cs.outlineVariant),
          ],
        )),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({required this.label, required this.controller, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              isDense: true, border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}