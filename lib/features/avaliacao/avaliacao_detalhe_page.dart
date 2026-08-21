import 'package:flutter/material.dart';

/// Tela de detalhes de uma Avaliação Corporal.
///
/// Recebe uma avaliação já carregada pela camada de serviço
/// e apresenta somente os dados fornecidos pela API.
///
/// A página não realiza comunicação HTTP.
class AvaliacaoDetalhePage extends StatelessWidget {
  const AvaliacaoDetalhePage({
    super.key,
    required this.avaliacao,
  });

  final Map<String, dynamic> avaliacao;

  @override
  Widget build(BuildContext context) {
    final valores = _obterValoresPreenchidos();

    final valoresCalculados = valores
        .where(
          (registro) => _obterCampo(registro)['calculado'] == true,
    )
        .toList();

    final valoresInformados = valores
        .where(
          (registro) =>
      _obterCampo(registro)['calculado'] != true &&
          !_campoCabecalho(registro),
    )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliação Corporal'),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildCabecalho(context),
          const SizedBox(height: 16),
          _buildResumo(context, valores),
          const SizedBox(height: 16),

          if (valoresInformados.isNotEmpty)
            _buildResultados(
              context,
              titulo: 'Medidas e resultados',
              icone: Icons.straighten_outlined,
              valores: valoresInformados,
            ),

          if (valoresInformados.isNotEmpty &&
              valoresCalculados.isNotEmpty)
            const SizedBox(height: 16),

          if (valoresCalculados.isNotEmpty)
            _buildResultados(
              context,
              titulo: 'Resultados calculados',
              icone: Icons.auto_awesome_outlined,
              valores: valoresCalculados,
              calculados: true,
            ),

          if (valores.isEmpty) ...[
            _buildSemResultados(context),
            const SizedBox(height: 16),
          ],

          _buildObservacoes(context),
        ],
      ),
    );
  }

  // ==========================================================
  // CABEÇALHO
  // ==========================================================

  Widget _buildCabecalho(BuildContext context) {
    final data = _formatarData(
      avaliacao['data_avaliacao'],
    );

    final tipo = _formatarTipo(
      avaliacao['tipo'],
    );

    final equipamento =
    avaliacao['equipamento']?.toString().trim();

    final avaliador = _obterValorPorCodigo(
      'avaliador',
    );

    final corScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: corScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.monitor_weight_outlined,
                    size: 28,
                    color: corScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avaliação corporal',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tipo,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                          color:
                          corScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // DATA DA AVALIAÇÃO
            // --------------------------------------------------

            _buildInfoLinha(
              context,
              Icons.calendar_today_outlined,
              'Data',
              data,
            ),

            // --------------------------------------------------
            // EQUIPAMENTO
            // --------------------------------------------------

            if (equipamento != null &&
                equipamento.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoLinha(
                context,
                Icons.devices_outlined,
                'Equipamento',
                equipamento,
              ),
            ],

            // --------------------------------------------------
            // AVALIADOR
            // --------------------------------------------------

            if (avaliador != null &&
                avaliador.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoLinha(
                context,
                Icons.person_outline,
                'Avaliador',
                avaliador,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // RESUMO
  // ==========================================================

  Widget _buildResumo(
      BuildContext context,
      List<Map<String, dynamic>> valores,
      ) {
    final quantidade = valores
        .where(
          (registro) => !_campoCabecalho(registro),
    )
        .length;

    final calculados = valores
        .where(
          (registro) =>
      _obterCampo(registro)['calculado'] == true,
    )
        .length;

    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildIndicadorResumo(
                context,
                Icons.analytics_outlined,
                quantidade.toString(),
                quantidade == 1
                    ? 'resultado registrado'
                    : 'resultados registrados',
              ),
            ),

            if (calculados > 0) ...[
              Container(
                width: 1,
                height: 42,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _buildIndicadorResumo(
                  context,
                  Icons.auto_awesome_outlined,
                  calculados.toString(),
                  calculados == 1
                      ? 'resultado calculado'
                      : 'resultados calculados',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadorResumo(
      BuildContext context,
      IconData icon,
      String valor,
      String descricao,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                valor,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // RESULTADOS
  // ==========================================================

  Widget _buildResultados(
      BuildContext context, {
        required String titulo,
        required IconData icone,
        required List<Map<String, dynamic>> valores,
        bool calculados = false,
      }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          8,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                    BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icone,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            ...valores.map(
                  (registro) => _buildResultado(
                context,
                registro,
                calculado: calculados,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado(
      BuildContext context,
      Map<String, dynamic> registro, {
        bool calculado = false,
      }) {
    final campo = _obterCampo(registro);

    final descricao = _descricaoCampo(campo);

    final valor = _valorFormatado(
      registro,
      campo,
    );

    final codigo = campo['codigo']?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: calculado
            ? Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.35)
            : Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: calculado
            ? Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.18),
        )
            : null,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface,
              borderRadius:
              BorderRadius.circular(9),
            ),
            child: Icon(
              calculado
                  ? Icons.auto_awesome_outlined
                  : Icons.straighten_outlined,
              size: 18,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  descricao,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (calculado) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Resultado calculado',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ] else if (codigo != null &&
                    codigo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    codigo,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SEM RESULTADOS
  // ==========================================================

  Widget _buildSemResultados(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 52,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),

            const SizedBox(height: 12),

            Text(
              'Nenhum resultado registrado',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Esta avaliação não possui valores '
                  'preenchidos.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // OBSERVAÇÕES
  // ==========================================================

  Widget _buildObservacoes(BuildContext context) {
    final observacoes =
    avaliacao['observacoes']
        ?.toString()
        .trim();

    if (observacoes == null ||
        observacoes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                    BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.notes_outlined,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 11),

                Text(
                  'Observações',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              observacoes,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // INFORMAÇÕES
  // ==========================================================

  Widget _buildInfoLinha(
      BuildContext context,
      IconData icon,
      String titulo,
      String valor,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),

        const SizedBox(width: 10),

        Text(
          '$titulo: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),

        Expanded(
          child: Text(valor),
        ),
      ],
    );
  }

  // ==========================================================
  // VALORES
  // ==========================================================

  List<Map<String, dynamic>>
  _obterValoresPreenchidos() {
    final valores = avaliacao['valores'];

    if (valores is! List) {
      return <Map<String, dynamic>>[];
    }

    final resultado = valores
        .whereType<Map>()
        .map(
          (valor) =>
      Map<String, dynamic>.from(valor),
    )
        .where(
          (registro) {
        final valor =
        registro['valor'];

        if (valor == null) {
          return false;
        }

        return valor
            .toString()
            .trim()
            .isNotEmpty;
      },
    )
        .toList();

    resultado.sort(
          (a, b) {
        final campoA = _obterCampo(a);
        final campoB = _obterCampo(b);

        final ordemA =
        _obterOrdem(campoA);
        final ordemB =
        _obterOrdem(campoB);

        return ordemA.compareTo(ordemB);
      },
    );

    return resultado;
  }

  // ==========================================================
  // CAMPOS DO CABEÇALHO
  // ==========================================================

  /// Identifica campos que pertencem ao cabeçalho
  /// e não devem aparecer em "Medidas e resultados".
  bool _campoCabecalho(
      Map<String, dynamic> registro,
      ) {
    final campo = _obterCampo(registro);

    final codigo =
    campo['codigo']
        ?.toString()
        .trim()
        .toLowerCase();

    return codigo == 'data_avaliacao' ||
        codigo == 'avaliador';
  }

  /// Obtém o valor de um campo pelo código.
  ///
  /// Usado para recuperar o avaliador da lista de
  /// valores recebida pela API.
  String? _obterValorPorCodigo(
      String codigo,
      ) {
    final valores = avaliacao['valores'];

    if (valores is! List) {
      return null;
    }

    for (final item in valores) {
      if (item is! Map) {
        continue;
      }

      final registro =
      Map<String, dynamic>.from(item);

      final campo =
      _obterCampo(registro);

      final codigoCampo =
      campo['codigo']
          ?.toString()
          .trim()
          .toLowerCase();

      if (codigoCampo !=
          codigo.trim().toLowerCase()) {
        continue;
      }

      final valor =
      registro['valor'];

      if (valor == null) {
        return null;
      }

      final texto =
      valor.toString().trim();

      if (texto.isEmpty) {
        return null;
      }

      return texto;
    }

    return null;
  }

  int _obterOrdem(
      Map<String, dynamic> campo,
      ) {
    final ordem = campo['ordem'];

    if (ordem is num) {
      return ordem.toInt();
    }

    return 999999;
  }

  Map<String, dynamic> _obterCampo(
      Map<String, dynamic> registro,
      ) {
    final campo = registro['campo'];

    if (campo is Map<String, dynamic>) {
      return campo;
    }

    if (campo is Map) {
      return Map<String, dynamic>.from(campo);
    }

    return <String, dynamic>{};
  }

  String _descricaoCampo(
      Map<String, dynamic> campo,
      ) {
    final descricao =
    campo['descricao'];

    if (descricao != null &&
        descricao
            .toString()
            .trim()
            .isNotEmpty) {
      return descricao
          .toString()
          .trim();
    }

    final codigo =
    campo['codigo'];

    if (codigo != null &&
        codigo
            .toString()
            .trim()
            .isNotEmpty) {
      return codigo
          .toString()
          .trim();
    }

    return 'Campo';
  }

  String _valorFormatado(
      Map<String, dynamic> registro,
      Map<String, dynamic> campo,
      ) {
    final valor = registro['valor'];

    if (valor == null) {
      return '';
    }

    final texto = valor
        .toString()
        .trim();

    if (texto.isEmpty) {
      return '';
    }

    final unidade =
    campo['unidade'];

    if (unidade == null) {
      return texto;
    }

    final unidadeTexto =
    unidade.toString().trim();

    if (unidadeTexto.isEmpty) {
      return texto;
    }

    return '$texto $unidadeTexto';
  }

  // ==========================================================
  // FORMATAÇÃO
  // ==========================================================

  String _formatarData(dynamic valor) {
    if (valor == null) {
      return 'Data não informada';
    }

    final texto =
    valor.toString().trim();

    if (texto.isEmpty) {
      return 'Data não informada';
    }

    try {
      final data =
      DateTime.parse(texto);

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
    } catch (_) {
      return texto;
    }
  }

  String _formatarTipo(dynamic valor) {
    if (valor == null) {
      return 'Avaliação corporal';
    }

    final tipo =
    valor.toString().trim();

    if (tipo.isEmpty) {
      return 'Avaliação corporal';
    }

    switch (tipo) {
      case 'antropometria':
        return 'Antropometria';

      case 'bio_adulto':
        return 'Bioimpedância — Adulto';

      case 'bio_infantil':
        return 'Bioimpedância — Infantil';

      case 'completa':
        return 'Avaliação completa';

      default:
        return tipo;
    }
  }
}