import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';
import 'prescricao_detalhe_page.dart';
import 'prescricao_service.dart';

/// Tela responsável por apresentar as prescrições
/// ativas do paciente autenticado.
///
/// A comunicação com a API permanece no
/// PrescricaoService.
///
/// Esta tela concentra somente:
/// - carregamento;
/// - estados de carregamento/erro/vazio;
/// - filtro das prescrições ativas;
/// - apresentação da lista;
/// - navegação para o detalhe da prescrição.
class PrescricaoPage extends StatefulWidget {
  const PrescricaoPage({
    super.key,
  });

  @override
  State<PrescricaoPage> createState() =>
      _PrescricaoPageState();
}

class _PrescricaoPageState
    extends State<PrescricaoPage> {
  late final AuthService _authService;

  late final ApiClient _apiClient;

  late final PacienteApiService
  _pacienteApiService;

  late final PrescricaoService
  _prescricaoService;

  bool _carregando = true;

  String? _erro;

  List<Map<String, dynamic>>
  _prescricoes =
  <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    _authService =
        AuthServiceFactory.create();

    _apiClient = ApiClient();

    _pacienteApiService =
        PacienteApiService(
          apiClient: _apiClient,
        );

    _prescricaoService =
        PrescricaoService(
          authService: _authService,
          pacienteApiService:
          _pacienteApiService,
        );

    _carregar();
  }

  @override
  void dispose() {
    _apiClient.dispose();

    super.dispose();
  }

  // ==========================================================
  // CARREGAMENTO
  // ==========================================================

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final prescricoes =
      await _prescricaoService
          .listarPrescricoes();

      // ======================================================
      // SOMENTE PRESCRIÇÕES ATIVAS
      // ======================================================
      //
      // Não excluímos nem alteramos registros no backend.
      //
      // Apenas filtramos o que será apresentado ao paciente.
      //
      // Ativa  -> aparece
      // Cancelada -> não aparece
      // Inativa -> não aparece
      // Outros status -> não aparecem
      //
      final prescricoesAtivas =
      prescricoes.where((prescricao) {
        final status =
        prescricao['status']
            ?.toString()
            .trim()
            .toLowerCase();

        return status == 'ativa';
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _prescricoes =
            prescricoesAtivas;
        _carregando = false;
      });
    } on PrescricaoException catch (e) {
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
        'Não foi possível carregar as prescrições.';
        _carregando = false;
      });
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prescrições',
        ),
      ),
      body: _buildConteudo(
        context,
      ),
    );
  }

  // ==========================================================
  // CONTEÚDO
  // ==========================================================

  Widget _buildConteudo(
      BuildContext context,
      ) {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erro != null) {
      return _buildErro(
        context,
      );
    }

    if (_prescricoes.isEmpty) {
      return _buildVazio(
        context,
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _prescricoes.length,
        separatorBuilder:
            (context, index) =>
        const SizedBox(height: 12),
        itemBuilder:
            (
            context,
            index,
            ) {
          return _buildPrescricaoCard(
            context,
            _prescricoes[index],
          );
        },
      ),
    );
  }

  // ==========================================================
  // CARD DA PRESCRIÇÃO
  // ==========================================================

  Widget _buildPrescricaoCard(
      BuildContext context,
      Map<String, dynamic> prescricao,
      ) {
    final data =
    _prescricaoService.obterData(
      prescricao,
    );

    final profissional =
    _prescricaoService
        .obterProfissional(
      prescricao,
    );

    final resumo =
    _prescricaoService.obterResumo(
      prescricao,
    );

    final status =
    _prescricaoService
        .obterStatusFormatado(
      prescricao,
    );

    final possuiConteudo =
    _prescricaoService
        .possuiConteudo(
      prescricao,
    );

    return Card(
      elevation: 1,
      clipBehavior:
      Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _abrirPrescricao(
            prescricao,
          );
        },
        child: Padding(
          padding:
          const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // ==================================================
              // CABEÇALHO
              // ==================================================

              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                    BoxDecoration(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primaryContainer,
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .medication_outlined,
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          'Prescrição',
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

                        const SizedBox(
                          height: 4,
                        ),

                        if (data.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons
                                    .calendar_today_outlined,
                                size: 14,
                                color: Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Flexible(
                                child: Text(
                                  data,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style:
                                  Theme.of(
                                    context,
                                  )
                                      .textTheme
                                      .bodySmall,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  _buildStatus(
                    context,
                    status,
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // PROFISSIONAL
              // ==================================================

              if (profissional.isNotEmpty)
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Icon(
                      Icons
                          .person_outline,
                      size: 18,
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        profissional,
                        style:
                        Theme.of(
                          context,
                        )
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

              if (profissional.isNotEmpty)
                const SizedBox(
                  height: 14,
                ),

              // ==================================================
              // RESUMO
              // ==================================================

              if (possuiConteudo)
                Text(
                  resumo,
                  maxLines: 4,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  Theme.of(
                    context,
                  )
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    height: 1.45,
                  ),
                )
              else
                Text(
                  'Prescrição sem conteúdo registrado.',
                  style:
                  Theme.of(
                    context,
                  )
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontStyle:
                    FontStyle.italic,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // RODAPÉ
              // ==================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .end,
                children: [
                  Text(
                    'Ver prescrição',
                    style:
                    Theme.of(
                      context,
                    )
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 14,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // STATUS
  // ==========================================================

  Widget _buildStatus(
      BuildContext context,
      String status,
      ) {
    if (status.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme =
        Theme.of(context)
            .colorScheme;

    Color backgroundColor;
    Color foregroundColor;

    switch (status.toLowerCase()) {
      case 'ativa':
        backgroundColor =
            colorScheme
                .primaryContainer;
        foregroundColor =
            colorScheme
                .onPrimaryContainer;
        break;

      case 'cancelada':
        backgroundColor =
            colorScheme
                .errorContainer;
        foregroundColor =
            colorScheme
                .onErrorContainer;
        break;

      case 'finalizada':
        backgroundColor =
            colorScheme
                .secondaryContainer;
        foregroundColor =
            colorScheme
                .onSecondaryContainer;
        break;

      default:
        backgroundColor =
            colorScheme
                .surfaceContainerHighest;
        foregroundColor =
            colorScheme
                .onSurfaceVariant;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        status,
        style:
        Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
          color:
          foregroundColor,
          fontWeight:
          FontWeight.w600,
        ),
      ),
    );
  }

  // ==========================================================
  // ESTADO VAZIO
  // ==========================================================

  Widget _buildVazio(
      BuildContext context,
      ) {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 80,
          ),

          Card(
            child: Padding(
              padding:
              const EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons
                        .medication_outlined,
                    size: 56,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'Nenhuma prescrição ativa encontrada',
                    textAlign:
                    TextAlign.center,
                    style:
                    Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'No momento não existem '
                        'prescrições ativas registradas '
                        'para você.',
                    textAlign:
                    TextAlign.center,
                    style:
                    Theme.of(
                      context,
                    )
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ERRO
  // ==========================================================

  Widget _buildErro(
      BuildContext context,
      ) {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 80,
          ),

          Card(
            child: Padding(
              padding:
              const EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons
                        .error_outline,
                    size: 56,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .error,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'Não foi possível carregar',
                    textAlign:
                    TextAlign.center,
                    style:
                    Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    _erro ??
                        'Ocorreu um erro ao carregar '
                            'as prescrições.',
                    textAlign:
                    TextAlign.center,
                    style:
                    Theme.of(
                      context,
                    )
                        .textTheme
                        .bodyMedium,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  FilledButton.icon(
                    onPressed:
                    _carregar,
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
        ],
      ),
    );
  }

  // ==========================================================
  // NAVEGAÇÃO
  // ==========================================================

  /// Abre o detalhe da prescrição selecionada.
  void _abrirPrescricao(
      Map<String, dynamic> prescricao,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PrescricaoDetalhePage(
              prescricao: prescricao,
            ),
      ),
    );
  }
}