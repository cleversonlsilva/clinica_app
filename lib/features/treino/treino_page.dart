import 'package:flutter/material.dart';

import 'treino_detalhe_page.dart';
import 'treino_service.dart';

/// Tela principal dos treinos do paciente.
///
/// Responsabilidades:
///
/// - carregar os treinos através do TreinoService;
/// - filtrar o tipo de treino quando solicitado;
/// - apresentar os treinos prescritos pelo profissional;
/// - identificar cada treino como A, B, C, D...;
/// - apresentar período, objetivo e quantidade de exercícios;
/// - apresentar a quantidade de execuções no período;
/// - encaminhar o usuário para os detalhes do treino;
/// - atualizar os dados quando retornar da execução.
///
/// A identificação A/B/C é feita pela ordem dos treinos
/// atualmente vigentes retornados pela API.
///
/// O backend continua sendo responsável por definir
/// quais treinos estão vigentes e quantas vezes cada
/// treino foi executado.
///
/// O filtro [tipoFiltro] permite utilizar esta tela
/// especificamente para Academia ou Corrida.
///
/// Exemplo:
///
/// TreinoPage(
///   treinoService: treinoService,
///   tipoFiltro: 'academia',
/// )
class TreinoPage extends StatefulWidget {
  const TreinoPage({
    super.key,
    required this.treinoService,
    this.tipoFiltro,
  });

  final TreinoService treinoService;

  /// Tipo de treino que deve ser apresentado.
  ///
  /// Valores esperados:
  ///
  /// - academia
  /// - corrida
  /// - cardio
  ///
  /// Quando nulo, todos os tipos são apresentados.
  final String? tipoFiltro;

  @override
  State<TreinoPage> createState() => _TreinoPageState();
}

class _TreinoPageState extends State<TreinoPage> {
  bool _carregando = true;
  String? _erro;

  List<Map<String, dynamic>> _treinos =
  <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // ==========================================================
  // CARREGAMENTO
  // ==========================================================

  Future<void> _carregar() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final treinos =
      await widget.treinoService.listarTreinos();

      final treinosFiltrados =
      _filtrarTreinos(treinos);

      if (!mounted) {
        return;
      }

      setState(() {
        _treinos = treinosFiltrados;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = _mensagemErro(e);
        _carregando = false;
      });
    }
  }

  String _mensagemErro(Object erro) {
    if (erro is TreinoException) {
      return erro.message;
    }

    return 'Não foi possível carregar os treinos.';
  }

  // ==========================================================
  // FILTRO
  // ==========================================================

  List<Map<String, dynamic>> _filtrarTreinos(
      List<Map<String, dynamic>> treinos,
      ) {
    final filtro = widget.tipoFiltro
        ?.trim()
        .toLowerCase();

    if (filtro == null || filtro.isEmpty) {
      return treinos;
    }

    return treinos.where((treino) {
      final tipo = widget.treinoService
          .tipoTreino(treino)
          .trim()
          .toLowerCase();

      return tipo == filtro;
    }).toList();
  }

  // ==========================================================
  // IDENTIFICAÇÃO A / B / C
  // ==========================================================

  /// Retorna a letra do treino conforme sua posição
  /// entre os treinos atualmente apresentados.
  ///
  /// Exemplo:
  ///
  /// índice 0 -> A
  /// índice 1 -> B
  /// índice 2 -> C
  /// índice 3 -> D
  ///
  /// Isso permite apresentar visualmente o mesmo conceito
  /// utilizado no sistema web.
  String _codigoTreino(int indice) {
    if (indice < 0) {
      return 'A';
    }

    const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    if (indice < letras.length) {
      return letras[indice];
    }

    return 'T${indice + 1}';
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _tituloPagina(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _buildBody(),
      ),
    );
  }

  String _tituloPagina() {
    switch (
    widget.tipoFiltro?.trim().toLowerCase()) {
      case 'academia':
        return 'Treinos de academia';

      case 'corrida':
        return 'Treinos de corrida';

      case 'cardio':
        return 'Treinos de cardio';

      default:
        return 'Meus treinos';
    }
  }

  // ==========================================================
  // BODY
  // ==========================================================

  Widget _buildBody() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erro != null) {
      return _buildErro();
    }

    if (_treinos.isEmpty) {
      return _buildVazio();
    }

    return ListView(
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
        ...List.generate(
          _treinos.length,
              (indice) => _buildTreinoCard(
            _treinos[indice],
            indice,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CABEÇALHO
  // ==========================================================

  Widget _buildCabecalho() {
    final titulo = _tituloCabecalho();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _gradienteCabecalho(),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
              Colors.white.withValues(alpha: 0.18),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: Icon(
              _iconeCabecalho(),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _textoQuantidadeTreinos(),
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.9,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tituloCabecalho() {
    switch (
    widget.tipoFiltro?.trim().toLowerCase()) {
      case 'academia':
        return 'Treinos de academia';

      case 'corrida':
        return 'Treinos de corrida';

      case 'cardio':
        return 'Treinos de cardio';

      default:
        return 'Seus treinos';
    }
  }

  String _textoQuantidadeTreinos() {
    if (_treinos.length == 1) {
      return '1 treino prescrito para você';
    }

    return '${_treinos.length} treinos prescritos para você';
  }

  IconData _iconeCabecalho() {
    switch (
    widget.tipoFiltro?.trim().toLowerCase()) {
      case 'corrida':
        return Icons.directions_run_rounded;

      case 'cardio':
        return Icons.monitor_heart_rounded;

      case 'academia':
        return Icons.fitness_center_rounded;

      default:
        return Icons.fitness_center_rounded;
    }
  }

  LinearGradient _gradienteCabecalho() {
    switch (
    widget.tipoFiltro?.trim().toLowerCase()) {
      case 'corrida':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF3B82F6),
          ],
        );

      case 'cardio':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB91C1C),
            Color(0xFFEF4444),
          ],
        );

      case 'academia':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF166534),
            Color(0xFF22C55E),
          ],
        );

      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF166534),
            Color(0xFF22C55E),
          ],
        );
    }
  }

  // ==========================================================
  // CARD DO TREINO
  // ==========================================================

  Widget _buildTreinoCard(
      Map<String, dynamic> treino,
      int indice,
      ) {
    final tipo =
    widget.treinoService.tipoTreino(treino);

    final objetivo =
    widget.treinoService.objetivoTreino(treino);

    final observacoes =
    widget.treinoService
        .observacoesTreino(treino);

    final exercicios =
    widget.treinoService
        .obterExercicios(treino);

    final dataInicio =
    widget.treinoService
        .dataInicioTreino(treino);

    final dataFim =
    widget.treinoService
        .dataFimTreino(treino);

    final id =
    widget.treinoService.idTreino(treino);

    final totalExecucoes =
    _totalExecucoes(treino);

    final tipoInfo = _tipoInfo(tipo);

    final codigo = _codigoTreino(indice);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _abrirDetalhes(treino);
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // ==================================================
                // IDENTIFICAÇÃO DO TREINO
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: tipoInfo.cor,
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        codigo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Treino $codigo',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.w900,
                                    color:
                                    Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tipoInfo.cor
                                      .withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(
                                    20,
                                  ),
                                ),
                                child: Text(
                                  tipoInfo.nome,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                    FontWeight.w700,
                                    color:
                                    tipoInfo.cor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (objetivo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              objetivo,
                              style: const TextStyle(
                                fontSize: 13,
                                color:
                                Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ==================================================
                // INFORMAÇÕES
                // ==================================================

                _buildInformacoes(
                  exercicios: exercicios.length,
                  dataInicio: dataInicio,
                  dataFim: dataFim,
                  totalExecucoes:
                  totalExecucoes,
                ),

                // ==================================================
                // OBSERVAÇÕES
                // ==================================================

                if (observacoes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFF8FAFC),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color:
                          Color(0xFF64748B),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            observacoes,
                            style:
                            const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color:
                              Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ==================================================
                // BOTÃO
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _abrirDetalhes(treino);
                    },
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      exercicios.isEmpty
                          ? 'Ver treino $codigo'
                          : 'Ver exercícios do treino $codigo',
                    ),
                    style:
                    OutlinedButton.styleFrom(
                      minimumSize:
                      const Size.fromHeight(46),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: tipoInfo.cor,
                      ),
                      foregroundColor:
                      tipoInfo.cor,
                    ),
                  ),
                ),

                if (id != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Treino $codigo • #$id',
                      style: const TextStyle(
                        fontSize: 11,
                        color:
                        Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // TOTAL DE EXECUÇÕES
  // ==========================================================

  /// Obtém o total de execuções informado pelo backend.
  ///
  /// O backend retorna este valor como
  /// `total_execucoes`.
  ///
  /// A conversão é defensiva para aceitar tanto
  /// int quanto valores numéricos vindos do JSON.
  int _totalExecucoes(
      Map<String, dynamic> treino,
      ) {
    final valor = treino['total_execucoes'];

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    if (valor is String) {
      return int.tryParse(valor) ?? 0;
    }

    return 0;
  }

  // ==========================================================
  // TIPO
  // ==========================================================

  _TipoTreinoInfo _tipoInfo(
      String tipo,
      ) {
    switch (tipo) {
      case 'corrida':
        return const _TipoTreinoInfo(
          nome: 'Corrida',
          icone:
          Icons.directions_run_rounded,
          cor: Color(0xFF2563EB),
        );

      case 'cardio':
        return const _TipoTreinoInfo(
          nome: 'Cardio',
          icone:
          Icons.monitor_heart_rounded,
          cor: Color(0xFFDC2626),
        );

      case 'academia':
        return const _TipoTreinoInfo(
          nome: 'Academia',
          icone:
          Icons.fitness_center_rounded,
          cor: Color(0xFF16A34A),
        );

      default:
        return const _TipoTreinoInfo(
          nome: 'Treino',
          icone:
          Icons.sports_gymnastics_rounded,
          cor: Color(0xFF7C3AED),
        );
    }
  }

  // ==========================================================
  // INFORMAÇÕES
  // ==========================================================

  Widget _buildInformacoes({
    required int exercicios,
    required String? dataInicio,
    required String? dataFim,
    required int totalExecucoes,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoItem(
                icone:
                Icons.format_list_numbered_rounded,
                titulo: 'Exercícios',
                valor: exercicios.toString(),
              ),
            ),
            Expanded(
              child: _InfoItem(
                icone:
                Icons.calendar_month_rounded,
                titulo: 'Período',
                valor: _formatarPeriodo(
                  dataInicio,
                  dataFim,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFDCFCE7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFF16A34A),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  totalExecucoes == 1
                      ? '1 execução no período'
                      : '$totalExecucoes execuções no período',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              Text(
                '$totalExecucoes',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DATAS
  // ==========================================================

  String _formatarPeriodo(
      String? inicio,
      String? fim,
      ) {
    final dataInicio =
    _formatarData(inicio);

    final dataFim =
    _formatarData(fim);

    if (dataInicio.isEmpty &&
        dataFim.isEmpty) {
      return 'Não informado';
    }

    if (dataInicio.isEmpty) {
      return dataFim;
    }

    if (dataFim.isEmpty) {
      return dataInicio;
    }

    if (dataInicio == dataFim) {
      return dataInicio;
    }

    return '$dataInicio - $dataFim';
  }

  String _formatarData(
      String? data,
      ) {
    if (data == null ||
        data.trim().isEmpty) {
      return '';
    }

    final partes = data.split('-');

    if (partes.length != 3) {
      return data;
    }

    final ano = partes[0];
    final mes = partes[1];
    final dia = partes[2];

    if (ano.length != 4 ||
        mes.length != 2 ||
        dia.length != 2) {
      return data;
    }

    return '$dia/$mes/$ano';
  }

  // ==========================================================
  // DETALHES
  // ==========================================================

  Future<void> _abrirDetalhes(
      Map<String, dynamic> treino,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TreinoDetalhePage(
          treino: treino,
          treinoService:
          widget.treinoService,
          onTreinoConcluido:
          _treinoConcluido,
        ),
      ),
    );

    // ========================================================
    // ATUALIZAÇÃO
    // ========================================================
    //
    // Ao retornar da tela de detalhes/execução,
    // buscamos novamente os treinos no backend.
    //
    // Isso garante que:
    // - total_execucoes seja atualizado;
    // - novos treinos sejam refletidos;
    // - treinos fora do período desapareçam;
    // - a ordem A/B/C seja recalculada.
    //
    // Não fazemos alteração manual no objeto local.
    // A fonte oficial continua sendo a API.

    if (!mounted) {
      return;
    }

    await _carregar();
  }

  // ==========================================================
  // CALLBACK DE CONCLUSÃO
  // ==========================================================

  /// Recebe a conclusão do treino a partir da tela
  /// de execução.
  ///
  /// A própria TreinoExecucaoPage já registra a execução
  /// através do fluxo definido para o módulo.
  ///
  /// Aqui apenas garantimos que, quando o fluxo retornar
  /// para esta tela, os dados sejam buscados novamente.
  Future<void> _treinoConcluido(
      int treinoId,
      int tempoTotalSegundos,
      ) async {
    if (!mounted) {
      return;
    }

    // O backend é a fonte oficial dos dados.
    //
    // Não incrementamos manualmente total_execucoes,
    // pois isso poderia duplicar uma execução já registrada.
    await _carregar();
  }

  // ==========================================================
  // ERRO
  // ==========================================================

  Widget _buildErro() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        Center(
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius:
              BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Não foi possível carregar seus treinos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _erro!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _carregar,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label:
            const Text('Tentar novamente'),
            style:
            ElevatedButton.styleFrom(
              minimumSize:
              const Size(180, 48),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // VAZIO
  // ==========================================================

  Widget _buildVazio() {
    final filtro = widget.tipoFiltro
        ?.trim()
        .toLowerCase();

    final bool corrida = filtro == 'corrida';

    final titulo = corrida
        ? 'Nenhuma corrida disponível'
        : filtro == 'academia'
        ? 'Nenhum treino de academia disponível'
        : 'Nenhum treino disponível';

    final descricao = corrida
        ? 'Quando um profissional prescrever '
        'um treino de corrida, ele aparecerá aqui.'
        : filtro == 'academia'
        ? 'Quando um profissional prescrever '
        'um treino de academia, ele aparecerá aqui.'
        : 'Quando um profissional prescrever '
        'um treino, ele aparecerá aqui.';

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 70),
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: corrida
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF0FDF4),
              borderRadius:
              BorderRadius.circular(24),
            ),
            child: Icon(
              corrida
                  ? Icons.directions_run_rounded
                  : Icons.fitness_center_rounded,
              color: corrida
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF16A34A),
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          descricao,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MODELO VISUAL DO TIPO
// ============================================================

class _TipoTreinoInfo {
  const _TipoTreinoInfo({
    required this.nome,
    required this.icone,
    required this.cor,
  });

  final String nome;
  final IconData icone;
  final Color cor;
}

// ============================================================
// ITEM DE INFORMAÇÃO
// ============================================================

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  final IconData icone;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icone,
          size: 19,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}