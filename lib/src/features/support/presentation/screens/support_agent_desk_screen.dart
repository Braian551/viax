import 'dart:async';

import 'package:flutter/material.dart';
import 'package:viax/src/features/support/presentation/screens/ticket_chat_screen.dart';
import 'package:viax/src/features/support/services/support_service.dart';
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

  bool _isLoadingTickets = true;

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
    _ticketsPollTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _loadTickets(silent: true);
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
          _buildFiltersCard(isDark),
          Expanded(
            child: _buildTicketList(isDark),
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
              hintText: 'Buscar ticket, asunto o usuario',
              suffixIcon: IconButton(
                onPressed: () => _loadTickets(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            onSubmitted: (_) => _loadTickets(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _statusOptions
                      .map((option) => DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(option['label']!),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _statusFilter = value ?? '');
                    _loadTickets();
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
                    _loadTickets();
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
}
