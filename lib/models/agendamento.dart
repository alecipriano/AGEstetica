class Agendamento {
  final int? id;
  final int clienteId;
  final String dataHora;
  final String status;
  final String? observacao;
  final int duracaoMinutos;
  final String? clienteNome;
  final String? clienteTelefone;
  final String? clienteObservacoes;
  final String? servicos;

  final String? clienteFichaSaude;

  Agendamento({
    this.id,
    required this.clienteId,
    required this.dataHora,
    required this.status,
    this.observacao,
    required this.duracaoMinutos,
    this.clienteNome,
    this.clienteTelefone,
    this.clienteObservacoes,
    this.clienteFichaSaude,
    this.servicos,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'data_hora': dataHora,
      'status': status,
      'observacao': observacao,
      'duracao_minutos': duracaoMinutos,
    };
  }

  factory Agendamento.fromMap(Map<String, dynamic> map) {
    return Agendamento(
      id: map['id'],
      clienteId: map['cliente_id'],
      dataHora: map['data_hora'],
      status: map['status'],
      observacao: map['observacao'],
      duracaoMinutos: map['duracao_minutos'] ?? 0,
      clienteNome: map['cliente_nome'],
      clienteTelefone: map['cliente_telefone'],
      clienteObservacoes: map['cliente_observacoes'],
      clienteFichaSaude: map['cliente_ficha_saude'],
      servicos: map['servicos'],
    );
  }
}

class AgendamentoServico {
  final int? id;
  final int? agendamentoId;
  final int servicoId;
  final double precoCobrado;

  AgendamentoServico({
    this.id,
    this.agendamentoId,
    required this.servicoId,
    required this.precoCobrado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agendamento_id': agendamentoId,
      'servico_id': servicoId,
      'preco_cobrado': precoCobrado,
    };
  }

  factory AgendamentoServico.fromMap(Map<String, dynamic> map) {
    return AgendamentoServico(
      id: map['id'],
      agendamentoId: map['agendamento_id'],
      servicoId: map['servico_id'],
      precoCobrado: map['preco_cobrado'],
    );
  }
}
