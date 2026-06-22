import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../models/agendamento.dart';
import '../database/database_helper.dart';

class ClientePerfilScreen extends StatefulWidget {
  final Cliente cliente;

  const ClientePerfilScreen({super.key, required this.cliente});

  @override
  State<ClientePerfilScreen> createState() => _ClientePerfilScreenState();
}

class _ClientePerfilScreenState extends State<ClientePerfilScreen> {
  late Future<List<Agendamento>> _agendamentosFuture;
  late Future<double> _totalGastoFuture;
  final Map<int, List<Map<String, dynamic>>> _servicosCache = {};
  final _obsController = TextEditingController();
  
  bool _temAlergia = false;
  final _alergiaController = TextEditingController();
  bool _temDiabetes = false;
  final _diabetesController = TextEditingController();
  bool _temCirculatorio = false;
  final _circulatorioController = TextEditingController();
  final _outrosObsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _obsController.text = widget.cliente.observacoes ?? '';
    
    final map = _parseFichaSaude(widget.cliente.fichaSaude);
    _temAlergia = map['alergia']?['sim'] ?? false;
    _alergiaController.text = map['alergia']?['obs'] ?? '';
    _temDiabetes = map['diabetes']?['sim'] ?? false;
    _diabetesController.text = map['diabetes']?['obs'] ?? '';
    _temCirculatorio = map['circulatorio']?['sim'] ?? false;
    _circulatorioController.text = map['circulatorio']?['obs'] ?? '';
    _outrosObsController.text = map['outros'] ?? '';
    
    _carregarHistorico();
  }

  @override
  void dispose() {
    _obsController.dispose();
    _alergiaController.dispose();
    _diabetesController.dispose();
    _circulatorioController.dispose();
    _outrosObsController.dispose();
    super.dispose();
  }

  void _carregarHistorico() {
    setState(() {
      _agendamentosFuture = DatabaseHelper.instance.getAgendamentosPorCliente(widget.cliente.id!);
      _totalGastoFuture = DatabaseHelper.instance.getTotalGastoPorCliente(widget.cliente.id!);
    });
  }

  Future<void> _salvarObservacoes() async {
    final clienteAtualizado = Cliente(
      id: widget.cliente.id,
      nome: widget.cliente.nome,
      telefone: widget.cliente.telefone,
      observacoes: _obsController.text.trim(),
      fichaSaude: jsonEncode({
        'alergia': {'sim': _temAlergia, 'obs': _alergiaController.text.trim()},
        'diabetes': {'sim': _temDiabetes, 'obs': _diabetesController.text.trim()},
        'circulatorio': {'sim': _temCirculatorio, 'obs': _circulatorioController.text.trim()},
        'outros': _outrosObsController.text.trim(),
      }),
    );
    
    try {
      await DatabaseHelper.instance.updateCliente(clienteAtualizado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar informações: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getServicosDetalhes(int agendamentoId) async {
    if (_servicosCache.containsKey(agendamentoId)) {
      return _servicosCache[agendamentoId]!;
    }
    final detalhes = await DatabaseHelper.instance.getServicosDetalhesPorAgendamento(agendamentoId);
    _servicosCache[agendamentoId] = detalhes;
    return detalhes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Perfil do Cliente'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Header com informações do cliente
          Padding(
            padding: const EdgeInsets.only(left: 17.0, right: 17.0, top: 10.0),
            child: Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.deepPurple, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        widget.cliente.nome.isNotEmpty ? widget.cliente.nome[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.cliente.nome,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatarTelefone(widget.cliente.telefone),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<double>(
                      future: _totalGastoFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Calculando...', style: TextStyle(color: Colors.white38, fontSize: 14));
                        }
                        final total = snapshot.data ?? 0.0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'Total Gasto: R\$ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17.0),
            child: Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.notes, color: Colors.deepPurpleAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Anotações e Ficha de Saúde',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _obsController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Anotações e Preferências',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                        hintText: 'Ex: Alérgica a acetona, tons nude...',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                        fillColor: Colors.black26,
                        filled: true,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple, width: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Possui Alergias?', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: _temAlergia,
                      activeColor: Colors.green,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _temAlergia = val ?? false;
                        });
                      },
                    ),
                    if (_temAlergia) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _alergiaController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Quais alergias?',
                          labelStyle: TextStyle(fontSize: 12, color: Colors.white70),
                          hintText: 'Ex: esmalte, acetona, látex...',
                          hintStyle: TextStyle(color: Colors.white38),
                          fillColor: Colors.black26,
                          filled: true,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple, width: 1)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Possui Diabetes?', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: _temDiabetes,
                      activeColor: Colors.green,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _temDiabetes = val ?? false;
                        });
                      },
                    ),
                    if (_temDiabetes) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _diabetesController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Observações de Diabetes (opcional)',
                          labelStyle: TextStyle(fontSize: 12, color: Colors.white70),
                          hintText: 'Ex: tipo 1, uso de insulina...',
                          hintStyle: TextStyle(color: Colors.white38),
                          fillColor: Colors.black26,
                          filled: true,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple, width: 1)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Problemas Circulatórios / Hipertensão?', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: _temCirculatorio,
                      activeColor: Colors.green,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _temCirculatorio = val ?? false;
                        });
                      },
                    ),
                    if (_temCirculatorio) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _circulatorioController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Observações de circulação',
                          labelStyle: TextStyle(fontSize: 12, color: Colors.white70),
                          hintText: 'Ex: hipertensa, varizes...',
                          hintStyle: TextStyle(color: Colors.white38),
                          fillColor: Colors.black26,
                          filled: true,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple, width: 1)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _outrosObsController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Outras Informações de Saúde',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.white70),
                        hintText: 'Ex: gestante, uso de anticoagulante...',
                        hintStyle: TextStyle(color: Colors.white38),
                        fillColor: Colors.black26,
                        filled: true,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple, width: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _salvarObservacoes,
                        icon: const Icon(Icons.save, size: 16, color: Colors.white),
                        label: const Text('Salvar Informações', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Título do Histórico
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 17.0, vertical: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Histórico de Agendamentos',
                style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          // Lista de Histórico
          Expanded(
            child: FutureBuilder<List<Agendamento>>(
              future: _agendamentosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Erro ao carregar histórico.', style: TextStyle(color: Colors.red)));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Nenhum serviço registrado ainda.', style: TextStyle(color: Colors.white54)));
                }

                final agendamentos = snapshot.data!;
                return ListView.builder(
                  itemCount: agendamentos.length,
                  itemBuilder: (context, index) {
                    final agendamento = agendamentos[index];
                    final dataHora = DateTime.parse(agendamento.dataHora);
                    final dataFormatada = DateFormat('dd/MM/yyyy - HH:mm').format(dataHora);

                    Color statusColor = Colors.grey;
                    if (agendamento.status == 'Pendente') statusColor = Colors.orange;
                    if (agendamento.status == 'Concluído') statusColor = Colors.green;
                    if (agendamento.status == 'Cancelado') statusColor = Colors.red;

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getServicosDetalhes(agendamento.id!),
                      builder: (context, servicosSnapshot) {
                        if (!servicosSnapshot.hasData) {
                          return const Card(
                            color: Color(0xFF1E1E1E),
                            margin: EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                            child: ListTile(title: Text('Carregando serviços...', style: TextStyle(color: Colors.white54))),
                          );
                        }

                        final servicosDetalhes = servicosSnapshot.data!;
                        final totalCobrado = servicosDetalhes.fold(0.0, (sum, item) => sum + (item['preco_cobrado'] as double));

                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ExpansionTile(
                            iconColor: Colors.white,
                            collapsedIconColor: Colors.white54,
                            title: Text(
                              dataFormatada,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Status: ${agendamento.status} | Total: R\$ ${totalCobrado.toStringAsFixed(2)}',
                              style: TextStyle(color: statusColor),
                            ),
                            children: [
                              Container(
                                color: Colors.black12,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('Serviços Realizados:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ...servicosDetalhes.map((s) => Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('- ${s['nome']}', style: const TextStyle(color: Colors.white)),
                                        Text('R\$ ${s['preco_cobrado'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                                      ],
                                    )),
                                    if (agendamento.observacao != null && agendamento.observacao!.isNotEmpty) ...[
                                      const Divider(color: Colors.white24),
                                      const Text('Observação:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                      Text(agendamento.observacao!, style: const TextStyle(color: Colors.white)),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _formatarTelefone(String telefone) {
  final apenasDigitos = telefone.replaceAll(RegExp(r'\D'), '');
  if (apenasDigitos.isEmpty) return telefone;

  final ddd = apenasDigitos.substring(0, apenasDigitos.length < 2 ? apenasDigitos.length : 2);
  String formatado = '($ddd';
  if (apenasDigitos.length > 2) {
    formatado += ') ';
    if (apenasDigitos.length <= 10) {
      final parte1 = apenasDigitos.substring(2, apenasDigitos.length < 6 ? apenasDigitos.length : 6);
      formatado += parte1;
      if (apenasDigitos.length > 6) {
        formatado += '-';
        final parte2 = apenasDigitos.substring(6, apenasDigitos.length < 10 ? apenasDigitos.length : 10);
        formatado += parte2;
      }
    } else {
      final parte1 = apenasDigitos.substring(2, apenasDigitos.length < 7 ? apenasDigitos.length : 7);
      formatado += parte1;
      if (apenasDigitos.length > 7) {
        formatado += '-';
        final parte2 = apenasDigitos.substring(7, apenasDigitos.length < 11 ? apenasDigitos.length : 11);
        formatado += parte2;
      }
    }
  }
  return formatado;
}

Map<String, dynamic> _parseFichaSaude(String? rawJson) {
  if (rawJson == null || rawJson.isEmpty) {
    return {
      'alergia': {'sim': false, 'obs': ''},
      'diabetes': {'sim': false, 'obs': ''},
      'circulatorio': {'sim': false, 'obs': ''},
      'outros': '',
    };
  }
  try {
    final parsed = jsonDecode(rawJson);
    if (parsed is Map<String, dynamic>) {
      return {
        'alergia': {
          'sim': parsed['alergia']?['sim'] ?? false,
          'obs': parsed['alergia']?['obs'] ?? '',
        },
        'diabetes': {
          'sim': parsed['diabetes']?['sim'] ?? false,
          'obs': parsed['diabetes']?['obs'] ?? '',
        },
        'circulatorio': {
          'sim': parsed['circulatorio']?['sim'] ?? false,
          'obs': parsed['circulatorio']?['obs'] ?? '',
        },
        'outros': parsed['outros'] ?? '',
      };
    }
  } catch (_) {
    return {
      'alergia': {'sim': false, 'obs': ''},
      'diabetes': {'sim': false, 'obs': ''},
      'circulatorio': {'sim': false, 'obs': ''},
      'outros': rawJson,
    };
  }
  return {
    'alergia': {'sim': false, 'obs': ''},
    'diabetes': {'sim': false, 'obs': ''},
    'circulatorio': {'sim': false, 'obs': ''},
    'outros': '',
  };
}
