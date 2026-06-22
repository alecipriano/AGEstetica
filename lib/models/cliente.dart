class Cliente {
  final int? id;
  final String nome;
  final String telefone;
  final String? observacoes;
  final String? fichaSaude;

  Cliente({
    this.id,
    required this.nome,
    required this.telefone,
    this.observacoes,
    this.fichaSaude,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'telefone': telefone,
      'observacoes': observacoes ?? '',
      'ficha_saude': fichaSaude ?? '',
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id']?.toInt(),
      nome: map['nome'],
      telefone: map['telefone'],
      observacoes: map['observacoes'],
      fichaSaude: map['ficha_saude'],
    );
  }
}
