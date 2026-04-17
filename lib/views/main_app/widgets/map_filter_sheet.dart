import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/emergency_types.dart';

// ─── Constantes de opciones ────────────────────────────────────────────────

const List<Map<String, String>> kStatusOptions = [
  {'value': 'all',      'label': 'Todas'},
  {'value': 'pending',  'label': 'No atendida'},
  {'value': 'attended', 'label': 'Atendida'},
];

const List<Map<String, String>> kDateOptions = [
  {'value': 'all',       'label': 'Cualquier fecha'},
  {'value': 'today',     'label': 'Hoy'},
  {'value': 'yesterday', 'label': 'Ayer'},
  {'value': 'week',      'label': 'Esta semana'},
  {'value': '7days',     'label': 'Últimos 7 días'},
  {'value': 'month',     'label': 'Este mes'},
  {'value': 'custom',    'label': 'Personalizado'},
];

// ─── Modelo de filtros ─────────────────────────────────────────────────────

class MapFilters {
  final Set<String> types;
  final String status;       // 'all' | 'pending' | 'attended'
  final String dateRange;    // 'all' | 'today' | 'yesterday' | 'week' | '7days' | 'month' | 'custom'
  final DateTime? customStart;
  final DateTime? customEnd;

  const MapFilters({
    this.types = const {},
    this.status = 'all',
    this.dateRange = 'all',
    this.customStart,
    this.customEnd,
  });

  MapFilters copyWith({
    Set<String>? types,
    String? status,
    String? dateRange,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustomStart = false,
    bool clearCustomEnd = false,
  }) {
    return MapFilters(
      types: types ?? this.types,
      status: status ?? this.status,
      dateRange: dateRange ?? this.dateRange,
      customStart: clearCustomStart ? null : (customStart ?? this.customStart),
      customEnd: clearCustomEnd ? null : (customEnd ?? this.customEnd),
    );
  }

  int get activeCount {
    int n = 0;
    if (types.isNotEmpty) n++;
    if (status != 'all') n++;
    if (dateRange != 'all') n++;
    return n;
  }

  bool get hasFilters => activeCount > 0;

  static const MapFilters empty = MapFilters();
}

// ─── Widget Bottom Sheet ───────────────────────────────────────────────────

class MapFilterSheet extends StatefulWidget {
  final MapFilters initial;
  final void Function(MapFilters) onApply;

  const MapFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late MapFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
  }

  void _toggleType(String type) {
    HapticFeedback.selectionClick();
    setState(() {
      final newTypes = Set<String>.from(_filters.types);
      if (newTypes.contains(type)) {
        newTypes.remove(type);
      } else {
        newTypes.add(type);
      }
      _filters = _filters.copyWith(types: newTypes);
    });
  }

  void _setStatus(String status) {
    HapticFeedback.selectionClick();
    setState(() {
      _filters = _filters.copyWith(status: status);
    });
  }

  void _setDateRange(String range) {
    HapticFeedback.selectionClick();
    setState(() {
      _filters = _filters.copyWith(
        dateRange: range,
        clearCustomStart: range != 'custom',
        clearCustomEnd: range != 'custom',
      );
    });
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      _filters = MapFilters.empty;
    });
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    widget.onApply(_filters);
    Navigator.of(context).pop();
  }

  Future<void> _pickCustomDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_filters.customStart ?? now)
        : (_filters.customEnd ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0D1B3E),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    setState(() {
      _filters = isStart
          ? _filters.copyWith(customStart: picked, dateRange: 'custom')
          : _filters.copyWith(customEnd: picked, dateRange: 'custom');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lista de tipos únicos del sistema de emergencias
    final allTypes = EmergencyTypes.allTypes;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B3E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.4,
                  ),
                ),
                if (_filters.hasFilters) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${_filters.activeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_filters.hasFilters)
                  TextButton(
                    onPressed: _clearAll,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      'Limpiar todo',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF9CA3AF),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // ─── Scrollable content ───
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tipos ──
                  _buildSectionTitle(Icons.category_rounded, 'Tipo de alerta'),
                  const SizedBox(height: 10),
                  _buildTypeGrid(allTypes),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 20),

                  // ── Estado ──
                  _buildSectionTitle(Icons.radio_button_checked_rounded, 'Estado de atención'),
                  const SizedBox(height: 10),
                  _buildStatusPills(),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 20),

                  // ── Período ──
                  _buildSectionTitle(Icons.calendar_today_rounded, 'Período de tiempo'),
                  const SizedBox(height: 10),
                  _buildDateChips(),

                  if (_filters.dateRange == 'custom') ...[
                    const SizedBox(height: 14),
                    _buildCustomDateRow(),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ─── Apply button ───
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1B3E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Aplicar filtros',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeGrid(List<String> types) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isActive = _filters.types.contains(type);
        final color = EmergencyTypes.getColor(type);
        final icon = EmergencyTypes.getIcon(type);
        final label = EmergencyTypes.getTranslatedType(type, context);

        return GestureDetector(
          onTap: () => _toggleType(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? color : const Color(0xFFE5E7EB),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: Colors.white, size: 11),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? color : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusPills() {
    return Row(
      children: kStatusOptions.map((opt) {
        final isActive = _filters.status == opt['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () => _setStatus(opt['value']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0D1B3E) : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? const Color(0xFF0D1B3E) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Center(
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kDateOptions.map((opt) {
        if (opt['value'] == 'custom') return const SizedBox.shrink();
        final isActive = _filters.dateRange == opt['value'];
        return GestureDetector(
          onTap: () => _setDateRange(opt['value']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF3F51B5) : Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isActive ? const Color(0xFF3F51B5) : const Color(0xFFE5E7EB),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt['label']!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ),
        );
      }).toList()
        ..add(
          GestureDetector(
            onTap: () => _setDateRange('custom'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _filters.dateRange == 'custom'
                    ? const Color(0xFF3F51B5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _filters.dateRange == 'custom'
                      ? const Color(0xFF3F51B5)
                      : const Color(0xFFE5E7EB),
                  width: _filters.dateRange == 'custom' ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 12,
                    color: _filters.dateRange == 'custom'
                        ? Colors.white
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Personalizado',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _filters.dateRange == 'custom'
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildCustomDateRow() {
    String fmt(DateTime? d) => d == null
        ? 'Seleccionar'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Row(
      children: [
        Expanded(
          child: _buildDatePickerButton(
            label: 'Desde',
            value: fmt(_filters.customStart),
            onTap: () => _pickCustomDate(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDatePickerButton(
            label: 'Hasta',
            value: fmt(_filters.customEnd),
            onTap: () => _pickCustomDate(false),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
