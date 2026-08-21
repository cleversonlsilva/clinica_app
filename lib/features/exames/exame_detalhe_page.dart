import 'package:flutter/material.dart';

import 'exames_service.dart';

class ExameDetalhePage extends StatefulWidget {
  const ExameDetalhePage({
    super.key,
    required this.service,
    required this.solicitacaoId,
  });

  final ExamesService service;
  final int solicitacaoId;

  @override
  State<ExameDetalhePage> createState() =>
      _ExameDetalhePageState();
}

class _ExameDetalhePageState
    extends State<ExameDetalhePage> {
  bool _carregando = true;
  String? _erro;
  Map<String, dynamic>? _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final dados = await widget.service.carregarDetalhe(
        solicitacaoId: widget.solicitacaoId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dados = dados;
        _carregando = false;
      });
    } on ExamesException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = e.message;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro =
        'Não foi possível carregar os detalhes dos exames.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes dos exames'),
      ),
      body: _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erro != null) {
      return _buildErro();
    }

    if (_dados == null) {
      return _buildErro(
        mensagem:
        'Não foi possível identificar a solicitação.',
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildCabecalho(),
          const SizedBox(height: 16),
          _buildInformacoesSolicitacao(),
          const SizedBox(height: 16),
          _buildExames(),
          const SizedBox(height: 16),
          _buildObservacoes(),
          const SizedBox(height: 16),
          _buildResultados(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCabecalho() {
    final solicitacao = _mapa('solicitacao');

    final status =
    solicitacao['status']?.toString();

    final data =
    _formatarData(
      solicitacao['data_solicitacao'],
    );

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.biotech_outlined,
                size: 30,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solicitação de exames',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusChip(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformacoesSolicitacao() {
    final solicitacao =
    _mapa('solicitacao');

    final paciente =
    _mapa('paciente');

    final profissional =
    _mapa('profissional');

    final validade =
    _obterInteiro(
      solicitacao['validade_dias'],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildTituloSecao(
              Icons.description_outlined,
              'Informações da solicitação',
            ),
            const SizedBox(height: 16),
            if (_textoValido(paciente['nome']))
              _buildInformacao(
                icone: Icons.person_outline,
                titulo: 'Paciente',
                valor:
                paciente['nome'].toString(),
              ),
            if (_textoValido(profissional['nome']))
              _buildInformacao(
                icone:
                Icons.medical_services_outlined,
                titulo: 'Profissional',
                valor:
                profissional['nome'].toString(),
              ),
            if (validade > 0)
              _buildInformacao(
                icone: Icons.event_outlined,
                titulo: 'Validade',
                valor:
                '$validade dias',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExames() {
    final exames =
    _listaMapas('exames');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildTituloSecao(
              Icons.science_outlined,
              'Exames solicitados',
            ),
            const SizedBox(height: 14),
            if (exames.isEmpty)
              const Text(
                'Nenhum exame encontrado nesta solicitação.',
              )
            else
              ...List.generate(
                exames.length,
                    (index) {
                  return _buildExameItem(
                    exames[index],
                    index,
                    exames.length,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExameItem(
      Map<String, dynamic> exame,
      int index,
      int total,
      ) {
    final nome =
    exame['nome']?.toString().trim();

    final categoria =
    exame['categoria']?.toString().trim();

    final descricao =
    exame['descricao']?.toString().trim();

    return Padding(
      padding: EdgeInsets.only(
        bottom: index == total - 1
            ? 0
            : 12,
      ),
      child: Container(
        padding:
        const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.science_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    nome?.isNotEmpty == true
                        ? nome!
                        : 'Exame',
                    style: const TextStyle(
                      fontWeight:
                      FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (categoria?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 4),
                    Text(
                      categoria!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                  if (descricao?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 6),
                    Text(
                      descricao!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservacoes() {
    final solicitacao =
    _mapa('solicitacao');

    final observacoes =
    solicitacao['observacoes']
        ?.toString()
        .trim();

    if (observacoes == null ||
        observacoes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildTituloSecao(
              Icons.notes_outlined,
              'Observações',
            ),
            const SizedBox(height: 12),
            Text(observacoes),
          ],
        ),
      ),
    );
  }

  Widget _buildResultados() {
    final resultados =
    _listaMapas('resultados');

    final solicitacao =
    _mapa('solicitacao');

    final observacao =
    solicitacao['resultado_observacao']
        ?.toString()
        .trim();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildTituloSecao(
              Icons.attach_file_outlined,
              'Resultados',
            ),
            const SizedBox(height: 14),
            if (resultados.isEmpty)
              Text(
                'Nenhum resultado anexado.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              )
            else
              ...List.generate(
                resultados.length,
                    (index) {
                  return _buildResultadoItem(
                    resultados[index],
                    index,
                    resultados.length,
                  );
                },
              ),
            if (observacao != null &&
                observacao.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Observação do resultado',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(observacao),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultadoItem(
      Map<String, dynamic> resultado,
      int index,
      int total,
      ) {
    final nome =
    resultado['nome_arquivo']
        ?.toString()
        .trim();

    final observacao =
    resultado['observacao']
        ?.toString()
        .trim();

    final data =
    _formatarData(
      resultado['data'],
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: index == total - 1
            ? 0
            : 12,
      ),
      child: Container(
        padding:
        const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    nome?.isNotEmpty == true
                        ? nome!
                        : 'Resultado',
                    style: const TextStyle(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  if (observacao != null &&
                      observacao.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(observacao),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTituloSecao(
      IconData icone,
      String titulo,
      ) {
    return Row(
      children: [
        Icon(
          icone,
          size: 21,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            titulo,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInformacao({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            size: 19,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(width: 10),
          Text(
            '$titulo:',
            style: const TextStyle(
              fontWeight:
              FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(valor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
      String? status,
      ) {
    final texto =
    _formatarStatus(status);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onSecondaryContainer,
          fontWeight:
          FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildErro({
    String? mensagem,
  }) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 52,
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
            const SizedBox(height: 16),
            Text(
              mensagem ??
                  _erro ??
                  'Não foi possível carregar os detalhes.',
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregar,
              icon:
              const Icon(Icons.refresh),
              label:
              const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _mapa(
      String chave,
      ) {
    final valor = _dados?[chave];

    if (valor is Map) {
      return Map<String, dynamic>.from(
        valor,
      );
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listaMapas(
      String chave,
      ) {
    final valor = _dados?[chave];

    if (valor is! List) {
      return <Map<String, dynamic>>[];
    }

    return valor
        .whereType<Map>()
        .map(
          (item) =>
      Map<String, dynamic>.from(item),
    )
        .toList();
  }

  bool _textoValido(dynamic valor) {
    return valor != null &&
        valor.toString().trim().isNotEmpty;
  }

  int _obterInteiro(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(
      valor?.toString() ?? '',
    ) ??
        0;
  }

  String _formatarData(dynamic valor) {
    if (valor == null) {
      return 'Não informada';
    }

    final texto =
    valor.toString().trim();

    if (texto.isEmpty) {
      return 'Não informada';
    }

    final data =
    DateTime.tryParse(texto);

    if (data == null) {
      return texto;
    }

    final dia =
    data.day.toString().padLeft(
      2,
      '0',
    );

    final mes =
    data.month.toString().padLeft(
      2,
      '0',
    );

    final ano =
    data.year.toString();

    return '$dia/$mes/$ano';
  }

  String _formatarStatus(
      String? status,
      ) {
    if (status == null ||
        status.isEmpty) {
      return 'Não informado';
    }

    switch (status.toLowerCase()) {
      case 'ativo':
        return 'Ativo';

      case 'concluido':
      case 'concluído':
        return 'Concluído';

      case 'cancelado':
        return 'Cancelado';

      default:
        return status;
    }
  }
}