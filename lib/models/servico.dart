class Servico {
  final int? id;
  final String nome;
  final double preco;
  final int tempoEstimado;

  Servico({
    this.id,
    required this.nome,
    required this.preco,
    this.tempoEstimado = 30,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'preco': preco,
      'tempo_estimado': tempoEstimado,
    };
  }

  factory Servico.fromMap(Map<String, dynamic> map) {
    return Servico(
      id: map['id']?.toInt(),
      nome: map['nome'],
      preco: map['preco']?.toDouble() ?? 0.0,
      tempoEstimado: map['tempo_estimado']?.toInt() ?? 30,
    );
  }
}
