import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/savings_group.dart';
import '../../app/theme.dart';
import '../../core/widgets/ajo_ui.dart';
import 'group_providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _members = TextEditingController(text: '10');
  // One id per form lifetime. Retrying an uncertain response cannot create two groups.
  final _requestId = List.generate(
    32,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  DateTime? _firstPayout;
  DateTime? _endDate;
  DateTime? _collectionDate;
  SavingsFrequency _payoutFrequency = SavingsFrequency.monthly;
  SavingsMode _mode = SavingsMode.rotating;
  SavingsFrequency _frequency = SavingsFrequency.monthly;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _members.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_firstPayout == null) {
      setState(
        () => _error = _mode == SavingsMode.rotating
            ? 'Choose a first contribution date.'
            : 'Choose a first contribution date.',
      );
      return;
    }
    final draft = GroupDraft(
      name: _name.text.trim(),
      rulesVersion: 2,
      lateFeeKobo: 20000,
      payoutFrequency: _mode == SavingsMode.rotating
          ? _payoutFrequency
          : _frequency,
      firstCollectionDate: _mode == SavingsMode.rotating
          ? (_collectionDate ?? _firstPayout!)
          : _firstPayout!,
      contributionKobo: parseNairaToKobo(_amount.text)!,
      memberLimit: int.parse(_members.text.trim()),
      firstPayoutDate: _firstPayout!,
      mode: _mode,
      frequency: _frequency,
      endDate: _mode == SavingsMode.target ? _endDate : null,
    );
    final validation = draft.validate(DateTime.now());
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(groupRepositoryProvider)
        .createGroup(draft, _requestId);
    if (!mounted) return;
    result.when(
      success: (group) {
        ref.invalidate(groupsProvider);
        context.go('/groups/${group.id}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Draft group created.')));
      },
      failure: (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseNairaToKobo(_amount.text);
    final members = int.tryParse(_members.text.trim());
    final validPreview =
        amount != null &&
        amount >= 100 &&
        amount <= 100000000 &&
        members != null &&
        members >= 2 &&
        members <= 50;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create a group'),
          backgroundColor: AjoColors.forest,
          foregroundColor: Colors.white,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AjoColors.forest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            color: AjoColors.mint,
                            size: 32,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Your circle. Your rhythm.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Choose how you save together. Set the amount, the pace, and the people.',
                            style: TextStyle(color: AjoColors.mint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '01  NAME YOUR CIRCLE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AjoColors.emerald,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                        hintText: 'e.g. Friends monthly savings',
                      ),
                      maxLength: 80,
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter at least 3 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 8),
                    const Text(
                      '02  SET YOUR SAVINGS RHYTHM',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AjoColors.emerald,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<SavingsMode>(
                      initialValue: _mode,
                      decoration: const InputDecoration(
                        labelText: 'Savings plan',
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: SavingsMode.rotating,
                          child: Text('Take turns receiving the pot'),
                        ),
                        DropdownMenuItem(
                          value: SavingsMode.target,
                          child: Text('Save until an end date'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _mode = value!),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _mode == SavingsMode.rotating
                          ? 'Every member pays the same fixed amount each contribution period. Choose a separate schedule for taking turns receiving the accumulated pot.'
                          : 'Everyone contributes regularly, then receives their own accumulated savings at the end. No interest is included.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SavingsFrequency>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Contribution frequency',
                      ),
                      items: SavingsFrequency.values
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(f.label),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _frequency = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amount,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '${_frequency.label} contribution (NGN)',
                        helperText: _mode == SavingsMode.target
                            ? 'Minimum per person each ${_frequency.interval}. Members may save more, never less.'
                            : 'Exact amount per person each ${_frequency.interval}. No overpayments.',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final kobo = parseNairaToKobo(value ?? '');
                        return kobo == null || kobo < 100 || kobo > 100000000
                            ? 'Enter NGN 1–1,000,000, with up to 2 decimal places'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _members,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of members',
                        helperText: 'Include yourself. Between 2 and 50.',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final count = int.tryParse(value?.trim() ?? '');
                        return count == null || count < 2 || count > 50
                            ? 'Enter 2–50 members'
                            : null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '03  SET THE DATES',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AjoColors.emerald,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final now = DateTime.now();
                              final tomorrow = DateTime(
                                now.year,
                                now.month,
                                now.day + 1,
                              );
                              final selected = await showDatePicker(
                                context: context,
                                initialDate:
                                    _firstPayout != null &&
                                        !_firstPayout!.isBefore(tomorrow)
                                    ? _firstPayout
                                    : tomorrow,
                                firstDate: tomorrow,
                                lastDate: DateTime(
                                  now.year + 2,
                                  now.month,
                                  now.day,
                                ),
                              );
                              if (mounted && selected != null) {
                                setState(() => _firstPayout = selected);
                              }
                            },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _firstPayout == null
                            ? (_mode == SavingsMode.rotating
                                  ? 'Choose first contribution date'
                                  : 'Choose first contribution date')
                            : '${_mode == SavingsMode.rotating ? 'First contribution' : 'First contribution'}: ${dateOnly(_firstPayout!)}',
                      ),
                    ),
                    if (_mode == SavingsMode.rotating) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SavingsFrequency>(
                        initialValue: _payoutFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Payout frequency',
                        ),
                        items: SavingsFrequency.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(f.label),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _payoutFrequency = v!),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_available),
                        label: Text(
                          _collectionDate == null
                              ? 'Choose first payout date'
                              : 'First payout: ${dateOnly(_collectionDate!)}',
                        ),
                        onPressed: _saving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final first =
                                    _firstPayout ??
                                    DateTime(now.year, now.month, now.day + 1);
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _collectionDate != null &&
                                          !_collectionDate!.isBefore(first)
                                      ? _collectionDate!
                                      : first,
                                  firstDate: first,
                                  lastDate: DateTime(
                                    now.year + 2,
                                    now.month,
                                    now.day,
                                  ),
                                );
                                if (mounted && selected != null) {
                                  setState(() => _collectionDate = selected);
                                }
                              },
                      ),
                      const Text(
                        'Each payout includes contributions scheduled after the previous payout and up to this payout date. Weekly totals vary with the number of deadlines in that month.',
                      ),
                    ],
                    if (_mode == SavingsMode.target) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final first =
                                    (_firstPayout ??
                                            DateTime(
                                              now.year,
                                              now.month,
                                              now.day + 1,
                                            ))
                                        .add(const Duration(days: 1));
                                final last = DateTime(
                                  now.year + 2,
                                  now.month,
                                  now.day,
                                );
                                if (first.isAfter(last)) {
                                  setState(
                                    () => _error =
                                        'Choose an earlier first contribution date.',
                                  );
                                  return;
                                }
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _endDate != null &&
                                          !_endDate!.isBefore(first)
                                      ? _endDate!
                                      : first,
                                  firstDate: first,
                                  lastDate: last,
                                );
                                if (mounted && date != null) {
                                  setState(() => _endDate = date);
                                }
                              },
                        icon: const Icon(Icons.event_available),
                        label: Text(
                          _endDate == null
                              ? 'Choose savings end date'
                              : 'End date: ${dateOnly(_endDate!)}',
                        ),
                      ),
                    ],
                    if (validPreview) ...[
                      const SizedBox(height: 24),
                      AjoPanel(
                        color: AjoColors.mint,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR CIRCLE AT A GLANCE',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: AjoColors.forest,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              formatNaira(
                                _mode == SavingsMode.rotating
                                    ? amount *
                                          members *
                                          (_firstPayout != null
                                              ? scheduledContributions(
                                                  _firstPayout!,
                                                  _collectionDate ??
                                                      _firstPayout!,
                                                  _frequency,
                                                )
                                              : 1)
                                    : amount *
                                          (_firstPayout != null &&
                                                  _endDate != null
                                              ? scheduledContributions(
                                                  _firstPayout!,
                                                  _endDate!,
                                                  _frequency,
                                                )
                                              : 0),
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              _mode == SavingsMode.rotating
                                  ? 'First scheduled payout'
                                  : 'Minimum planned savings per member · no interest',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _mode == SavingsMode.rotating
                                  ? '$members members · $members ${_payoutFrequency.label.toLowerCase()} payouts'
                                  : '$members members · ${_firstPayout != null && _endDate != null ? scheduledContributions(_firstPayout!, _endDate!, _frequency) : 0} scheduled contributions each',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _mode == SavingsMode.rotating
                                  ? 'Everyone keeps contributing until each member has received their turn.'
                                  : 'Contributions start on your chosen date and repeat through the end date, including any payment due on that day.',
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Late-payment rule: NGN 200 once per missed deadline, from the next day in Nigeria time. This belongs to AjoPay, stays separate from savings, and is not currently collected in the app. Add the group bank account and agree the terms before activation.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Creating draft…' : 'Create draft group',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
