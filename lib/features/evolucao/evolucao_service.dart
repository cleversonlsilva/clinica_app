import '../avaliacao/avaliacao_service.dart';

/// Serviço responsável por preparar os dados
/// históricos para a tela de Evolução Corporal.
///
/// Não realiza chamadas HTTP próprias.
///
/// Os dados são obtidos através do
/// AvaliacaoService, evitando duplicação da
/// comunicação com a API.
///
/// O serviço também não recalcula nenhum indicador.
/// Todos os valores vêm originalmente do backend.
class EvolucaoService {
  EvolucaoService({
    required this.avaliacaoService,
  });

  final AvaliacaoService avaliacaoService;

  /// Carrega as avaliações corporais disponíveis
  /// para o paciente autenticado.
  Future<List<Map<String, dynamic>>> carregar() async {
    return avaliacaoService.listarAvaliacoes();
  }

  /// Retorna somente avaliações que possuem
  /// valores preenchidos.
  List<Map<String, dynamic>> avaliacoesComValores(
      List<Map<String, dynamic>> avaliacoes,
      ) {
    return avaliacoes.where((avaliacao) {
      return avaliacaoService
          .obterValoresPreenchidos(avaliacao)
          .isNotEmpty;
    }).toList();
  }

  /// Retorna os valores preenchidos de uma avaliação.
  List<Map<String, dynamic>> valores(
      Map<String, dynamic> avaliacao,
      ) {
    return avaliacaoService.obterValoresPreenchidos(
      avaliacao,
    );
  }

  /// Retorna o código do campo.
  String codigoCampo(
      Map<String, dynamic> registro,
      ) {
    final campo =
    avaliacaoService.obterCampo(registro);

    final codigo = campo['codigo'];

    if (codigo == null) {
      return '';
    }

    return codigo.toString().trim().toLowerCase();
  }

  /// Retorna a descrição do campo.
  String descricaoCampo(
      Map<String, dynamic> registro,
      ) {
    return avaliacaoService.descricaoCampo(
      registro,
    );
  }

  /// Retorna a unidade do campo.
  String? unidadeCampo(
      Map<String, dynamic> registro,
      ) {
    return avaliacaoService.unidadeCampo(
      registro,
    );
  }

  /// Retorna o valor original do backend.
  String valorFormatado(
      Map<String, dynamic> registro,
      ) {
    return avaliacaoService.valorFormatado(
      registro,
    );
  }

  /// Procura determinado campo dentro de uma avaliação.
  Map<String, dynamic>? encontrarCampo(
      Map<String, dynamic> avaliacao,
      String codigo,
      ) {
    final codigoNormalizado =
    codigo.trim().toLowerCase();

    for (final registro in valores(avaliacao)) {
      if (codigoCampo(registro) ==
          codigoNormalizado) {
        return registro;
      }
    }

    return null;
  }

  /// Obtém o valor de determinado campo.
  String? obterValorCampo(
      Map<String, dynamic> avaliacao,
      String codigo,
      ) {
    final registro = encontrarCampo(
      avaliacao,
      codigo,
    );

    if (registro == null) {
      return null;
    }

    return valorFormatado(registro);
  }

  /// Obtém a data da avaliação.
  DateTime? obterData(
      Map<String, dynamic> avaliacao,
      ) {
    final valor =
    avaliacao['data_avaliacao'];

    if (valor == null) {
      return null;
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(texto);
    } catch (_) {
      return null;
    }
  }

  /// Formata a data para apresentação.
  String formatarData(
      Map<String, dynamic> avaliacao,
      ) {
    final data = obterData(avaliacao);

    if (data == null) {
      return 'Data não informada';
    }

    final dia =
    data.day.toString().padLeft(2, '0');

    final mes =
    data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  /// Compara duas avaliações para determinado campo.
  ///
  /// A comparação é textual quando os valores não
  /// puderem ser convertidos para número.
  EvolucaoComparacao comparar(
      Map<String, dynamic> atual,
      Map<String, dynamic> anterior,
      String codigo,
      ) {
    final valorAtual =
    encontrarCampo(atual, codigo);

    final valorAnterior =
    encontrarCampo(anterior, codigo);

    if (valorAtual == null ||
        valorAnterior == null) {
      return const EvolucaoComparacao.semDados();
    }

    final atualNumero =
    _numero(valorAtual['valor']);

    final anteriorNumero =
    _numero(valorAnterior['valor']);

    if (atualNumero == null ||
        anteriorNumero == null) {
      return EvolucaoComparacao(
        disponivel: true,
        alteracaoNumerica: false,
        diferenca: null,
        direcao: EvolucaoDirecao.semAlteracao,
      );
    }

    final diferenca =
        atualNumero - anteriorNumero;

    if (diferenca == 0) {
      return EvolucaoComparacao(
        disponivel: true,
        alteracaoNumerica: true,
        diferenca: 0,
        direcao: EvolucaoDirecao.semAlteracao,
      );
    }

    return EvolucaoComparacao(
      disponivel: true,
      alteracaoNumerica: true,
      diferenca: diferenca,
      direcao: diferenca > 0
          ? EvolucaoDirecao.aumentou
          : EvolucaoDirecao.diminuiu,
    );
  }

  double? _numero(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is num) {
      return valor.toDouble();
    }

    final texto =
    valor.toString().trim();

    if (texto.isEmpty) {
      return null;
    }

    return double.tryParse(
      texto.replaceAll(',', '.'),
    );
  }
}

/// Resultado de uma comparação entre duas avaliações.
class EvolucaoComparacao {
  const EvolucaoComparacao({
    required this.disponivel,
    required this.alteracaoNumerica,
    required this.diferenca,
    required this.direcao,
  });

  const EvolucaoComparacao.semDados()
      : disponivel = false,
        alteracaoNumerica = false,
        diferenca = null,
        direcao = EvolucaoDirecao.semAlteracao;

  final bool disponivel;
  final bool alteracaoNumerica;
  final double? diferenca;
  final EvolucaoDirecao direcao;
}

enum EvolucaoDirecao {
  aumentou,
  diminuiu,
  semAlteracao,
}