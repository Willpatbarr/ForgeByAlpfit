import 'package:flutter/material.dart';
import '../../../../services/plans_service.dart';

class PlanCreatorSheet extends StatefulWidget {
  const PlanCreatorSheet({
    super.key,
    this.planId,
    this.fallbackPlanName,
  });

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);
  final String? planId;
  final String? fallbackPlanName;

  @override
  State<PlanCreatorSheet> createState() => _PlanCreatorSheetState();
}

class _PlanCreatorSheetState extends State<PlanCreatorSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _repeatWeeksController =
      TextEditingController(text: '1');

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoadingEvents = true;
  bool _isLoadingPlan = false;
  bool _isCreating = false;
  List<LinkableEvent> _events = [];
  String? _eventToAddId;

  /// sourceEventId -> weekday (1=Mon...7=Sun)
  final Map<String, int> _selectedEventWeekdays = {};

  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate!.add(const Duration(days: 56));
    _loadEvents();
    _loadExistingPlanIfEditing();
  }

  bool get _isEditMode => widget.planId != null || widget.fallbackPlanName != null;

  Future<void> _loadExistingPlanIfEditing() async {
    if (!_isEditMode) return;
    setState(() => _isLoadingPlan = true);
    try {
      PlanDetails? plan;
      if (widget.planId != null) {
        plan = await getPlanDetailsForCurrentUser(widget.planId!);
      } else if (widget.fallbackPlanName != null) {
        plan = await findPlanByNameForCurrentUser(widget.fallbackPlanName!);
      }
      if (!mounted || plan == null) return;
      final loaded = plan;
      setState(() {
        _nameController.text = loaded.name;
        _descriptionController.text = loaded.description;
        _repeatWeeksController.text = loaded.repeatWindowWeeks.toString();
        _startDate = DateTime(
          loaded.startDate.year,
          loaded.startDate.month,
          loaded.startDate.day,
        );
        _endDate = DateTime(
          loaded.endDate.year,
          loaded.endDate.month,
          loaded.endDate.day,
        );
        _selectedEventWeekdays
          ..clear()
          ..addAll(loaded.linkedEventWeekdays);
      });
    } finally {
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final list = await getLinkableEventsForCurrentUser();
      if (!mounted) return;
      setState(() {
        _events = list;
        _isLoadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = [];
        _isLoadingEvents = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _repeatWeeksController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && !_endDate!.isAfter(picked)) {
          _endDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final min = (_startDate ?? DateTime.now()).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? min,
      firstDate: min,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _createPlan() async {
    if (_isCreating) return;

    final name = _nameController.text.trim();
    final repeatWeeks = int.tryParse(_repeatWeeksController.text.trim());

    if (name.isEmpty) {
      _showMessage('Plan name is required');
      return;
    }
    if (repeatWeeks == null || repeatWeeks <= 0) {
      _showMessage('Repeat window must be a whole number of weeks');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showMessage('Start and end dates are required');
      return;
    }
    if (_selectedEventWeekdays.isEmpty) {
      _showMessage('Select at least one event for this plan');
      return;
    }

    setState(() => _isCreating = true);
    try {
      bool updateFutureInstances = true;
      if (_isEditMode) {
        final choice = await _confirmUpdateUpcomingInstances();
        updateFutureInstances = choice ?? false;
        if (choice == null) {
          // User cancelled; keep editing.
          setState(() => _isCreating = false);
          return;
        }

        final existing = widget.planId != null
            ? await getPlanDetailsForCurrentUser(widget.planId!)
            : await findPlanByNameForCurrentUser(widget.fallbackPlanName ?? '');
        if (existing == null) {
          throw Exception('Could not load this plan for editing');
        }
        await updatePlanForCurrentUser(
          planId: existing.id,
          name: name,
          description: _descriptionController.text,
          repeatWindowWeeks: repeatWeeks,
          startDate: _startDate!,
          endDate: _endDate!,
          selectedEventWeekdays: _selectedEventWeekdays,
          updateFutureInstances: updateFutureInstances,
        );
      } else {
        await createPlanForCurrentUser(
          name: name,
          description: _descriptionController.text,
          repeatWindowWeeks: repeatWeeks,
          startDate: _startDate!,
          endDate: _endDate!,
          selectedEventWeekdays: _selectedEventWeekdays,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? (updateFutureInstances
                    ? 'Plan updated. Future instances regenerated.'
                    : 'Plan updated. Future instances left unchanged.')
                : 'Plan created and events generated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  /// Returns:
  /// - `true` if the user wants to regenerate future instances
  /// - `false` if the user wants to only update plan settings
  /// - `null` if the user cancels
  Future<bool?> _confirmUpdateUpcomingInstances() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Update upcoming instances?'),
          content: const Text(
            'This will regenerate all future instances of this plan. Past occurrences will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Only update plan'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: PlanCreatorSheet.forgeBlue,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return SizedBox(
      height: maxHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: PlanCreatorSheet.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode ? 'Edit Plan' : 'Create Plan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingPlan
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLabeledField(
                      label: 'Plan Name',
                      icon: Icons.view_timeline,
                      child: TextField(
                        controller: _nameController,
                        decoration: _inputDecoration(hint: 'e.g. 8 Week Strength Block'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabeledField(
                      label: 'Description (optional)',
                      icon: Icons.notes,
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: _inputDecoration(hint: 'Add notes for this plan'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabeledField(
                      label: 'Repeat Window (weeks)',
                      icon: Icons.repeat,
                      child: TextField(
                        controller: _repeatWeeksController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: '1 = weekly, 2 = every other week'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabeledField(
                      label: 'Start Date',
                      icon: Icons.calendar_today,
                      child: _buildDatePickerTile(
                        value: _startDate,
                        onTap: _pickStartDate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabeledField(
                      label: 'End Date',
                      icon: Icons.event,
                      child: _buildDatePickerTile(
                        value: _endDate,
                        onTap: _pickEndDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Existing Events + Assign Day',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildEventsSelector(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _createPlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PlanCreatorSheet.forgeBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditMode ? 'Update Plan' : 'Create Plan',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSelector() {
    if (_isLoadingEvents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No existing events found. Create events first, then add them to a plan.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
      );
    }

    final selectedEvents = _events
        .where((e) => _selectedEventWeekdays.containsKey(e.id))
        .toList();
    final availableEvents = _events
        .where((e) => !_selectedEventWeekdays.containsKey(e.id))
        .toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _eventToAddId,
                  decoration: _inputDecoration(
                    hint: availableEvents.isEmpty
                        ? 'All events already added'
                        : 'Select event to add',
                  ).copyWith(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: availableEvents
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.id,
                          child: Text(
                            e.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: availableEvents.isEmpty
                      ? null
                      : (v) => setState(() => _eventToAddId = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_eventToAddId == null)
                    ? null
                    : () {
                        setState(() {
                          _selectedEventWeekdays[_eventToAddId!] =
                              DateTime.monday;
                          _eventToAddId = null;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PlanCreatorSheet.forgeBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedEvents.isEmpty)
            const Text(
              'No events added yet.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
          ...selectedEvents.map((event) {
            final selectedWeekday =
                _selectedEventWeekdays[event.id] ?? DateTime.monday;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: DropdownButtonFormField<int>(
                        value: selectedWeekday,
                        decoration: _inputDecoration().copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        items: List.generate(7, (i) {
                          final wd = i + 1;
                          return DropdownMenuItem<int>(
                            value: wd,
                            child: Text(
                              _weekdayLabels[i],
                              style: const TextStyle(
                                  fontSize: 12, fontFamily: 'Poppins'),
                            ),
                          );
                        }),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedEventWeekdays[event.id] = v);
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => _selectedEventWeekdays.remove(event.id),
                      ),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDatePickerTile({required DateTime? value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PlanCreatorSheet.forgeBlue.withValues(alpha: 0.3)),
        ),
        child: Text(
          value == null
              ? 'Select date'
              : '${value.month}/${value.day}/${value.year}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: value == null ? Colors.black54 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Colors.black54,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PlanCreatorSheet.forgeBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
