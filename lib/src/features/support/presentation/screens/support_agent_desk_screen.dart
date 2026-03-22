import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viax/src/features/support/presentation/screens/ticket_chat_screen.dart';
import 'package:viax/src/features/support/services/support_service.dart';
import 'package:viax/src/shared/widgets/global_overlay_message.dart';
import 'package:viax/src/theme/app_colors.dart';

class SupportAgentDeskScreen extends StatefulWidget {
  final int agentId;

  const SupportAgentDeskScreen({
    super.key,
    required this.agentId,
  });

  @override
  State<SupportAgentDeskScreen> createState() => _SupportAgentDeskScreenState();
}

class _SupportAgentDeskScreenState extends State<SupportAgentDeskScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _ticketsPollTimer;

  List<SupportTicket> _tickets = [];
  List<UserModerationReport> _userReports = [];

  bool _isLoadingTickets = true;
  bool _isLoadingReports = true;

  String _deskMode = 'tickets';

  String _statusFilter = '';
  String _priorityFilter = '';

  final List<Map<String, String>> _statusOptions = const [
    {'value': '', 'label': 'Todos'},
    {'value': 'abierto', 'label': 'Abierto'},
    {'value': 'en_progreso', 'label': 'En progreso'},
    {'value': 'esperando_usuario', 'label': 'Esperando usuario'},
    {'value': 'resuelto', 'label': 'Resuelto'},
    {'value': 'cerrado', 'label': 'Cerrado'},
  ];

  final List<Map<String, String>> _reportStatusOptions = const [
    {'value': '', 'label': 'Todos'},
    {'value': 'pendiente', 'label': 'Pendiente'},
    {'value': 'en_revision', 'label': 'En revisión'},
    {'value': 'resuelto', 'label': 'Resuelto'},
    {'value': 'descartado', 'label': 'Descartado'},
  ];

  final List<Map<String, String>> _priorityOptions = const [
    {'value': '', 'label': 'Todas'},
    {'value': 'baja', 'label': 'Baja'},
    {'value': 'normal', 'label': 'Normal'},
    {'value': 'alta', 'label': 'Alta'},
    {'value': 'urgente', 'label': 'Urgente'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _loadUserReports();
    _ticketsPollTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (_deskMode == 'tickets') {
        _loadTickets(silent: true);
      } else {
        _loadUserReports(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _ticketsPollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingTickets = true);
    }

    final tickets = await SupportService.getOperationalTickets(
      agentId: widget.agentId,
      status: _statusFilter,
      priority: _priorityFilter,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _tickets = tickets;
      _isLoadingTickets = false;
    });
  }

  Future<void> _loadUserReports({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingReports = true);
    }

    final response = await SupportService.getUserReports(
      actorId: widget.agentId,
      estado: _statusFilter,
      prioridad: _priorityFilter,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _userReports = (response['reportes'] as List?)?.cast<UserModerationReport>() ??
          <UserModerationReport>[];
      _isLoadingReports = false;
    });
  }

  Future<void> _handleReportAction(
    UserModerationReport report,
    String action,
  ) async {
    final ok = await SupportService.updateUserReport(
      actorId: widget.agentId,
      reportId: report.id,
      action: action,
    );

    if (!mounted) return;

        if (ok) {
          GlobalOverlayMessage.showSuccess(
            context,
            'Reporte #${report.id} actualizado correctamente.',
          );
        } else {
          GlobalOverlayMessage.showError(
            context,
            'No se pudo actualizar el reporte #${report.id}.',
          );
        }

        if (ok) {
          _loadUserReports(silent: true);
        }
  }

  String _prettyReason(String raw) {
    switch (raw) {
      case 'comportamiento_inapropiado':
        return 'Comportamiento inapropiado';
      case 'acoso_o_amenaza':
        return 'Acoso o amenaza';
      case 'fraude_o_estafa':
        return 'Fraude o estafa';
      case 'incumplimiento_servicio':
        return 'Incumplimiento del servicio';
      case 'contenido_inapropiado_chat':
        return 'Contenido inapropiado en chat';
      default:
        return 'Otro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mesa operativa de soporte'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tickets'),
                  selected: _deskMode == 'tickets',
                  onSelected: (_) {
                    setState(() {
                      _deskMode = 'tickets';
                    });
                    _loadTickets(silent: true);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Reportes usuarios'),
                  selected: _deskMode == 'reportes',
                  onSelected: (_) {
                    setState(() {
                      _deskMode = 'reportes';
                    });
                    _loadUserReports(silent: true);
                  },
                ),
              ],
            ),
          ),
          _buildFiltersCard(isDark),
          Expanded(
            child: _deskMode == 'tickets'
                ? _buildTicketList(isDark)
                : _buildReportList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: _deskMode == 'tickets'
                  ? 'Buscar ticket, asunto o usuario'
                  : 'Buscar por usuario, motivo o detalle',
              suffixIcon: IconButton(
                onPressed: () {
                  if (_deskMode == 'tickets') {
                    _loadTickets();
                  } else {
                    _loadUserReports();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            onSubmitted: (_) {
              if (_deskMode == 'tickets') {
                _loadTickets();
              } else {
                _loadUserReports();
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: (_deskMode == 'tickets'
                          ? _statusOptions
                          : _reportStatusOptions)
                      .map((option) => DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(option['label']!),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _statusFilter = value ?? '');
                    if (_deskMode == 'tickets') {
                      _loadTickets();
                    } else {
                      _loadUserReports();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _priorityFilter,
                  decoration: const InputDecoration(labelText: 'Prioridad'),
                  items: _priorityOptions
                      .map((option) => DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(option['label']!),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _priorityFilter = value ?? '');
                    if (_deskMode == 'tickets') {
                      _loadTickets();
                    } else {
                      _loadUserReports();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList(bool isDark) {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tickets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No hay tickets con estos filtros'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 6, 16),
      itemBuilder: (_, index) {
        final ticket = _tickets[index];

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketChatScreen(
                  ticketId: ticket.id,
                  agentId: widget.agentId,
                ),
              ),
            );
            _loadTickets(silent: true);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.numeroTicket,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.asunto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ticket.usuarioNombre ?? 'Usuario'} ${ticket.usuarioApellido ?? ''}'.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _tickets.length,
    );
  }

  Widget _buildReportList(bool isDark) {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userReports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No hay reportes de usuarios con estos filtros'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 6, 16),
      itemBuilder: (_, index) {
        final report = _userReports[index];
        final reporterName =
            '${report.reporterNombre ?? ''} ${report.reporterApellido ?? ''}'
                .trim();
        final reportedName =
            '${report.reportedNombre ?? ''} ${report.reportedApellido ?? ''}'
                .trim();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reporte #${report.id} • ${_prettyReason(report.motivo)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleReportAction(report, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'start_review',
                        child: Text('Marcar en revisión'),
                      ),
                      PopupMenuItem<String>(
                        value: 'resolve',
                        child: Text('Marcar resuelto'),
                      ),
                      PopupMenuItem<String>(
                        value: 'dismiss',
                        child: Text('Descartar reporte'),
                      ),
                      PopupMenuItem<String>(
                        value: 'reopen',
                        child: Text('Reabrir reporte'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Reporta: ${reporterName.isEmpty ? 'Usuario ${report.reporterUserId}' : reporterName}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                'Reportado: ${reportedName.isEmpty ? 'Usuario ${report.reportedUserId}' : reportedName}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              if ((report.descripcion ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  report.descripcion!.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text('Estado: ${report.estado}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text('Prioridad: ${report.prioridad}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _userReports.length,
    );
  }
}
