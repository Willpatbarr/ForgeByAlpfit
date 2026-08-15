import 'package:flutter/material.dart';
import '../../../../models/goal.dart';
import '../../../../services/goals_service.dart';

/// Modal bottom sheet for creating a new goal.
class GoalCreatorSheet extends StatefulWidget {
  const GoalCreatorSheet({super.key, this.goalId});

  final String? goalId;

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<GoalCreatorSheet> createState() => _GoalCreatorSheetState();
}

class _GoalCreatorSheetState extends State<GoalCreatorSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _requiredController = TextEditingController(
    text: '3',
  );

  DateTime? _startDate;
  DateTime? _endDate;
  ResetPeriod _resetPeriod = ResetPeriod.weekly;
  bool _isCreating = false;
  bool _isDeleting = false;
  bool _isLoadingGoal = false;

  bool get _isEditMode => widget.goalId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate ??= DateTime(now.year, now.month, now.day);
    _endDate ??= _startDate!.add(const Duration(days: 30));
    if (_isEditMode) {
      _loadGoalForEdit();
    }
  }

  Future<void> _loadGoalForEdit() async {
    setState(() => _isLoadingGoal = true);
    try {
      final goal = await getGoal(widget.goalId!);
      if (!mounted) return;
      if (goal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load goal to edit.')),
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _nameController.text = goal.name;
        _descriptionController.text = goal.description;
        _requiredController.text = goal.requiredCheckupsPerPeriod.toString();
        _resetPeriod = goal.resetPeriod;
        _startDate = DateTime(goal.startDate.year, goal.startDate.month, goal.startDate.day);
        _endDate = DateTime(goal.endDate.year, goal.endDate.month, goal.endDate.day);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load goal details.')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingGoal = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _requiredController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    final start = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? start.add(const Duration(days: 30)),
      firstDate: start.add(const Duration(days: 1)),
      lastDate: start.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _confirmDeleteGoal() async {
    if (!_isEditMode || _isDeleting || _isCreating) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text(
          'This removes the goal and its history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await deleteGoal(widget.goalId!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete goal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _createGoal() async {
    if (_isCreating || _isDeleting) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal name cannot be empty')),
      );
      return;
    }

    final requiredStr = _requiredController.text.trim();
    final required = int.tryParse(requiredStr);
    if (required == null || required <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Required check-ins must be a number greater than 0'),
        ),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      if (_isEditMode) {
        await updateGoalForCurrentUser(
          goalId: widget.goalId!,
          name: name,
          description: _descriptionController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          requiredCheckupsPerPeriod: required,
          resetPeriod: _resetPeriod,
        );
      } else {
        await createGoal(
          name: name,
          description: _descriptionController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          requiredCheckupsPerPeriod: required,
          resetPeriod: _resetPeriod,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Goal updated!' : 'Goal created!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create goal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return SizedBox(
      height: maxHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: GoalCreatorSheet.background,
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
                    _isEditMode ? 'Edit Goal' : 'Create Goal',
                    style: const TextStyle(
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
              child: _isLoadingGoal
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLabeledField(
                      label: 'Goal Name',
                      icon: Icons.flag,
                      child: TextField(
                        controller: _nameController,
                        decoration: _inputDecoration(hint: 'e.g. Work out 3x per week'),
                        style: _inputStyle(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: 'Description (optional)',
                      icon: Icons.notes,
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(hint: 'Add details about your goal'),
                        style: _inputStyle(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: 'Check-ins per period',
                      icon: Icons.check_circle_outline,
                      child: TextField(
                        controller: _requiredController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: 'e.g. 3'),
                        style: _inputStyle(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: 'Reset period',
                      icon: Icons.repeat,
                      child: DropdownButtonFormField<ResetPeriod>(
                        value: _resetPeriod,
                        decoration: _inputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: ResetPeriod.daily,
                            child: Text('Daily'),
                          ),
                          DropdownMenuItem(
                            value: ResetPeriod.weekly,
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: ResetPeriod.biweekly,
                            child: Text('Every 2 weeks'),
                          ),
                          DropdownMenuItem(
                            value: ResetPeriod.monthly,
                            child: Text('Monthly'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _resetPeriod = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: 'Start date',
                      icon: Icons.calendar_today,
                      child: GestureDetector(
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: GoalCreatorSheet.forgeBlue
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _startDate != null
                                ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'
                                : 'Select start date',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color:
                                  _startDate != null ? Colors.black87 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: 'End date (within 1 year)',
                      icon: Icons.event,
                      child: GestureDetector(
                        onTap: _pickEndDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: GoalCreatorSheet.forgeBlue
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _endDate != null
                                ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'
                                : 'Select end date',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color:
                                  _endDate != null ? Colors.black87 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isEditMode) ...[
                      OutlinedButton.icon(
                        onPressed: (_isCreating || _isDeleting)
                            ? null
                            : _confirmDeleteGoal,
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Icon(Icons.delete_outline, color: Colors.red),
                        label: Text(_isDeleting ? 'Deleting…' : 'Delete goal'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(
                      onPressed:
                          (_isCreating || _isDeleting) ? null : _createGoal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GoalCreatorSheet.forgeBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isEditMode ? 'Update Goal' : 'Create Goal',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
        fontSize: 16,
        color: Colors.black54,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: GoalCreatorSheet.forgeBlue,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  TextStyle _inputStyle() {
    return const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      color: Colors.black87,
    );
  }
}
