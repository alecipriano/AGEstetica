import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/agendamento.dart';
import 'agendamento_form_screen.dart';
import 'clientes_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Agendamento> _agendamentosDoDia = [];
  Set<String> _diasComAgendamento = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final agendamentos = await DatabaseHelper.instance.getAgendamentosPorData(
        _selectedDay ?? DateTime.now(),
      );
      final dias = await DatabaseHelper.instance.getDiasComAgendamentos(
        _focusedDay,
      );
      if (mounted) {
        setState(() {
          _agendamentosDoDia = agendamentos;
          _diasComAgendamento = dias.toSet();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      }
    }
  }

  void _atualizarStatus(Agendamento agendamento, String novoStatus) async {
    try {
      await DatabaseHelper.instance.updateAgendamentoStatus(
        agendamento.id!,
        novoStatus,
      );
      _carregarDados();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar status: $e')));
      }
    }
  }

  void _editarAgendamento(Agendamento agendamento) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgendamentoFormScreen(
          dataSelecionada: DateTime.parse(agendamento.dataHora),
          agendamento: agendamento,
        ),
      ),
    );
    _carregarDados();
  }

  void _excluirAgendamento(int id) async {
    try {
      await DatabaseHelper.instance.deleteAgendamento(id);
      _carregarDados();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir agendamento: $e')),
        );
      }
    }
  }

  Future<void> _enviarLembreteWhatsApp(Agendamento agendamento) async {
    final telefone = agendamento.clienteTelefone;
    if (telefone == null || telefone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefone do cliente não cadastrado.')),
        );
      }
      return;
    }

    var telLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    if (telLimpo.length <= 11) {
      telLimpo = '55$telLimpo';
    }

    String dataFormatada = '';
    String horaFormatada = '';
    try {
      final dataHora = DateTime.parse(agendamento.dataHora);
      dataFormatada = DateFormat('dd/MM').format(dataHora);
      horaFormatada = DateFormat('HH:mm').format(dataHora);
    } catch (_) {
      dataFormatada = agendamento.dataHora;
    }

    final salaoNome = await DatabaseHelper.instance.getConfig(
      'nome_salao',
      'Manicure Pro',
    );
    final servicos = agendamento.servicos ?? 'atendimento';
    final clienteNome = agendamento.clienteNome ?? 'Cliente';

    final modeloTemplate = await DatabaseHelper.instance.getConfig(
      'modelo_mensagem_whatsapp',
      'Olá! Aqui é do {salao}. Passando para confirmar seu horário de {servicos} no dia {data} às {hora}. Confirma?',
    );

    final mensagem = modeloTemplate
        .replaceAll('{salao}', salaoNome)
        .replaceAll('{cliente}', clienteNome)
        .replaceAll('{servicos}', servicos)
        .replaceAll('{data}', dataFormatada)
        .replaceAll('{hora}', horaFormatada);

    final urlString =
        'https://wa.me/$telLimpo?text=${Uri.encodeComponent(mensagem)}';

    final uri = Uri.parse(urlString);
    try {
      // Tenta abrir o WhatsApp diretamente no aplicativo externo
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw 'O sistema não conseguiu abrir o link do WhatsApp.';
      }
    } catch (e) {
      // Fallback para abrir no navegador caso dê erro ao abrir o aplicativo direto
      try {
        final openedFallback = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (!openedFallback) {
          throw 'Não foi possível abrir o WhatsApp.';
        }
      } catch (fallbackError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir o WhatsApp: $fallbackError')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TableCalendar(
              key: ValueKey(_diasComAgendamento.join(',')),
              locale: 'pt_BR',
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(DateTime.now().year + 10, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              rowHeight: 33, // Deixa o calendário mais compacto
              eventLoader: (day) {
                final formatted = DateFormat('yyyy-MM-dd').format(day);
                if (_diasComAgendamento.contains(formatted)) {
                  return [true];
                }
                return [];
              },
              headerStyle: HeaderStyle(
                headerPadding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                headerMargin: const EdgeInsets.only(bottom: 4.0),
                titleTextFormatter: (date, locale) {
                  final texto = DateFormat.yMMMM(locale).format(date);
                  return texto[0].toUpperCase() + texto.substring(1);
                },
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70),
                weekendStyle: TextStyle(color: Color(0xFFFFD54F)),
              ),
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Color(0xFFFFD54F)),
                outsideTextStyle: TextStyle(color: Colors.white38),
                cellMargin: EdgeInsets.all(2.0),
                selectedDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                todayDecoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.green, width: 1.5),
                  ),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _carregarDados();
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                _carregarDados();
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _agendamentosDoDia.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum agendamento para este dia.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 80,
                    ), // Espaço extra pro botão +
                    itemCount: _agendamentosDoDia.length,
                    itemBuilder: (context, index) {
                      final agendamento = _agendamentosDoDia[index];
                      final nomeCliente =
                          agendamento.clienteNome ?? 'Cliente Desconhecido';
                      final hora = DateFormat(
                        'HH:mm',
                      ).format(DateTime.parse(agendamento.dataHora));

                      Color statusColor = Colors.grey;
                      if (agendamento.status == 'Pendente') {
                        statusColor = Colors.orange;
                      }
                      if (agendamento.status == 'Concluído') {
                        statusColor = Colors.green;
                      }
                      if (agendamento.status == 'Cancelado') {
                        statusColor = Colors.red;
                      }

                      return Card(
                        color: const Color(0xFF1E1E1E),
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 12,
                                bottom: 0,
                              ),
                              child: Text(
                                nomeCliente,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 16,
                                      right: 0,
                                      top: 0,
                                      bottom: 4,
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_filled,
                                          color: statusColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hora,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          '•',
                                          style: TextStyle(
                                            color: Colors.white30,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: statusColor.withValues(
                                                  alpha: 0.4,
                                                ),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          agendamento.status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            agendamento.servicos ??
                                                'Nenhum serviço',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (agendamento.clienteObservacoes !=
                                                  null &&
                                              agendamento.clienteObservacoes!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.notes,
                                                  color: Colors.amberAccent,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Obs. Cliente:',
                                                        style: TextStyle(
                                                          color: Colors.amberAccent,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        agendamento
                                                            .clienteObservacoes!,
                                                        style: const TextStyle(
                                                          color: Colors.amberAccent,
                                                          fontSize: 12,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (agendamento.observacao != null &&
                                              agendamento.observacao!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.event_note,
                                                  color: Colors.lightBlueAccent,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Obs. Agendamento:',
                                                        style: TextStyle(
                                                          color: Colors.lightBlueAccent,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        agendamento.observacao!,
                                                        style: const TextStyle(
                                                          color: Colors.lightBlueAccent,
                                                          fontSize: 12,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 16,
                                    left: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (agendamento.status == 'Pendente') ...[
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: const Icon(
                                            Icons.message_outlined,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          tooltip: 'Enviar Lembrete WhatsApp',
                                          onPressed: () =>
                                              _enviarLembreteWhatsApp(
                                                  agendamento),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      PopupMenuButton<String>(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                        ),
                                        color: Colors.grey[900],
                                        onSelected: (value) {
                                          if (value == 'excluir') {
                                            _excluirAgendamento(
                                                agendamento.id!);
                                          } else {
                                            _atualizarStatus(
                                                agendamento, value);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'Pendente',
                                            child: Text(
                                              'Marcar Pendente',
                                              style: TextStyle(
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'Concluído',
                                            child: Text(
                                              'Marcar Concluído',
                                              style: TextStyle(
                                                  color: Colors.green),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'Cancelado',
                                            child: Text(
                                              'Cancelar Agendamento',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem<String>(
                                            value: null,
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _editarAgendamento(
                                                        agendamento,
                                                      );
                                                    },
                                                    child: const Text(
                                                      'Editar',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const Text(
                                                    ' | ',
                                                    style: TextStyle(
                                                      color: Colors.white30,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _excluirAgendamento(
                                                        agendamento.id!,
                                                      );
                                                    },
                                                    child: const Text(
                                                      'Excluir',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Builder(
                              builder: (context) {
                                final fichaResumo = _obterFichaResumo(
                                  agendamento.clienteFichaSaude,
                                );
                                if (fichaResumo.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.health_and_safety,
                                            color: Colors.redAccent,
                                            size: 14,
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Ficha de Saúde:',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fichaResumo.join(' | '),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgendamentoFormScreen(
                dataSelecionada: _selectedDay ?? DateTime.now(),
              ),
            ),
          );
          _carregarDados();
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  List<String> _obterFichaResumo(String? fichaSaudeRaw) {
    final map = parseFichaSaude(fichaSaudeRaw);
    final List<String> list = [];
    if (map['alergia']?['sim'] == true) {
      final obs = map['alergia']?['obs'] ?? '';
      list.add('Alergias: ${obs.isNotEmpty ? obs : 'Sim'}');
    }
    if (map['diabetes']?['sim'] == true) {
      final obs = map['diabetes']?['obs'] ?? '';
      list.add('Diabetes: ${obs.isNotEmpty ? obs : 'Sim'}');
    }
    if (map['circulatorio']?['sim'] == true) {
      final obs = map['circulatorio']?['obs'] ?? '';
      list.add('Circulatório: ${obs.isNotEmpty ? obs : 'Sim'}');
    }
    final outros = map['outros'] ?? '';
    if (outros.isNotEmpty) {
      list.add('Outros: $outros');
    }
    return list;
  }
}
