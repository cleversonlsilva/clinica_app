import 'package:flutter/material.dart';

import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';
import 'avaliacao_detalhe_page.dart';
import 'avaliacao_service.dart';

/// Tela de histórico de Avaliação Corporal do paciente.
///
/// A página é responsável apenas pela apresentação do histórico.
/// Toda comunicação com a API permanece no AvaliacaoService.
class AvaliacaoPage extends StatefulWidget {
  const AvaliacaoPage({
    super.key,
  });

  @override
  State<AvaliacaoPage> createState() => _AvaliacaoPageState();
}

class _AvaliacaoPageState extends State<AvaliacaoPage> {
  late final AvaliacaoService _service;

  bool _carregando = true;
  String? _erro;

  List<Map<String, dynamic>> _avaliacoes = [];

  @override
  void initState() {
    super.initState();

    final apiClient = ApiClient();

    _service = AvaliacaoService(
      authService: AuthServiceFactory.create(),
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
      final avaliacoes =
      await _service.listarAvaliacoes();

      if (!mounted) {
        return;
      }

      setState(() {
        _avaliacoes = avaliacoes;
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
        'Não foi possível carregar as avaliações corporais.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliação Corporal'),
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _avaliacoes.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          final avaliacao = _avaliacoes[index];

          return _buildAvaliacaoCard(
            avaliacao,
          );
        },
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(
            height:
            MediaQuery.of(context).size.height * 0.25,
          ),
          Icon(
            Icons.monitor_weight_outlined,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma avaliação corporal',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ainda não existem avaliações corporais '
                'registradas para você.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildAvaliacaoCard(
      Map<String, dynamic> avaliacao,
      ) {
    final data = _formatarData(
      avaliacao['data_avaliacao'],
    );

    final tipo = _formatarTipo(
      avaliacao['tipo'],
    );

    final equipamento =
    avaliacao['equipamento']
        ?.toString()
        .trim();

    final valores =
    _service.obterValoresPreenchidos(
      avaliacao,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _abrirDetalhes(avaliacao);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
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
                          data,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tipo,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              if (equipamento != null &&
                  equipamento.isNotEmpty)
                _buildInfoLinha(
                  Icons.devices_outlined,
                  'Equipamento',
                  equipamento,
                ),
              _buildInfoLinha(
                Icons.analytics_outlined,
                'Valores registrados',
                valores.length.toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoLinha(
      IconData icon,
      String titulo,
      String valor,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
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
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(valor),
          ),
        ],
      ),
    );
  }

  /// Abre os detalhes da avaliação selecionada.
  ///
  /// A avaliação já foi carregada pelo AvaliacaoService.
  /// A tela de detalhes apenas recebe os dados e os apresenta.
  void _abrirDetalhes(
      Map<String, dynamic> avaliacao,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvaliacaoDetalhePage(
          avaliacao: avaliacao,
        ),
      ),
    );
  }

  String _formatarData(dynamic valor) {
    if (valor == null) {
      return 'Data não informada';
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return 'Data não informada';
    }

    try {
      final data = DateTime.parse(texto);

      final dia =
      data.day.toString().padLeft(2, '0');

      final mes =
      data.month.toString().padLeft(2, '0');

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

    final tipo = valor.toString().trim();

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