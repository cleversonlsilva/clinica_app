import 'package:flutter/material.dart';

import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';
import 'exame_detalhe_page.dart';
import 'exames_service.dart';

/// Tela de Exames do paciente.
///
/// Apresenta as solicitações de exames retornadas pela API.
///
/// A página não realiza comunicação HTTP diretamente.
/// Toda a comunicação permanece no ExamesService.
class ExamesPage extends StatefulWidget {
  const ExamesPage({
    super.key,
  });

  @override
  State<ExamesPage> createState() => _ExamesPageState();
}

class _ExamesPageState extends State<ExamesPage> {
  late final ExamesService _service;

  bool _carregando = true;

  String? _erro;

  List<Map<String, dynamic>> _exames = [];

  @override
  void initState() {
    super.initState();

    final apiClient = ApiClient();

    final authService = AuthServiceFactory.create();

    _service = ExamesService(
      authService: authService,
      pacienteApiService: PacienteApiService(
        apiClient: apiClient,
      ),
    );

    _carregar();
  }

  @override
  void dispose() {
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
      final exames = await _service.listarExames();

      if (!mounted) {
        return;
      }

      setState(() {
        _exames = exames;
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
        _erro = 'Não foi possível carregar os exames.';
        _carregando = false;
      });
    }
  }

  // ==========================================================
  // ABRIR DETALHE
  // ==========================================================

  void _abrirDetalhe(
      Map<String, dynamic> exame,
      ) {
    final id = _obterInteiro(exame['id']);

    if (id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível identificar a solicitação de exames.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExameDetalhePage(
          service: _service,
          solicitacaoId: id,
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exames'),
      ),
      body: _buildConteudo(),
    );
  }

  // ==========================================================
  // CONTEÚDO
  // ==========================================================

  Widget _buildConteudo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erro != null) {
      return _buildErro();
    }

    if (_exames.isEmpty) {
      return _buildVazio();
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _exames.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          return _buildExameCard(
            _exames[index],
          );
        },
      ),
    );
  }

  // ==========================================================
  // CARD DO EXAME
  // ==========================================================

  Widget _buildExameCard(
      Map<String, dynamic> exame,
      ) {
    final descricao =
    exame['descricao']?.toString().trim();

    final status =
    exame['status']?.toString().trim();

    final data =
    _formatarData(
      exame['data_solicitacao'],
    );

    final totalResultados =
    _obterInteiro(
      exame['total_resultados'],
    );

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirDetalhe(exame),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.biotech_outlined,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      descricao?.isNotEmpty == true
                          ? descricao!
                          : 'Solicitação de exames',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildInformacao(
                icone:
                Icons.calendar_today_outlined,
                titulo: 'Solicitação',
                valor: data,
              ),
              const SizedBox(height: 10),
              _buildInformacao(
                icone: Icons.info_outline,
                titulo: 'Status',
                valor: _formatarStatus(status),
              ),
              const SizedBox(height: 10),
              _buildInformacao(
                icone: Icons.attach_file_outlined,
                titulo: 'Resultados',
                valor: _formatarResultados(
                  totalResultados,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ver detalhes',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // INFORMAÇÃO
  // ==========================================================

  Widget _buildInformacao({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Row(
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
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            valor,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ERRO
  // ==========================================================

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              _erro ??
                  'Não foi possível carregar os exames.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
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
    );
  }

  // ==========================================================
  // VAZIO
  // ==========================================================

  Widget _buildVazio() {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
            MediaQuery.of(context).size.height *
                0.65,
            child: Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.biotech_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum exame encontrado.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'As solicitações de exames '
                          'aparecerão aqui quando '
                          'estiverem disponíveis.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FORMATAÇÕES
  // ==========================================================

  String _formatarData(dynamic valor) {
    if (valor == null) {
      return 'Não informada';
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return 'Não informada';
    }

    final data =
    DateTime.tryParse(texto);

    if (data == null) {
      return texto;
    }

    final dia =
    data.day.toString().padLeft(2, '0');

    final mes =
    data.month.toString().padLeft(2, '0');

    final ano =
    data.year.toString();

    return '$dia/$mes/$ano';
  }

  String _formatarStatus(String? status) {
    if (status == null || status.isEmpty) {
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

  String _formatarResultados(int total) {
    if (total == 0) {
      return 'Nenhum resultado';
    }

    if (total == 1) {
      return '1 resultado';
    }

    return '$total resultados';
  }
}