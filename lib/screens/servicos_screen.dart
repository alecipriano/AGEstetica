import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/servico.dart';

class ServicosScreen extends StatefulWidget {
  final bool showAppBar;
  const ServicosScreen({super.key, this.showAppBar = true});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

class _ServicosScreenState extends State<ServicosScreen> {
  late Future<List<Servico>> _servicosFuture;

  @override
  void initState() {
    super.initState();
    _refreshServicos();
  }

  void _refreshServicos() {
    setState(() {
      _servicosFuture = DatabaseHelper.instance.getServicos();
    });
  }

  void _showFormDialog([Servico? servico]) {
    final nomeController = TextEditingController(text: servico?.nome);
    final precoController = TextEditingController(text: servico?.preco.toString());
    final tempoController = TextEditingController(text: servico?.tempoEstimado.toString() ?? '30');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(servico == null ? 'Novo Serviço' : 'Editar Serviço', style: const TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome do Serviço (ex: Mão Simples)'),
                validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: precoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Obrigatório';
                  }
                  final limpo = value.replaceAll(',', '.');
                  if (double.tryParse(limpo) == null) {
                    return 'Insira um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: tempoController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Tempo Estimado (minutos)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Obrigatório';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Insira um número inteiro válido';
                  }
                  return null;
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
                final novoServico = Servico(
                  id: servico?.id,
                  nome: nomeController.text,
                  preco: double.parse(precoController.text.replaceAll(',', '.')),
                  tempoEstimado: int.tryParse(tempoController.text) ?? 30,
                );

                try {
                  if (servico == null) {
                    await DatabaseHelper.instance.insertServico(novoServico);
                  } else {
                    await DatabaseHelper.instance.updateServico(novoServico);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _refreshServicos();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar serviço: $e')),
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

  void _deleteServico(int id) async {
    // Apresenta indicador de carregamento enquanto faz a consulta de segurança
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
    );

    try {
      final jaUtilizado = await DatabaseHelper.instance.isServicoVinculado(id);
      if (mounted) Navigator.pop(context); // Remove o indicador de carregamento

      if (jaUtilizado) {
        // Bloqueia a exclusão completamente se houver histórico financeiro associado
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Exclusão Bloqueada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Não é possível excluir este serviço pois ele já foi prestado em agendamentos históricos do salão.\n\n'
                'A exclusão apagaria a referência deste serviço e afetaria permanentemente seus relatórios e estatísticas financeiras de faturamento. Você pode apenas editar os dados ou preço do serviço.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Excluir Serviço', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              'Tem certeza de que deseja excluir este serviço?\n'
              'Ele será removido permanentemente da lista de serviços.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sim, Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirmar != true) return;

        await DatabaseHelper.instance.deleteServico(id);
        _refreshServicos();
      }
    } catch (e) {
      if (mounted) {
        // Se o indicador de carregamento ainda estiver na tela por algum erro
        try {
          Navigator.pop(context);
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir serviço: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Serviços Disponíveis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1E1E1E),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: FutureBuilder<List<Servico>>(
        future: _servicosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar serviços', style: TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum serviço cadastrado.', style: TextStyle(color: Colors.white70)));
          }

          final servicos = snapshot.data!;
          return ListView.builder(
            itemCount: servicos.length,
            itemBuilder: (context, index) {
              final servico = servicos[index];
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.spa, color: Colors.white),
                  ),
                  title: Text(servico.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('R\$ ${servico.preco.toStringAsFixed(2)} | ${servico.tempoEstimado} min', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.green),
                        onPressed: () => _showFormDialog(servico),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteServico(servico.id!),
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
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
