import 'package:flutter/material.dart';

import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';
import '../avaliacao/avaliacao_service.dart';
import 'evolucao_service.dart';

/// Tela de Evolução Corporal do paciente.
///
/// Utiliza os dados já fornecidos pelo módulo
/// Avaliação Corporal.
///
/// Não realiza cálculos clínicos.
/// Os valores e indicadores são provenientes
/// do backend.
class EvolucaoPage extends StatefulWidget {
  const EvolucaoPage({
    super.key,
  });

  @override
  State<EvolucaoPage> createState() =>
      _EvolucaoPageState();
}

class _EvolucaoPageState
    extends State<EvolucaoPage> {
  late final ApiClient _apiClient;
  late final EvolucaoService _service;

  bool _carregando = true;
  String? _erro;

  List<Map<String, dynamic>> _avaliacoes = [];

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();

    final avaliacaoService =
    AvaliacaoService(
      authService:
      AuthServiceFactory.create(),
      pacienteApiService:
      PacienteApiService(
        apiClient: _apiClient,
      ),
    );

    _service = EvolucaoService(
      avaliacaoService: avaliacaoService,
    );

    _carregar();
  }

  @override
  void dispose() {
    _apiClient.dispose();

    super.dispose();
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final avaliacoes =
      await _service.carregar();

      if (!mounted) {
        return;
      }

      setState(() {
        _avaliacoes =
            _ordenarAvaliacoes(avaliacoes);
        _carregando = false;
      });
    } on AvaliacaoException catch (e) {
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
        'Não foi possível carregar '
            'a evolução corporal.';
        _carregando = false;
      });
    }
  }

  List<Map<String, dynamic>>
  _ordenarAvaliacoes(
      List<Map<String, dynamic>> avaliacoes,
      ) {
    final resultado =
    List<Map<String, dynamic>>.from(
      avaliacoes,
    );

    resultado.sort((a, b) {
      final dataA =
      _service.obterData(a);

      final dataB =
      _service.obterData(b);

      if (dataA == null && dataB == null) {
        return 0;
      }

      if (dataA == null) {
        return 1;
      }

      if (dataB == null) {
        return -1;
      }

      final comparacao =
      dataB.compareTo(dataA);

      if (comparacao != 0) {
        return comparacao;
      }

      final idA =
      _numeroId(a['id']);

      final idB =
      _numeroId(b['id']);

      return idB.compareTo(idA);
    });

    return resultado;
  }

  int _numeroId(dynamic valor) {
    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(
      valor?.toString() ?? '',
    ) ??
        0;
  }

  Map<String, dynamic>? get _ultimaAvaliacao {
    if (_avaliacoes.isEmpty) {
      return null;
    }

    return _avaliacoes.first;
  }

  Map<String, dynamic>? get _avaliacaoAnterior {
    if (_avaliacoes.length < 2) {
      return null;
    }

    return _avaliacoes[1];
  }

  List<Map<String, dynamic>>
  _valoresUltimaAvaliacao() {
    final ultima =
        _ultimaAvaliacao;

    if (ultima == null) {
      return [];
    }

    return _service.valores(ultima)
        .where(_deveExibirIndicador)
        .toList();
  }

  /// Campos que representam dados cadastrais/contextuais
  /// e não devem aparecer como indicadores de evolução.
  ///
  /// Eles continuam disponíveis no backend e podem ser
  /// utilizados por outras partes da aplicação.
  bool _deveExibirIndicador(
      Map<String, dynamic> registro,
      ) {
    final codigo =
    _service.codigoCampo(registro);

    final descricao =
    _normalizarTexto(
      _service.descricaoCampo(registro),
    );

    const codigosIgnorados = {
      'data_avaliacao',
      'data_da_avaliacao',
      'avaliador',
      'profissional',
      'altura',
      'idade',
      'sexo',
      'nivel_atividade',
      'nivel_de_atividade',
      'nivel_atividade_fisica',
      'objetivo',
    };

    if (codigosIgnorados.contains(codigo)) {
      return false;
    }

    const descricoesIgnoradas = {
      'data da avaliacao',
      'avaliador',
      'profissional',
      'altura',
      'idade',
      'sexo',
      'nivel de atividade',
      'nivel de atividade fisica',
      'objetivo',
    };

    return !descricoesIgnoradas.contains(
      descricao,
    );
  }

  String _normalizarTexto(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  String _texto(dynamic valor) {
    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  String _tipoAvaliacao(
      Map<String, dynamic> avaliacao,
      ) {
    final tipo =
    _texto(avaliacao['tipo']);

    if (tipo.isEmpty) {
      return 'Avaliação corporal';
    }

    switch (tipo.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Evolução corporal',
        ),
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

    if (_avaliacoes.isEmpty) {
      return _buildVazio();
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),
        children: [
          _buildResumo(),
          const SizedBox(height: 16),
          _buildIndicadores(),
          const SizedBox(height: 20),
          _buildHistorico(),
        ],
      ),
    );
  }

  Widget _buildResumo() {
    final ultima =
    _ultimaAvaliacao!;

    final anterior =
        _avaliacaoAnterior;

    final data =
    _service.formatarData(ultima);

    final tipo =
    _tipoAvaliacao(ultima);

    final equipamento =
    _texto(ultima['equipamento']);

    final totalAvaliacoes =
        _avaliacoes.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                  BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .show_chart_outlined,
                    size: 30,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolução corporal',
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Acompanhamento dos seus '
                            'resultados',
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 14),
            _buildInfoLinha(
              Icons.calendar_today_outlined,
              'Última avaliação',
              data,
            ),
            _buildInfoLinha(
              Icons.category_outlined,
              'Tipo',
              tipo,
            ),
            if (equipamento.isNotEmpty)
              _buildInfoLinha(
                Icons.devices_outlined,
                'Equipamento',
                equipamento,
              ),
            _buildInfoLinha(
              Icons.assessment_outlined,
              'Avaliações registradas',
              totalAvaliacoes.toString(),
            ),
            if (anterior != null)
              _buildInfoLinha(
                Icons.compare_arrows_outlined,
                'Comparação',
                'Com a avaliação anterior',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadores() {
    final valores =
    _valoresUltimaAvaliacao();

    if (valores.isEmpty) {
      return _buildCardSemDados();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          const EdgeInsets.only(
            left: 4,
            bottom: 12,
          ),
          child: Text(
            'Resultados atuais',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
        ...valores.map(
              (registro) =>
              _buildIndicadorCard(
                registro,
              ),
        ),
      ],
    );
  }

  Widget _buildIndicadorCard(
      Map<String, dynamic> registro,
      ) {
    final descricao =
    _service.descricaoCampo(
      registro,
    );

    final valor =
    _service.valorFormatado(
      registro,
    );

    final codigo =
    _service.codigoCampo(
      registro,
    );

    final anterior =
        _avaliacaoAnterior;

    EvolucaoComparacao comparacao =
    const EvolucaoComparacao.semDados();

    if (anterior != null &&
        codigo.isNotEmpty) {
      comparacao =
          _service.comparar(
            _ultimaAvaliacao!,
            anterior,
            codigo,
          );
    }

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                  BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .straighten_outlined,
                    size: 22,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    descricao,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              valor.isEmpty
                  ? 'Não informado'
                  : valor,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),
            if (comparacao
                .alteracaoNumerica)
              ...[
                const SizedBox(height: 8),
                _buildComparacao(
                  comparacao,
                ),
              ]
            else if (anterior != null)
              ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons
                          .remove_outlined,
                      size: 18,
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sem comparação numérica',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparacao(
      EvolucaoComparacao comparacao,
      ) {
    final diferenca =
        comparacao.diferenca;

    if (diferenca == null) {
      return const SizedBox.shrink();
    }

    if (diferenca == 0) {
      return Row(
        children: [
          Icon(
            Icons.remove_outlined,
            size: 18,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Sem alteração',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final diminuiu =
        comparacao.direcao ==
            EvolucaoDirecao.diminuiu;

    final cor = diminuiu
        ? Colors.green
        : Colors.orange;

    final icone = diminuiu
        ? Icons
        .arrow_downward_outlined
        : Icons
        .arrow_upward_outlined;

    final sinal =
    diferenca > 0 ? '+' : '';

    return Row(
      children: [
        Icon(
          icone,
          size: 18,
          color: cor,
        ),
        const SizedBox(width: 6),
        Text(
          '$sinal${_formatarNumero(diferenca)} '
              'desde a avaliação anterior',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color: cor,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatarNumero(
      double valor,
      ) {
    if (valor == valor.roundToDouble()) {
      return valor
          .toInt()
          .toString();
    }

    return valor
        .toStringAsFixed(2)
        .replaceAll(
      '.',
      ',',
    );
  }

  Widget _buildHistorico() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          const EdgeInsets.only(
            left: 4,
            bottom: 12,
          ),
          child: Text(
            'Histórico de avaliações',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
        ..._avaliacoes.asMap().entries.map(
              (entry) {
            final index =
                entry.key;

            final avaliacao =
                entry.value;

            return _buildHistoricoItem(
              avaliacao,
              index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoricoItem(
      Map<String, dynamic> avaliacao,
      int index,
      ) {
    final data =
    _service.formatarData(
      avaliacao,
    );

    final tipo =
    _tipoAvaliacao(
      avaliacao,
    );

    final valores =
    _service.valores(
      avaliacao,
    );

    final isUltima =
        index == 0;

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
              BoxDecoration(
                color: isUltima
                    ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                isUltima
                    ? Icons
                    .radio_button_checked
                    : Icons
                    .history_outlined,
                size: 21,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data,
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isUltima)
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration:
                          BoxDecoration(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .primaryContainer,
                            borderRadius:
                            BorderRadius
                                .circular(
                              20,
                            ),
                          ),
                          child: Text(
                            'Atual',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 12,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tipo,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${valores.length} '
                        'resultado'
                        '${valores.length == 1 ? '' : 's'} '
                        'registrado'
                        '${valores.length == 1 ? '' : 's'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSemDados() {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons
                  .analytics_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum resultado disponível',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A avaliação mais recente '
                  'não possui valores registrados.',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErro() {
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
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
            const SizedBox(height: 16),
            Text(
              _erro!,
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge,
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

  Widget _buildVazio() {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(24),
        children: [
          SizedBox(
            height:
            MediaQuery.of(context)
                .size
                .height *
                0.22,
          ),
          Icon(
            Icons
                .show_chart_outlined,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma avaliação corporal',
            textAlign:
            TextAlign.center,
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
            'Ainda não existem avaliações '
                'corporais registradas para você.',
            textAlign:
            TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLinha(
      IconData icon,
      String titulo,
      String valor,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
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
              fontWeight:
              FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(valor),
          ),
        ],
      ),
    );
  }
}
