class EstoqueItem {
  final int? id;
  final String nome;
  final int quantidade;
  final String? detalhe;
  final double valor;

  EstoqueItem({
    this.id,
    required this.nome,
    required this.quantidade,
    this.detalhe,
    required this.valor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
      'detalhe': detalhe,
      'valor': valor,
    };
  }

  factory EstoqueItem.fromMap(Map<String, dynamic> map) {
    return EstoqueItem(
      id: map['id'],
      nome: map['nome'],
      quantidade: map['quantidade'],
      detalhe: map['detalhe'],
      valor: (map['valor'] as num).toDouble(),
    );
  }
}
