import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';

/// Tela de detalhe de uma prescrição.
///
/// Recebe diretamente o registro retornado pela API.
///
/// A tela não recalcula nenhum dado da prescrição.
/// O PDF é carregado somente quando o usuário solicita
/// sua visualização.
class PrescricaoDetalhePage extends StatefulWidget {
  const PrescricaoDetalhePage({
    super.key,
    required this.prescricao,
  });

  final Map<String, dynamic> prescricao;

  @override
  State<PrescricaoDetalhePage> createState() =>
      _PrescricaoDetalhePageState();
}

class _PrescricaoDetalhePageState
    extends State<PrescricaoDetalhePage> {
  late final AuthService _authService;
  late final ApiClient _apiClient;
  late final PacienteApiService _pacienteApiService;

  bool _carregandoPdf = false;

  @override
  void initState() {
    super.initState();

    _authService = AuthServiceFactory.create();

    _apiClient = ApiClient();

    _pacienteApiService = PacienteApiService(
      apiClient: _apiClient,
    );
  }

  @override
  void dispose() {
    _apiClient.dispose();

    super.dispose();
  }

  String _texto(dynamic valor) {
    if (valor == null) {
      return '';
    }

    return valor.toString().trim();
  }

  int? _prescricaoId() {
    final valor = widget.prescricao['id'];

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(
      valor?.toString() ?? '',
    );
  }

  String _statusTexto() {
    final status =
    _texto(widget.prescricao['status']);

    if (status.isEmpty) {
      return 'Não informado';
    }

    switch (status.toLowerCase()) {
      case 'ativa':
        return 'Ativa';

      case 'cancelada':
        return 'Cancelada';

      case 'inativa':
        return 'Inativa';

      case 'finalizada':
        return 'Finalizada';

      default:
        return status;
    }
  }

  Color _statusCor(BuildContext context) {
    final status =
    _texto(widget.prescricao['status'])
        .toLowerCase();

    switch (status) {
      case 'ativa':
        return Colors.green;

      case 'cancelada':
      case 'inativa':
        return Theme.of(context)
            .colorScheme
            .error;

      case 'finalizada':
        return Colors.orange;

      default:
        return Theme.of(context)
            .colorScheme
            .primary;
    }
  }

  Future<void> _visualizarPdf() async {
    if (_carregandoPdf) {
      return;
    }

    final prescricaoId = _prescricaoId();

    if (prescricaoId == null) {
      _mostrarErro(
        'Não foi possível identificar a prescrição.',
      );
      return;
    }

    final status =
    _texto(widget.prescricao['status'])
        .toLowerCase();

    if (status != 'ativa') {
      _mostrarErro(
        'Somente prescrições ativas possuem PDF disponível.',
      );
      return;
    }

    setState(() {
      _carregandoPdf = true;
    });

    try {
      final token =
      await _authService.obterToken();

      if (token == null ||
          token.trim().isEmpty) {
        throw ApiException(
          'Sessão do paciente não encontrada.',
        );
      }

      final bytes =
      await _pacienteApiService
          .obterPrescricaoPdf(
        token: token.trim(),
        prescricaoId: prescricaoId,
      );

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        throw ApiException(
          'O PDF retornado pela API está vazio.',
        );
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return PrescricaoPdfPage(
              bytes: Uint8List.fromList(bytes),
              prescricao: widget.prescricao,
            );
          },
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      _mostrarErro(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _mostrarErro(
        'Não foi possível carregar o PDF da prescrição.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _carregandoPdf = false;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final data =
    _texto(widget.prescricao['data']);

    final profissional = _texto(
      widget.prescricao['profissional_nome'],
    );

    final texto =
    _texto(widget.prescricao['texto']);

    final resumo =
    _texto(widget.prescricao['resumo']);

    final totalCaracteres =
    widget.prescricao['total_caracteres'];

    final statusCor =
    _statusCor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescrição'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCabecalho(
            context,
            data: data,
            profissional: profissional,
            statusCor: statusCor,
          ),
          const SizedBox(height: 20),
          _buildPrescricao(
            context,
            texto: texto,
            resumo: resumo,
          ),
          const SizedBox(height: 20),
          _buildBotaoPdf(context),
          const SizedBox(height: 20),
          _buildInformacoes(
            context,
            data: data,
            profissional: profissional,
            totalCaracteres: totalCaracteres,
          ),
        ],
      ),
    );
  }

  Widget _buildCabecalho(
      BuildContext context, {
        required String data,
        required String profissional,
        required Color statusCor,
      }) {
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    size: 28,
                    color: Theme.of(context)
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
                        'Prescrição',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusCor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusTexto(),
                          style: TextStyle(
                            color: statusCor,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (data.isNotEmpty)
              _buildInfoLinha(
                context,
                Icons.calendar_today_outlined,
                'Data',
                data,
              ),
            if (profissional.isNotEmpty)
              _buildInfoLinha(
                context,
                Icons.person_outline,
                'Profissional',
                profissional,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescricao(
      BuildContext context, {
        required String texto,
        required String resumo,
      }) {
    final conteudo =
    texto.isNotEmpty ? texto : resumo;

    if (conteudo.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhum conteúdo registrado',
                textAlign: TextAlign.center,
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
                'Esta prescrição não possui '
                    'conteúdo preenchido.',
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Orientações',
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
            const SizedBox(height: 16),
            SelectableText(
              conteudo,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoPdf(
      BuildContext context,
      ) {
    final ativa =
        _texto(widget.prescricao['status'])
            .toLowerCase() ==
            'ativa';

    if (!ativa) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
            _carregandoPdf
                ? null
                : _visualizarPdf,
            icon: _carregandoPdf
                ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.picture_as_pdf_outlined,
            ),
            label: Text(
              _carregandoPdf
                  ? 'Carregando PDF...'
                  : 'Visualizar PDF',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformacoes(
      BuildContext context, {
        required String data,
        required String profissional,
        required dynamic totalCaracteres,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Informações',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoLinha(
              context,
              Icons.info_outline,
              'Status',
              _statusTexto(),
            ),
            if (data.isNotEmpty)
              _buildInfoLinha(
                context,
                Icons.calendar_today_outlined,
                'Data',
                data,
              ),
            if (profissional.isNotEmpty)
              _buildInfoLinha(
                context,
                Icons.person_outline,
                'Profissional',
                profissional,
              ),
            if (totalCaracteres != null)
              _buildInfoLinha(
                context,
                Icons.text_fields_outlined,
                'Caracteres',
                totalCaracteres.toString(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLinha(
      BuildContext context,
      IconData icon,
      String titulo,
      String valor,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
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
}

/// Tela de visualização real do PDF da prescrição.
///
/// Recebe os bytes diretamente da API e utiliza
/// o Syncfusion PDF Viewer para renderização.
///
/// O mesmo PDF carregado na memória pode ser
/// compartilhado diretamente pelo menu nativo
/// do sistema operacional.
class PrescricaoPdfPage extends StatefulWidget {
  const PrescricaoPdfPage({
    super.key,
    required this.bytes,
    required this.prescricao,
  });

  final Uint8List bytes;
  final Map<String, dynamic> prescricao;

  @override
  State<PrescricaoPdfPage> createState() =>
      _PrescricaoPdfPageState();
}

class _PrescricaoPdfPageState
    extends State<PrescricaoPdfPage> {
  final PdfViewerController _pdfController =
  PdfViewerController();

  int _paginaAtual = 1;
  int _totalPaginas = 0;
  bool _compartilhando = false;

  @override
  void dispose() {
    _pdfController.dispose();

    super.dispose();
  }

  String _nomeArquivo() {
    final id =
    widget.prescricao['id']?.toString();

    if (id != null && id.trim().isNotEmpty) {
      return 'prescricao_$id.pdf';
    }

    return 'prescricao.pdf';
  }

  Future<void> _compartilharPdf() async {
    if (_compartilhando) {
      return;
    }

    if (widget.bytes.isEmpty) {
      _mostrarErro(
        'O PDF está vazio e não pode ser compartilhado.',
      );
      return;
    }

    setState(() {
      _compartilhando = true;
    });

    try {
      final id =
          widget.prescricao['id']?.toString() ?? '';

      final paciente =
      widget.prescricao['paciente_nome']
          ?.toString()
          .trim();

      final nomeArquivo = _nomeArquivo();

      final assunto = id.isEmpty
          ? 'Prescrição'
          : 'Prescrição nº $id';

      final texto = paciente != null &&
          paciente.isNotEmpty
          ? '$assunto - $paciente'
          : assunto;

      final sharePositionOrigin =
      Rect.fromLTWH(
        0,
        0,
        MediaQuery.sizeOf(context).width,
        kToolbarHeight,
      );

      await SharePlus.instance.share(
        ShareParams(
          title: assunto,
          subject: assunto,
          text: texto,
          files: [
            XFile.fromData(
              widget.bytes,
              name: nomeArquivo,
              mimeType: 'application/pdf',
            ),
          ],
          sharePositionOrigin:
          sharePositionOrigin,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _mostrarErro(
        'Não foi possível compartilhar o PDF.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _compartilhando = false;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final id =
        widget.prescricao['id']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          id.isEmpty
              ? 'PDF da Prescrição'
              : 'Prescrição nº $id',
        ),
        actions: [
          if (_totalPaginas > 0)
            Center(
              child: Padding(
                padding:
                const EdgeInsets.only(
                  right: 8,
                ),
                child: Text(
                  '$_paginaAtual/$_totalPaginas',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Compartilhar PDF',
            onPressed: _compartilhando
                ? null
                : _compartilharPdf,
            icon: _compartilhando
                ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.share_outlined,
            ),
          ),
        ],
      ),
      body: SfPdfViewer.memory(
        widget.bytes,
        controller: _pdfController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onDocumentLoaded:
            (PdfDocumentLoadedDetails details) {
          if (!mounted) {
            return;
          }

          setState(() {
            _totalPaginas =
                details.document.pages.count;
            _paginaAtual = 1;
          });
        },
        onPageChanged:
            (PdfPageChangedDetails details) {
          if (!mounted) {
            return;
          }

          setState(() {
            _paginaAtual =
                details.newPageNumber;
          });
        },
        onDocumentLoadFailed:
            (PdfDocumentLoadFailedDetails details) {
          if (!mounted) {
            return;
          }

          _mostrarErro(
            'Não foi possível abrir o PDF: '
                '${details.description}',
          );
        },
      ),
    );
  }
}