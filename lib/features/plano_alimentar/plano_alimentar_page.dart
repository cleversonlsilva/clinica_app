import 'package:flutter/material.dart';

import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';
import 'plano_alimentar_service.dart';

/// Tela do Plano Alimentar do paciente.
///
/// Apresenta:
/// - informações gerais do plano;
/// - refeições;
/// - alimentos;
/// - valores calóricos;
/// - lista de substituições A/B/C.
///
/// A página não realiza comunicação HTTP diretamente.
/// Toda a comunicação permanece no PlanoAlimentarService.
class PlanoAlimentarPage extends StatefulWidget {
  const PlanoAlimentarPage({
    super.key,
    required this.planoId,
  });

  /// Identificador do plano alimentar que será exibido.
  final int planoId;

  @override
  State<PlanoAlimentarPage> createState() =>
      _PlanoAlimentarPageState();
}

class _PlanoAlimentarPageState
    extends State<PlanoAlimentarPage> {
  late final PlanoAlimentarService _service;

  bool _carregando = true;
  String? _erro;

  Map<String, dynamic>? _plano;

  @override
  void initState() {
    super.initState();

    final apiClient = ApiClient();

    final authService = AuthServiceFactory.create();

    _service = PlanoAlimentarService(
      authService: authService,
      pacienteApiService: PacienteApiService(
        apiClient: apiClient,
      ),
    );

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
      final plano = await _service.carregar(
        planoId: widget.planoId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _plano = plano;
        _carregando = false;
      });
    } on PlanoAlimentarException catch (e) {
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
        'Não foi possível carregar o plano alimentar.';
        _carregando = false;
      });
    }
  }

  List<Map<String, dynamic>> _refeicoes() {
    final valor = _plano?['refeicoes'];

    if (valor is List) {
      return valor
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> _itens(
      Map<String, dynamic> refeicao,
      ) {
    final valor = refeicao['itens'];

    if (valor is List) {
      return valor
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> _substituicoes(
      Map<String, dynamic> item,
      ) {
    final valor = item['substituicoes'];

    if (valor is List) {
      return valor
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return [];
  }

  String _texto(dynamic valor) {
    if (valor == null) {
      return '';
    }

    return valor.toString();
  }

  String _formatarNumero(dynamic valor) {
    if (valor == null) {
      return '0';
    }

    final numero = valor is num
        ? valor.toDouble()
        : double.tryParse(valor.toString());

    if (numero == null) {
      return valor.toString();
    }

    if (numero == numero.roundToDouble()) {
      return numero.toInt().toString();
    }

    return numero
        .toStringAsFixed(1)
        .replaceAll('.', ',');
  }

  String _formatarKcal(dynamic valor) {
    return '${_formatarNumero(valor)} kcal';
  }

  String _formatarData(dynamic valor) {
    final texto = _texto(valor);

    if (texto.isEmpty) {
      return '';
    }

    try {
      final data = DateTime.parse(texto);

      final dia =
      data.day.toString().padLeft(2, '0');
      final mes =
      data.month.toString().padLeft(2, '0');
      final ano = data.year.toString();

      return '$dia/$mes/$ano';
    } catch (_) {
      return texto;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        appBar: _PlanoAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_erro != null) {
      return _buildErro();
    }

    if (_plano == null) {
      return _buildVazio();
    }

    return Scaffold(
      appBar: const _PlanoAppBar(),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            _buildCabecalho(),
            const SizedBox(height: 20),
            ..._refeicoes().map(
                  (refeicao) => Padding(
                padding:
                const EdgeInsets.only(bottom: 16),
                child: _buildRefeicao(refeicao),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
    final nome = _texto(_plano?['nome']);

    final criadoEm =
    _formatarData(_plano?['criado_em']);

    final totalKcal = _plano?['total_kcal'];

    final totalRefeicoes =
        _plano?['total_refeicoes'] ?? 0;

    return Card(
      elevation: 0,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plano alimentar',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nome.isEmpty
                            ? 'Plano alimentar'
                            : nome,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildIndicador(
                    icon: Icons
                        .local_fire_department_outlined,
                    titulo: 'Total diário',
                    valor:
                    _formatarKcal(totalKcal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildIndicador(
                    icon: Icons.restaurant_outlined,
                    titulo: 'Refeições',
                    valor:
                    totalRefeicoes.toString(),
                  ),
                ),
              ],
            ),
            if (criadoEm.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Criado em $criadoEm',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: Theme.of(context)
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

  Widget _buildIndicador({
    required IconData icon,
    required String titulo,
    required String valor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefeicao(
      Map<String, dynamic> refeicao,
      ) {
    final nome = _texto(refeicao['nome']);
    final hora = _texto(refeicao['hora']);
    final totalKcal = refeicao['total_kcal'];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          8,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome.isEmpty
                            ? 'Refeição'
                            : nome,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      if (hora.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons
                                  .access_time_outlined,
                              size: 15,
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hora,
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
                const SizedBox(width: 8),
                Text(
                  _formatarKcal(totalKcal),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            ..._itens(refeicao).map(
                  (item) => _buildItem(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
      Map<String, dynamic> item,
      ) {
    final descricao =
    _texto(item['descricao']);

    final quantidade =
    _formatarNumero(item['quantidade']);

    final unidade =
    _texto(item['unidade']);

    final kcal = item['kcal_total'];

    final substituicoes =
    _substituicoes(item);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.circle,
                size: 7,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      descricao.isEmpty
                          ? 'Alimento'
                          : descricao,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$quantidade $unidade • '
                          '${_formatarKcal(kcal)}',
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
          if (substituicoes.isNotEmpty)
            _buildSubstituicoes(
              substituicoes,
            ),
        ],
      ),
    );
  }

  Widget _buildSubstituicoes(
      List<Map<String, dynamic>> substituicoes,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 17,
        top: 10,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          childrenPadding:
          const EdgeInsets.fromLTRB(
            12,
            0,
            12,
            10,
          ),
          leading: Icon(
            Icons.swap_horiz_outlined,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          title: const Text(
            'Substituições',
          ),
          subtitle: Text(
            '${substituicoes.length} '
                '${substituicoes.length == 1 ? 'opção' : 'opções'}',
          ),
          children: substituicoes.map(
                (substituicao) {
              return _buildSubstituicao(
                substituicao,
              );
            },
          ).toList(),
        ),
      ),
    );
  }

  Widget _buildSubstituicao(
      Map<String, dynamic> substituicao,
      ) {
    final opcao =
    _texto(substituicao['opcao']);

    final nome =
    _texto(substituicao['nome']);

    final quantidade =
    _formatarNumero(
      substituicao['quantidade'],
    );

    final unidade =
    _texto(substituicao['unidade']);

    final kcal = substituicao['kcal'];

    return Padding(
      padding: const EdgeInsets.only(
        top: 8,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surface,
          borderRadius:
          BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius.circular(8),
              ),
              child: Text(
                opcao.isEmpty ? '?' : opcao,
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    nome.isEmpty
                        ? 'Alimento substituto'
                        : nome,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$quantidade $unidade • '
                        '${_formatarKcal(kcal)}',
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

  Widget _buildVazio() {
    return Scaffold(
      appBar: const _PlanoAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                size: 56,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum plano alimentar encontrado.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Scaffold(
      appBar: const _PlanoAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                'Não foi possível carregar '
                    'o plano alimentar.',
                textAlign: TextAlign.center,
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
                _erro ?? '',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _carregar,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  'Tentar novamente',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AppBar isolada para manter o build principal
/// mais limpo.
class _PlanoAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _PlanoAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Plano alimentar',
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight);
}