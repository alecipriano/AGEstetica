import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/cliente.dart';
import 'cliente_perfil_screen.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  late Future<List<Cliente>> _clientesFuture;

  @override
  void initState() {
    super.initState();
    _refreshClientes();
  }

  void _refreshClientes() {
    setState(() {
      _clientesFuture = DatabaseHelper.instance.getClientes();
    });
  }

  void _showFormDialog([Cliente? cliente]) {
    final nomeController = TextEditingController(text: cliente?.nome);
    final telefoneController = TextEditingController(
      text: formatarTelefone(cliente?.telefone ?? ''),
    );

    final fichaSaudeMap = parseFichaSaude(cliente?.fichaSaude);
    bool temAlergia = fichaSaudeMap['alergia']?['sim'] ?? false;
    final alergiaController = TextEditingController(
      text: fichaSaudeMap['alergia']?['obs'] ?? '',
    );
    bool temDiabetes = fichaSaudeMap['diabetes']?['sim'] ?? false;
    final diabetesController = TextEditingController(
      text: fichaSaudeMap['diabetes']?['obs'] ?? '',
    );
    bool temCirculatorio = fichaSaudeMap['circulatorio']?['sim'] ?? false;
    final circulatorioController = TextEditingController(
      text: fichaSaudeMap['circulatorio']?['obs'] ?? '',
    );
    final outrosObsController = TextEditingController(
      text: fichaSaudeMap['outros'] ?? '',
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        scrollable: true,
        title: Text(
          cliente == null ? 'Novo Cliente' : 'Editar Cliente',
          style: const TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: telefoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Telefone/WhatsApp (com DDD)',
                  errorMaxLines: 3,
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [TelefoneInputFormatter()],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Obrigatório';
                  }
                  final apenasDigitos = value.replaceAll(RegExp(r'\D'), '');
                  if (apenasDigitos.length < 10 || apenasDigitos.length > 11) {
                    return 'Telefone inválido (deve ter 10 ou 11 dígitos com DDD)';
                  }

                  final primeiroDigitoAposDDD = apenasDigitos[2];

                  if (apenasDigitos.length == 11) {
                    if (primeiroDigitoAposDDD != '9') {
                      return 'Celular inválido (deve começar com 9 após o DDD)';
                    }
                  } else if (apenasDigitos.length == 10) {
                    const digitosValidosFixo = ['2', '3', '4', '5'];
                    if (!digitosValidosFixo.contains(primeiroDigitoAposDDD)) {
                      return 'Telefone fixo inválido (deve começar com 2, 3, 4 ou 5 após o DDD)';
                    }
                  }
                  return null;
                },
              ),
              const Divider(color: Colors.white24, height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ficha de Saúde',
                  style: TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        title: const Text(
                          'Possui Alergias?',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        value: temAlergia,
                        activeColor: Colors.green,
                        checkColor: Colors.black,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() {
                            temAlergia = val ?? false;
                          });
                        },
                      ),
                      if (temAlergia) ...[
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: alergiaController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quais alergias?',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            hintText: 'Ex: esmalte, acetona, látex...',
                            hintStyle: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text(
                          'Possui Diabetes?',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        value: temDiabetes,
                        activeColor: Colors.green,
                        checkColor: Colors.black,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() {
                            temDiabetes = val ?? false;
                          });
                        },
                      ),
                      if (temDiabetes) ...[
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: diabetesController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Observações de Diabetes (opcional)',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            hintText: 'Ex: tipo 1, uso de insulina...',
                            hintStyle: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text(
                          'Problemas Circulatórios / Hipertensão?',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        value: temCirculatorio,
                        activeColor: Colors.green,
                        checkColor: Colors.black,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() {
                            temCirculatorio = val ?? false;
                          });
                        },
                      ),
                      if (temCirculatorio) ...[
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: circulatorioController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Observações de circulação',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            hintText: 'Ex: hipertensa, varizes...',
                            hintStyle: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: outrosObsController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Outras Informações de Saúde',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          hintText: 'Ex: gestante, uso de anticoagulante...',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final telLimpo = telefoneController.text.replaceAll(
                  RegExp(r'\D'),
                  '',
                );
                final clientes = await DatabaseHelper.instance.getClientes();

                final existeDuplicado = clientes.any((c) {
                  if (cliente != null && c.id == cliente.id) return false;
                  final cTelLimpo = c.telefone.replaceAll(RegExp(r'\D'), '');
                  return cTelLimpo == telLimpo;
                });

                if (existeDuplicado) {
                  if (!context.mounted) return;
                  final prosseguir = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text(
                        'Telefone Duplicado',
                        style: TextStyle(color: Colors.orange),
                      ),
                      content: const Text(
                        'Já existe um cliente cadastrado com este telefone.\nDeseja cadastrar mesmo assim?',
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Sim, Cadastrar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (prosseguir != true) return;
                }

                final novoCliente = Cliente(
                  id: cliente?.id,
                  nome: nomeController.text,
                  telefone: telefoneController.text,
                  observacoes: cliente?.observacoes,
                  fichaSaude: jsonEncode({
                    'alergia': {
                      'sim': temAlergia,
                      'obs': alergiaController.text,
                    },
                    'diabetes': {
                      'sim': temDiabetes,
                      'obs': diabetesController.text,
                    },
                    'circulatorio': {
                      'sim': temCirculatorio,
                      'obs': circulatorioController.text,
                    },
                    'outros': outrosObsController.text,
                  }),
                );

                try {
                  if (cliente == null) {
                    await DatabaseHelper.instance.insertCliente(novoCliente);
                  } else {
                    await DatabaseHelper.instance.updateCliente(novoCliente);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _refreshClientes();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar cliente: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteCliente(int id) async {
    // Apresenta indicador de carregamento enquanto faz a consulta de segurança
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
    );

    try {
      final agendamentos = await DatabaseHelper.instance
          .getAgendamentosPorCliente(id);
      if (mounted) Navigator.pop(context); // Remove o indicador de carregamento

      final temConcluidos = agendamentos.any((a) => a.status == 'Concluído');

      if (temConcluidos) {
        // Bloqueia a exclusão completamente se houver histórico financeiro associado
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Exclusão Bloqueada',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Não é possível excluir este cliente pois ele possui histórico de atendimentos concluídos.\n\n'
                'A exclusão apagaria esses agendamentos históricos e distorceria permanentemente seus relatórios e faturamento financeiro. Você pode apenas editar os dados do cliente.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      final temQualquerAgendamento = agendamentos.isNotEmpty;
      final mensagem = temQualquerAgendamento
          ? 'Este cliente possui agendamentos cadastrados (pendentes ou cancelados).\n\n'
                'Tem certeza de que deseja excluí-lo? Todos os agendamentos vinculados a ele serão excluídos permanentemente.'
          : 'Tem certeza de que deseja excluir este cliente?';

      if (mounted) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Excluir Cliente',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              mensagem,
              style: const TextStyle(color: Colors.white70),
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
                  'Sim, Excluir',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmar != true) return;

        await DatabaseHelper.instance.deleteCliente(id);
        _refreshClientes();
      }
    } catch (e) {
      if (mounted) {
        // Se o indicador de carregamento ainda estiver na tela por algum erro
        try {
          Navigator.pop(context);
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao excluir cliente: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Cliente>>(
        future: _clientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          } else if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar clientes',
                style: TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum cliente cadastrado.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final clientes = snapshot.data!;
          return ListView.builder(
            itemCount: clientes.length,
            itemBuilder: (context, index) {
              final cliente = clientes[index];
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClientePerfilScreen(cliente: cliente),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      cliente.nome.isNotEmpty
                          ? cliente.nome[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    cliente.nome,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    formatarTelefone(cliente.telefone),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.green),
                        onPressed: () => _showFormDialog(cliente),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCliente(cliente.id!),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

String formatarTelefone(String telefone) {
  final apenasDigitos = telefone.replaceAll(RegExp(r'\D'), '');
  if (apenasDigitos.isEmpty) return telefone;

  final ddd = apenasDigitos.substring(
    0,
    apenasDigitos.length < 2 ? apenasDigitos.length : 2,
  );
  String formatado = '($ddd';
  if (apenasDigitos.length > 2) {
    formatado += ') ';
    if (apenasDigitos.length <= 10) {
      final parte1 = apenasDigitos.substring(
        2,
        apenasDigitos.length < 6 ? apenasDigitos.length : 6,
      );
      formatado += parte1;
      if (apenasDigitos.length > 6) {
        formatado += '-';
        final parte2 = apenasDigitos.substring(
          6,
          apenasDigitos.length < 10 ? apenasDigitos.length : 10,
        );
        formatado += parte2;
      }
    } else {
      final parte1 = apenasDigitos.substring(
        2,
        apenasDigitos.length < 7 ? apenasDigitos.length : 7,
      );
      formatado += parte1;
      if (apenasDigitos.length > 7) {
        formatado += '-';
        final parte2 = apenasDigitos.substring(
          7,
          apenasDigitos.length < 11 ? apenasDigitos.length : 11,
        );
        formatado += parte2;
      }
    }
  }
  return formatado;
}

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Se estiver apagando, deixa passar
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      return newValue;
    }

    final apenasDigitos = text.replaceAll(RegExp(r'\D'), '');
    if (apenasDigitos.length > 11) {
      return oldValue;
    }

    final formatado = formatarTelefone(apenasDigitos);

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}

Map<String, dynamic> parseFichaSaude(String? rawJson) {
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
