import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/agendamento.dart';
import '../models/cliente.dart';
import '../models/servico.dart';
import 'clientes_screen.dart';

class AgendamentoFormScreen extends StatefulWidget {
  final DateTime dataSelecionada;
  final Agendamento? agendamento;

  const AgendamentoFormScreen({
    super.key,
    required this.dataSelecionada,
    this.agendamento,
  });

  @override
  State<AgendamentoFormScreen> createState() => _AgendamentoFormScreenState();
}

class _AgendamentoFormScreenState extends State<AgendamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Cliente> _clientes = [];
  List<Servico> _servicosDisponiveis = [];

  Cliente? _clienteSelecionado;
  TimeOfDay? _horaSelecionada;
  final List<Servico> _servicosSelecionados = [];
  final TextEditingController _observacaoController = TextEditingController();

  double _totalPrevisto = 0.0;
  int _duracaoPrevista = 0;

  bool _diaLotado = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _verificarLimiteHorario() async {
    try {
      final inicio = await DatabaseHelper.instance.getConfig(
        'horario_inicio',
        '08:00',
      );
      final fim = await DatabaseHelper.instance.getConfig(
        'horario_fim',
        '18:00',
      );

      final inicioMin = _parseTimeToMinutes(inicio);
      final fimMin = _parseTimeToMinutes(fim);
      final limiteMinutos = fimMin - inicioMin;

      final agendamentos = await DatabaseHelper.instance.getAgendamentosPorData(
        widget.dataSelecionada,
      );
      final agendamentosAtivos = agendamentos.where(
        (a) => a.status != 'Cancelado',
      );

      int totalMinutos = 0;
      for (var a in agendamentosAtivos) {
        totalMinutos += a.duracaoMinutos;
      }

      setState(() {
        _diaLotado = (totalMinutos + _duracaoPrevista) > limiteMinutos;
      });
    } catch (_) {}
  }

  Future<void> _carregarDados() async {
    final clientes = await DatabaseHelper.instance.getClientes();
    final servicos = await DatabaseHelper.instance.getServicos();

    Cliente? clienteSelecionado;
    TimeOfDay? horaSelecionada = _horaSelecionada;
    List<Servico> servicosSelecionados = [];

    if (widget.agendamento != null) {
      try {
        clienteSelecionado = clientes.firstWhere(
          (c) => c.id == widget.agendamento!.clienteId,
        );
      } catch (_) {}

      final dt = DateTime.parse(widget.agendamento!.dataHora);
      horaSelecionada = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _observacaoController.text = widget.agendamento!.observacao ?? '';

      final agendamentoServicos = await DatabaseHelper.instance
          .getServicosDoAgendamento(widget.agendamento!.id!);
      for (var as in agendamentoServicos) {
        try {
          final s = servicos.firstWhere((s) => s.id == as.servicoId);
          servicosSelecionados.add(s);
        } catch (_) {}
      }
    }

    setState(() {
      _clientes = clientes;
      _servicosDisponiveis = servicos;
      if (widget.agendamento != null) {
        _clienteSelecionado = clienteSelecionado;
        _horaSelecionada = horaSelecionada;
        _servicosSelecionados.clear();
        _servicosSelecionados.addAll(servicosSelecionados);
      }
    });
    _atualizarTotal();
  }

  void _atualizarTotal() {
    setState(() {
      _totalPrevisto = _servicosSelecionados.fold(
        0,
        (sum, item) => sum + item.preco,
      );
      _duracaoPrevista = _servicosSelecionados.fold(
        0,
        (sum, item) => sum + item.tempoEstimado,
      );
    });
    _verificarLimiteHorario();
  }

  void _salvar() async {
    if (_formKey.currentState!.validate()) {
      if (_clienteSelecionado == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selecione um cliente!')));
        return;
      }
      if (_horaSelecionada == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selecione um horário!')));
        return;
      }
      if (_servicosSelecionados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione pelo menos um serviço!')),
        );
        return;
      }

      final dataHoraInicio = DateTime(
        widget.dataSelecionada.year,
        widget.dataSelecionada.month,
        widget.dataSelecionada.day,
        _horaSelecionada!.hour,
        _horaSelecionada!.minute,
      );

      final dataHoraFim = dataHoraInicio.add(
        Duration(minutes: _duracaoPrevista),
      );

      bool temConflito = false;
      try {
        final agendamentosDoDia = await DatabaseHelper.instance
            .getAgendamentosPorData(dataHoraInicio);
        final agendamentosAtivos = agendamentosDoDia.where(
          (a) => a.status != 'Cancelado' && a.id != widget.agendamento?.id,
        );

        for (var a in agendamentosAtivos) {
          final aInicio = DateTime.parse(a.dataHora);
          final aFim = aInicio.add(Duration(minutes: a.duracaoMinutos));

          if (dataHoraInicio.isBefore(aFim) && dataHoraFim.isAfter(aInicio)) {
            temConflito = true;
            break;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao verificar conflito de horários: $e'),
            ),
          );
        }
        return;
      }

      if (temConflito) {
        if (!mounted) return;
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Choque de Horários!',
              style: TextStyle(color: Colors.orange),
            ),
            content: const Text(
              'Já existe um agendamento conflitante neste período.\nTem certeza que deseja agendar mesmo assim?',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Sim, Confirmar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        if (confirmar != true) return;
      }

      final agendamento = Agendamento(
        id: widget.agendamento?.id,
        clienteId: _clienteSelecionado!.id!,
        dataHora: dataHoraInicio.toIso8601String(),
        status: widget.agendamento?.status ?? 'Pendente',
        observacao: _observacaoController.text,
        duracaoMinutos: _duracaoPrevista,
      );

      final agendamentoServicos = _servicosSelecionados
          .map(
            (s) => AgendamentoServico(servicoId: s.id!, precoCobrado: s.preco),
          )
          .toList();

      try {
        if (widget.agendamento == null) {
          await DatabaseHelper.instance.insertAgendamento(
            agendamento,
            agendamentoServicos,
          );
        } else {
          await DatabaseHelper.instance.updateAgendamento(
            agendamento,
            agendamentoServicos,
          );
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar agendamento: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.agendamento == null
              ? 'Novo Agendamento'
              : 'Editar Agendamento',
        ),
        backgroundColor: Colors.black,
      ),
      body: _clientes.isEmpty
          ? const Center(
              child: Text(
                'Cadastre clientes primeiro!',
                style: TextStyle(color: Colors.white),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Data Selecionada',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(widget.dataSelecionada),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<Cliente>(
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        filled: true,
                        fillColor: Color(0xFF1E1E1E),
                      ),
                      initialValue: _clienteSelecionado,
                      items: _clientes
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.nome)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _clienteSelecionado = val),
                    ),
                    if (_clienteSelecionado != null) ...[
                      Builder(
                        builder: (context) {
                          final summary = _getHealthSummary(
                            _clienteSelecionado!,
                          );
                          if (summary.isEmpty) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.health_and_safety,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Atenção - Ficha de Saúde',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...summary.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    ListTile(
                      tileColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: const Text(
                        'Horário do Atendimento',
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        _horaSelecionada == null
                            ? 'Toque para selecionar'
                            : _horaSelecionada!.format(context),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.white,
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() => _horaSelecionada = time);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Serviços (Selecione um ou mais)',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    _servicosDisponiveis.isEmpty
                        ? const Text(
                            'Nenhum serviço cadastrado.',
                            style: TextStyle(color: Colors.red),
                          )
                        : Container(
                            height:
                                155, // Altura ideal para exibir cerca de 3 serviços simultâneos com peeking
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ListView.builder(
                              itemCount: _servicosDisponiveis.length,
                              itemBuilder: (context, index) {
                                final servico = _servicosDisponiveis[index];
                                final isSelected = _servicosSelecionados
                                    .contains(servico);
                                return CheckboxListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  title: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${servico.nome} - ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              'R\$ ${servico.preco.toStringAsFixed(2)} | ${servico.tempoEstimado} min',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  value: isSelected,
                                  activeColor: Colors.deepPurple,
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                  onChanged: (bool? checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _servicosSelecionados.add(servico);
                                      } else {
                                        _servicosSelecionados.remove(servico);
                                      }
                                      _atualizarTotal();
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                    if (_diaLotado) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Atenção: A agenda deste dia atingiu o limite de horário configurado para atendimento!',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _observacaoController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Observação (Opcional)',
                        filled: true,
                        fillColor: Color(0xFF1E1E1E),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.deepPurple),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Previsto:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Duração: $_duracaoPrevista min',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'R\$ ${_totalPrevisto.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.agendamento == null
                            ? 'SALVAR AGENDAMENTO'
                            : 'SALVAR ALTERAÇÕES',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<String> _getHealthSummary(Cliente client) {
    final map = parseFichaSaude(client.fichaSaude);
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
      list.add(
        'Problemas Circulatórios/Hipertensão: ${obs.isNotEmpty ? obs : 'Sim'}',
      );
    }
    final outros = map['outros'] ?? '';
    if (outros.isNotEmpty) {
      list.add('Outras Obs: $outros');
    }

    return list;
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }
}
