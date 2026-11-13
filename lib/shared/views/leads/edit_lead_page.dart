import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/models/lead_model.dart';
import 'package:quickboom_crm_customer/shared/models/social_media_model.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/leads_viewmodel.dart';

/// Full-screen editor for an existing lead. Every field already stored on the
/// lead is shown in one scrolling column and saved through the existing update API.
class EditLeadPage extends ConsumerStatefulWidget {
  final LeadModel lead;
  const EditLeadPage({super.key, required this.lead});

  @override
  ConsumerState<EditLeadPage> createState() => _EditLeadPageState();
}

class _EditLeadPageState extends ConsumerState<EditLeadPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _company;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _category;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _country;
  late final TextEditingController _source;
  late final TextEditingController _value;
  late final TextEditingController _team;
  late final TextEditingController _followUpDate;
  late final TextEditingController _followUpTime;
  late final TextEditingController _workStart;
  late final TextEditingController _workNotes;
  late final TextEditingController _notes;
  late final Map<String, TextEditingController> _social;
  late String _priority;
  bool _saving = false;

  static const _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

  @override
  void initState() {
    super.initState();
    final lead = widget.lead;
    final social = lead.socialMedia is SocialMediaModel ? lead.socialMedia as SocialMediaModel : null;
    _company = TextEditingController(text: lead.companyName);
    _firstName = TextEditingController(text: lead.firstName ?? '');
    _lastName = TextEditingController(text: lead.lastName ?? '');
    _phone = TextEditingController(text: lead.phone ?? '');
    _email = TextEditingController(text: lead.email ?? '');
    _website = TextEditingController(text: lead.website ?? '');
    _category = TextEditingController(text: lead.category ?? '');
    _address = TextEditingController(text: lead.address ?? '');
    _city = TextEditingController(text: lead.city ?? '');
    _state = TextEditingController(text: lead.state ?? '');
    _pincode = TextEditingController(text: lead.pincode ?? '');
    _country = TextEditingController(text: lead.country ?? '');
    _source = TextEditingController(text: lead.source);
    _value = TextEditingController(text: lead.value == null ? '' : lead.value!.toString());
    _team = TextEditingController(text: lead.assignedTeam ?? '');
    _followUpDate = TextEditingController(text: _dateOnly(lead.nextFollowUpDate));
    _followUpTime = TextEditingController(text: _timeOnly(lead.nextFollowUpTime));
    _workStart = TextEditingController(text: _dateOnly(lead.workStartDate));
    _workNotes = TextEditingController(text: lead.workNotes ?? '');
    _notes = TextEditingController(text: lead.notes ?? '');
    _priority = _priorities.contains((lead.priority ?? '').toUpperCase()) ? lead.priority!.toUpperCase() : (lead.priority ?? 'MEDIUM');
    if (!_priorities.contains(_priority)) _priority = 'MEDIUM';
    _social = {
      'instagram': TextEditingController(text: social?.instagram ?? ''),
      'facebook': TextEditingController(text: social?.facebook ?? ''),
      'linkedin': TextEditingController(text: social?.linkedin ?? ''),
      'twitter': TextEditingController(text: social?.twitter ?? ''),
      'youtube': TextEditingController(text: social?.youtube ?? ''),
      'tiktok': TextEditingController(text: social?.tiktok ?? ''),
      'pinterest': TextEditingController(text: social?.pinterest ?? ''),
      'whatsapp': TextEditingController(text: social?.whatsapp ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in [
      _company, _firstName, _lastName, _phone, _email, _website, _category,
      _address, _city, _state, _pincode, _country, _source, _value, _team,
      _followUpDate, _followUpTime, _workStart, _workNotes, _notes, ..._social.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _dateOnly(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.length >= 10) return value.substring(0, 10);
    return value;
  }

  String _timeOnly(String? raw) {
    final value = raw?.trim() ?? '';
    final match = RegExp(r'(\d{2}:\d{2})').firstMatch(value);
    return match?.group(1) ?? value;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = DateTime.tryParse(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().substring(0, 10);
      setState(() {});
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 11,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
      setState(() {});
    }
  }

  Map<String, dynamic> _changes() {
    final lead = widget.lead;
    final social = lead.socialMedia is SocialMediaModel ? lead.socialMedia as SocialMediaModel : null;
    final payload = <String, dynamic>{};
    void text(String key, TextEditingController controller, String original) {
      final next = controller.text.trim();
      if (next != original.trim()) payload[key] = next;
    }

    text('companyName', _company, lead.companyName);
    if (payload.containsKey('companyName')) payload['title'] = _company.text.trim();
    text('firstName', _firstName, lead.firstName ?? '');
    text('lastName', _lastName, lead.lastName ?? '');
    text('phone', _phone, lead.phone ?? '');
    text('email', _email, lead.email ?? '');
    text('website', _website, lead.website ?? '');
    text('category', _category, lead.category ?? '');
    text('address', _address, lead.address ?? '');
    text('city', _city, lead.city ?? '');
    text('state', _state, lead.state ?? '');
    text('pincode', _pincode, lead.pincode ?? '');
    text('country', _country, lead.country ?? '');
    text('source', _source, lead.source);
    text('assignedTeam', _team, lead.assignedTeam ?? '');
    text('nextFollowUpDate', _followUpDate, _dateOnly(lead.nextFollowUpDate));
    text('nextFollowUpTime', _followUpTime, _timeOnly(lead.nextFollowUpTime));
    text('workStartDate', _workStart, _dateOnly(lead.workStartDate));
    text('workNotes', _workNotes, lead.workNotes ?? '');
    text('notes', _notes, lead.notes ?? '');
    final nextValue = double.tryParse(_value.text.trim());
    if ((nextValue ?? -1) != (lead.value ?? -1) && _value.text.trim() != (lead.value?.toString() ?? '')) {
      if (nextValue != null) payload['value'] = nextValue;
    }
    if (_priority != (lead.priority ?? 'MEDIUM').toUpperCase()) payload['priority'] = _priority;

    final socialPayload = <String, String>{};
    void socialText(String key, String original) {
      final next = _social[key]!.text.trim();
      if (next != original.trim()) socialPayload[key] = next;
    }
    socialText('instagram', social?.instagram ?? '');
    socialText('facebook', social?.facebook ?? '');
    socialText('linkedin', social?.linkedin ?? '');
    socialText('twitter', social?.twitter ?? '');
    socialText('youtube', social?.youtube ?? '');
    socialText('tiktok', social?.tiktok ?? '');
    socialText('pinterest', social?.pinterest ?? '');
    socialText('whatsapp', social?.whatsapp ?? '');
    if (socialPayload.isNotEmpty) payload['socialMedia'] = socialPayload;
    return payload;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final payload = _changes();
    if (payload.isEmpty) {
      Navigator.pop(context, widget.lead);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await ref.read(leadsProvider.notifier).updateLead(widget.lead.id, payload);
      if (!mounted) return;
      AppToast.success(context, 'Lead updated');
      Navigator.pop(context, updated ?? widget.lead);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text('Edit Lead', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _section('Basic information'),
            _field('Lead / business name', _company, required: true),
            _field('First name', _firstName, textCapitalization: TextCapitalization.words),
            _field('Last name', _lastName, textCapitalization: TextCapitalization.words),
            _field('Phone number', _phone, keyboard: TextInputType.phone),
            _field('Email', _email, keyboard: TextInputType.emailAddress, validator: _emailRule),
            _field('Website', _website, keyboard: TextInputType.url),
            _field('Business category', _category),
            _section('Business address'),
            _field('Address', _address, maxLines: 3),
            _field('City', _city),
            _field('State', _state),
            _field('Pincode', _pincode, keyboard: TextInputType.number),
            _field('Country', _country),
            _readOnly('Location coordinates', _coordinates()),
            _section('Lead information'),
            _field('Lead source', _source),
            _readOnly('Pipeline stage', widget.lead.stage?.name ?? widget.lead.status),
            _priorityField(),
            _field('Lead value', _value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _readOnly('Assigned employee', widget.lead.assignedToName ?? 'Unassigned'),
            _field('Assigned team', _team),
            _pickerField('Next follow-up date', _followUpDate, () => _pickDate(_followUpDate)),
            _pickerField('Next follow-up time', _followUpTime, () => _pickTime(_followUpTime)),
            _section('Work and additional details'),
            _pickerField('Work start date', _workStart, () => _pickDate(_workStart)),
            _field('Work notes', _workNotes, maxLines: 4),
            _field('Notes', _notes, maxLines: 4),
            _section('Social media'),
            _field('Instagram', _social['instagram']!),
            _field('Facebook', _social['facebook']!),
            _field('LinkedIn', _social['linkedin']!),
            _field('X / Twitter', _social['twitter']!),
            _field('YouTube', _social['youtube']!),
            _field('TikTok', _social['tiktok']!),
            _field('Pinterest', _social['pinterest']!),
            _field('WhatsApp', _social['whatsapp']!, keyboard: TextInputType.phone),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom > 0 ? 12 : 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save changes', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _coordinates() {
    final lead = widget.lead;
    if (lead.latitude == null && lead.longitude == null) return 'Not set';
    return '${lead.latitude ?? '—'}, ${lead.longitude ?? '—'}';
  }

  String? _emailRule(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.3)),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    int maxLines = 1,
    bool required = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        scrollPadding: const EdgeInsets.only(bottom: 120),
        validator: validator ?? (required ? (value) => (value ?? '').trim().isEmpty ? 'Business name is required' : null : null),
        style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF111827)),
        decoration: _decoration(label),
      ),
    );
  }

  Widget _pickerField(String label, TextEditingController controller, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF111827)),
        decoration: _decoration(label),
      ),
    );
  }

  Widget _priorityField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _priorities.contains(_priority) ? _priority : 'MEDIUM',
        isExpanded: true,
        items: _priorities.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _priority = value);
        },
        decoration: _decoration('Priority'),
      ),
    );
  }

  Widget _readOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: _decoration(label),
        child: Text(value.isEmpty ? '—' : value, style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF334155))),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16A34A))),
    );
  }
}
