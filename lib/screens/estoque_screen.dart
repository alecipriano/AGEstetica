import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/estoque_item.dart';

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({super.key});

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  List<EstoqueItem> _items = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<EstoqueItem> get _filteredItems {
    if (_searchQuery.trim().isEmpty) {
      return _items;
    }
    final query = _searchQuery.toLowerCase();
    return _items.where((item) {
      return item.nome.toLowerCase().contains(query) ||
          (item.detalhe != null && item.detalhe!.toLowerCase().contains(query));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  Future<void> _refreshItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await DatabaseHelper.instance.getEstoqueItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar estoque: $e')),
        );
      }
    }
  }

  void _showFormDialog([EstoqueItem? item]) {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: item?.nome ?? '');
    final quantidadeController = TextEditingController(text: item?.quantidade.toString() ?? '');
    final detalheController = TextEditingController(text: item?.detalhe ?? '');
    final valorController = TextEditingController(text: item?.valor.toStringAsFixed(2).replaceAll('.', ',') ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          item == null ? 'Adicionar Item' : 'Editar Item',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome do Item',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Insira o nome' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantidadeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Quantidade',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  ),
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Insira uma quantidade válida' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: detalheController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Detalhes/Localização (opcional)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: valorController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Valor Pago / Custo',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  ),
                  validator: (v) {
                    final limpo = v?.replaceAll(',', '.') ?? '';
                    if (double.tryParse(limpo) == null) {
                      return 'Insira um valor válido';
                    }
                    return null;
                  },
                ),
              ],
            ),
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
                final novoItem = EstoqueItem(
                  id: item?.id,
                  nome: nomeController.text,
                  quantidade: int.parse(quantidadeController.text),
                  detalhe: detalheController.text,
                  valor: double.parse(valorController.text.replaceAll(',', '.')),
                );

                try {
                  if (item == null) {
                    await DatabaseHelper.instance.insertEstoqueItem(novoItem);
                  } else {
                    await DatabaseHelper.instance.updateEstoqueItem(novoItem);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _refreshItems();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar item no estoque: $e')),
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

  void _deleteItem(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Excluir Item', style: TextStyle(color: Colors.white)),
        content: const Text('Tem certeza que deseja remover este item do estoque?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await DatabaseHelper.instance.deleteEstoqueItem(id);
      _refreshItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Pesquisar produto...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum produto cadastrado no estoque.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum produto encontrado.',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              final isCritico = item.quantidade <= 3;

                              return Card(
                                color: const Color(0xFF1E1E1E),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCritico
                                        ? Colors.amber.withValues(alpha: 0.2)
                                        : Colors.deepPurple.withValues(alpha: 0.2),
                                    child: Icon(
                                      isCritico ? Icons.warning_rounded : Icons.inventory_2_outlined,
                                      color: isCritico ? Colors.amber : Colors.deepPurple,
                                    ),
                                  ),
                                  title: Text(
                                    item.nome,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (item.detalhe != null && item.detalhe!.isNotEmpty)
                                        Text('Detalhe: ${item.detalhe}',
                                            style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                      Text('Custo Unitário: R\$ ${item.valor.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.green, fontSize: 13)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isCritico
                                              ? Colors.amber.withValues(alpha: 0.2)
                                              : Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                              color: isCritico ? Colors.amber : Colors.green.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          '${item.quantidade} un',
                                          style: TextStyle(
                                            color: isCritico ? Colors.amber : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                        onPressed: () => _showFormDialog(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteItem(item.id!),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
