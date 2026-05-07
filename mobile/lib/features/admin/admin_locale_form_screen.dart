import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../locales/data/locale_models.dart';
import '../locales/data/locales_api.dart';
import '../locales/locales_controller.dart';
import '../recommendations/data/recommendations_api.dart';
import 'data/admin_api.dart';

const _types = ['bar', 'ristorante', 'pub', 'pizzeria', 'caffe', 'club'];
const _weekdayLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

class AdminLocaleFormScreen extends ConsumerStatefulWidget {
  const AdminLocaleFormScreen({super.key, this.localeId});
  final String? localeId; // null => create

  @override
  ConsumerState<AdminLocaleFormScreen> createState() => _AdminLocaleFormScreenState();
}

class _AdminLocaleFormScreenState extends ConsumerState<AdminLocaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _rating = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  String _type = 'bar';
  int _priceLevel = 2;
  bool _isPublished = true;
  final List<MediaPayload> _media = [];
  final List<_HourEntry> _hours = List.generate(7, (i) => _HourEntry.defaultFor(i));

  bool _saving = false;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.localeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _address, _city, _lat, _lng, _rating, _phone, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final detail = await ref.read(localesApiProvider).get(widget.localeId!);
      _name.text = detail.name;
      _description.text = detail.description ?? '';
      _address.text = detail.address;
      _city.text = detail.city;
      _lat.text = detail.latitude.toString();
      _lng.text = detail.longitude.toString();
      _rating.text = detail.rating?.toString() ?? '';
      _phone.text = detail.phone ?? '';
      _website.text = detail.website ?? '';
      _type = detail.type;
      _priceLevel = detail.priceLevel;
      _media
        ..clear()
        ..addAll(detail.media.map((m) => MediaPayload(
              url: m.url,
              isPrimary: m.isPrimary,
              sortOrder: m.sortOrder,
            )));
      for (final h in detail.openingHours) {
        _hours[h.weekday] = _HourEntry(
          openTime: _parseTime(h.openTime),
          closeTime: _parseTime(h.closeTime),
          closed: h.closedAllDay,
        );
      }
      setState(() {});
    } on DioException catch (e) {
      setState(() => _error = 'Errore caricamento: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(adminApiProvider).uploadImage(
            bytes: bytes,
            filename: picked.name,
          );
      setState(() {
        _media.add(MediaPayload(
          url: url,
          isPrimary: _media.isEmpty,
          sortOrder: _media.length,
        ));
      });
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload fallito: $e')));
    }
  }

  Future<void> _addUrlImage() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('URL immagine'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    setState(() {
      _media.add(MediaPayload(
        url: url,
        isPrimary: _media.isEmpty,
        sortOrder: _media.length,
      ));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = LocaleWritePayload(
      name: _name.text.trim(),
      type: _type,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      priceLevel: _priceLevel,
      rating: _rating.text.trim().isEmpty ? null : double.tryParse(_rating.text.trim()),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      website: _website.text.trim().isEmpty ? null : _website.text.trim(),
      latitude: double.parse(_lat.text.trim()),
      longitude: double.parse(_lng.text.trim()),
      isPublished: _isPublished,
      media: _media,
      openingHours: [
        for (var i = 0; i < 7; i++)
          OpeningHoursPayload(
            weekday: i,
            openTime: _formatTime(_hours[i].openTime),
            closeTime: _formatTime(_hours[i].closeTime),
            closedAllDay: _hours[i].closed,
          ),
      ],
    );

    try {
      final api = ref.read(adminApiProvider);
      if (_isEdit) {
        await api.update(widget.localeId!, payload);
      } else {
        await api.create(payload);
      }
      // Refresh list & recommendations
      ref.invalidate(localesListProvider);
      ref.invalidate(tonightRecommendationsProvider);
      if (!mounted) return;
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = 'Salvataggio fallito: ${e.response?.data ?? e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifica locale' : 'Nuovo locale'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome *'),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo *'),
              items: [
                for (final t in _types) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'bar'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Indirizzo *'),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Città *'),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    decoration: const InputDecoration(labelText: 'Latitudine *'),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: _validateLat,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    decoration: const InputDecoration(labelText: 'Longitudine *'),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: _validateLng,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Prezzo', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 4; i++)
                  ChoiceChip(
                    label: Text('€' * i),
                    selected: _priceLevel == i,
                    onSelected: (_) => setState(() => _priceLevel = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rating,
              decoration: const InputDecoration(labelText: 'Rating (0-5, opzionale)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v);
                if (n == null || n < 0 || n > 5) return '0–5';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefono (opzionale)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _website,
              decoration: const InputDecoration(labelText: 'Sito web (opzionale)'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Pubblicato'),
              value: _isPublished,
              onChanged: (v) => setState(() => _isPublished = v),
            ),
            const Divider(height: 32),
            Text('Immagini', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _pickAndUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Carica foto'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addUrlImage,
                  icon: const Icon(Icons.link),
                  label: const Text('Aggiungi URL'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._media.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: CachedNetworkImage(
                        imageUrl: m.url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  title: Text(
                    m.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: m.isPrimary ? const Text('Principale') : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!m.isPrimary)
                        IconButton(
                          tooltip: 'Imposta principale',
                          icon: const Icon(Icons.star_outline),
                          onPressed: () {
                            setState(() {
                              for (var k = 0; k < _media.length; k++) {
                                _media[k] = MediaPayload(
                                  url: _media[k].url,
                                  isPrimary: k == i,
                                  sortOrder: _media[k].sortOrder,
                                );
                              }
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _media.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 32),
            Text('Orari', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < 7; i++) _hourRow(i),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Salva modifiche' : 'Crea locale'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _hourRow(int weekday) {
    final entry = _hours[weekday];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(_weekdayLabels[weekday])),
          if (entry.closed)
            const Expanded(child: Text('chiuso', style: TextStyle(fontStyle: FontStyle.italic)))
          else ...[
            TextButton(
              onPressed: () => _pickTime(weekday, isOpen: true),
              child: Text(_formatDisplay(entry.openTime)),
            ),
            const Text('–'),
            TextButton(
              onPressed: () => _pickTime(weekday, isOpen: false),
              child: Text(_formatDisplay(entry.closeTime)),
            ),
            const Spacer(),
          ],
          Switch(
            value: !entry.closed,
            onChanged: (v) => setState(() {
              _hours[weekday] = _HourEntry(
                openTime: entry.openTime,
                closeTime: entry.closeTime,
                closed: !v,
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(int weekday, {required bool isOpen}) async {
    final entry = _hours[weekday];
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? entry.openTime : entry.closeTime,
    );
    if (picked == null) return;
    setState(() {
      _hours[weekday] = _HourEntry(
        openTime: isOpen ? picked : entry.openTime,
        closeTime: isOpen ? entry.closeTime : picked,
        closed: entry.closed,
      );
    });
  }
}

class _HourEntry {
  const _HourEntry({required this.openTime, required this.closeTime, required this.closed});
  final TimeOfDay openTime;
  final TimeOfDay closeTime;
  final bool closed;

  factory _HourEntry.defaultFor(int weekday) {
    return _HourEntry(
      openTime: const TimeOfDay(hour: 18, minute: 0),
      closeTime: const TimeOfDay(hour: 23, minute: 0),
      closed: weekday == 6, // Domenica chiuso di default
    );
  }
}

String? _validateLat(String? v) {
  if (v == null || v.trim().isEmpty) return 'Obbligatorio';
  final n = double.tryParse(v);
  if (n == null || n < -90 || n > 90) return 'Tra -90 e 90';
  return null;
}

String? _validateLng(String? v) {
  if (v == null || v.trim().isEmpty) return 'Obbligatorio';
  final n = double.tryParse(v);
  if (n == null || n < -180 || n > 180) return 'Tra -180 e 180';
  return null;
}

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

String _formatDisplay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String hms) {
  final parts = hms.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}
