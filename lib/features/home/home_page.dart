import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_service_factory.dart';
import '../../core/network/api_client.dart';
import '../../services/paciente_api_service.dart';
import '../agenda/agenda_page.dart';
import '../agenda/agenda_service.dart';
import '../avaliacao/avaliacao_page.dart';
import '../evolucao/evolucao_page.dart';
import '../exames/exames_page.dart';
import '../plano_alimentar/plano_alimentar_page.dart';
import '../prescricao/prescricao_page.dart';
import '../treino/academia/treino_academia_page.dart';
import '../treino/corrida/treino_corrida_page.dart';
import '../treino/treino_service.dart';
import '../teleatendimento/teleatendimento_service.dart';
import 'home_service.dart';

/// Tela principal do paciente no Nexo APP.
///
/// Responsável por:
///
/// - apresentar o perfil do paciente;
/// - apresentar o resumo dos dados;
/// - apresentar os indicadores dos módulos;
/// - apresentar o próximo agendamento;
/// - permitir acesso à agenda;
/// - permitir acesso aos exames;
/// - permitir acesso à avaliação corporal;
/// - permitir acesso ao plano alimentar;
/// - permitir acesso às prescrições;
/// - permitir acesso à evolução corporal;
/// - permitir acesso aos treinos de academia;
/// - permitir acesso aos treinos de corrida;
/// - permitir atualização dos dados;
/// - permitir encerramento da sessão.
///
/// As regras de comunicação com a API permanecem
/// nos serviços especializados.
///
/// A área clínica e a área esportiva são apresentadas
/// separadamente na interface.
class HomePage extends StatefulWidget {
const HomePage({super.key});

@override
State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
late final AuthService _authService;
late final HomeService _homeService;

late final ApiClient _apiClient;
late final PacienteApiService _pacienteApiService;
late final TreinoService _treinoService;

bool _carregando = true;
String? _erro;

Map<String, dynamic>? _dados;

bool _nomeVisivel = true;

@override
void initState() {
super.initState();

_authService = AuthServiceFactory.create();

_apiClient = ApiClient();

_pacienteApiService = PacienteApiService(
apiClient: _apiClient,
);

_homeService = HomeService(
authService: _authService,
pacienteApiService: _pacienteApiService,
);

_treinoService = TreinoService(
authService: _authService,
pacienteApiService: _pacienteApiService,
);

_carregar();
}

@override
void dispose() {
_apiClient.dispose();

super.dispose();
}

/// Carrega ou atualiza todos os dados da Home.
Future<void> _carregar() async {
if (mounted) {
setState(() {
_carregando = true;
_erro = null;
});
}

try {
final dados = await _homeService.carregar();

if (!mounted) {
return;
}

setState(() {
_dados = dados;
_carregando = false;
});
} on HomeException catch (e) {
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
_erro = 'Não foi possível carregar seus dados.';
_carregando = false;
});
}
}

/// Encerra a sessão do paciente.
Future<void> _logout() async {
await _authService.logout();

if (!mounted) {
return;
}

Navigator.of(context).pushNamedAndRemoveUntil(
'/',
(route) => false,
);
}

/// Retorna um mapa armazenado nos dados da Home.
Map<String, dynamic> _map(String chave) {
final valor = _dados?[chave];

if (valor is Map<String, dynamic>) {
return valor;
}

return {};
}

/// Retorna uma lista armazenada nos dados da Home.
List<dynamic> _lista(String chave) {
final valor = _dados?[chave];

if (valor is List) {
return valor;
}

return [];
}

/// Recupera os dados do paciente.
///
/// Primeiro tenta o perfil e, caso não encontre,
/// utiliza os dados do resumo.
Map<String, dynamic> _paciente() {
final perfil = _map('perfil');

final pacientePerfil = perfil['paciente'];

if (pacientePerfil is Map<String, dynamic>) {
return pacientePerfil;
}

final resumo = _map('resumo');

final pacienteResumo = resumo['paciente'];

if (pacienteResumo is Map<String, dynamic>) {
return pacienteResumo;
}

return {};
}

/// Retorna o nome completo do paciente.
String _nomePaciente() {
final paciente = _paciente();

final nome = paciente['nome'];

if (nome is String && nome.trim().isNotEmpty) {
return nome.trim();
}

return 'Paciente';
}

/// Retorna somente o primeiro nome.
String _primeiroNome() {
final nome = _nomePaciente().trim();

if (nome.isEmpty) {
return 'Paciente';
}

final partes = nome.split(RegExp(r'\s+'));

return partes.first;
}

/// Retorna a quantidade de registros de um módulo.
int _total(String chave) {
return _lista(chave).length;
}

@override
Widget build(BuildContext context) {
if (_carregando) {
return const Scaffold(
body: Center(
child: CircularProgressIndicator(),
),
);
}

if (_erro != null) {
return _buildErro();
}

return Scaffold(
appBar: AppBar(
toolbarHeight: 92,
backgroundColor: const Color(0xFF3D55F5),
foregroundColor: Colors.white,
elevation: 0,
automaticallyImplyLeading: false,
titleSpacing: 16,
title: Row(
children: [
Image.asset(
'assets/images/nexo_saude.png',
width: 42,
height: 42,
fit: BoxFit.contain,
errorBuilder: (context, error, stackTrace) {
return const Icon(
Icons.health_and_safety_outlined,
size: 38,
);
},
),
const SizedBox(width: 12),
Expanded(
child: Text(
_nomeVisivel
? 'Olá, ${_primeiroNome()}'
    : 'Olá, ••••••',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w500,
),
),
),
],
),
actions: [
IconButton(
tooltip: _nomeVisivel
? 'Ocultar nome'
    : 'Visualizar nome',
onPressed: () {
setState(() {
_nomeVisivel = !_nomeVisivel;
});
},
icon: Icon(
_nomeVisivel
? Icons.visibility_outlined
    : Icons.visibility_off_outlined,
size: 27,
),
),
const SizedBox(width: 12),
const Icon(
Icons.chat_bubble_outline_rounded,
size: 27,
),
const SizedBox(width: 6),
IconButton(
tooltip: 'Sair',
onPressed: _logout,
icon: const Icon(
Icons.logout_outlined,
size: 30,
),
),
const SizedBox(width: 6),
],
),
body: RefreshIndicator(
onRefresh: _carregar,
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
children: [
_buildCabecalho(),
const SizedBox(height: 14),
_buildResumo(),
const SizedBox(height: 18),

// ==================================================
// ÁREA CLÍNICA
// ==================================================
_buildTituloSecao(
titulo: 'Clínica',
subtitulo:
'Acompanhe sua saúde e seus cuidados.',
icone: Icons.medical_services_outlined,
cor: const Color(0xFF166534),
),
const SizedBox(height: 10),
_buildModulos(),

const SizedBox(height: 20),

// ==================================================
// ÁREA DE TREINOS
// ==================================================
_buildTituloSecao(
titulo: 'Treinos',
subtitulo:
'Acesse os treinos prescritos pelo seu profissional.',
icone: Icons.fitness_center_outlined,
cor: const Color(0xFF2563EB),
),
const SizedBox(height: 10),
_buildTreinos(),

const SizedBox(height: 18),
_buildAgenda(),
const SizedBox(height: 24),
_buildMensagem(),
],
),
),
);
}

// ==========================================================
// CABEÇALHO
// ==========================================================

Widget _buildCabecalho() {
final paciente = _paciente();
final foto = paciente['foto'];

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (foto is String && foto.trim().isNotEmpty) ...[
ClipOval(
child: Image.network(
foto,
width: 72,
height: 72,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) {
return _buildAvatarFallback();
},
),
),
const SizedBox(height: 16),
],
Text(
'Acompanhe sua saúde, seus cuidados e seus treinos.',
style: Theme.of(context).textTheme.bodyMedium,
),
],
);
}

Widget _buildAvatarFallback() {
return CircleAvatar(
radius: 36,
child: Text(
_primeiroNome().isNotEmpty
? _primeiroNome()[0].toUpperCase()
    : 'P',
style: const TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
),
),
);
}

// ==========================================================
// TÍTULO DE SEÇÃO
// ==========================================================

Widget _buildTituloSecao({
required String titulo,
required String subtitulo,
required IconData icone,
required Color cor,
}) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: cor.withValues(alpha: 0.10),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
icone,
color: cor,
size: 22,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
titulo,
style: Theme.of(context).textTheme.titleLarge?.copyWith(
fontSize: 21,
fontWeight: FontWeight.w800,
),
),
const SizedBox(height: 3),
Text(
subtitulo,
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Colors.grey.shade600,
),
),
],
),
),
],
);
}

// ==========================================================
// RESUMO
// ==========================================================

Widget _buildResumo() {
final paciente = _paciente();

final telefone = paciente['telefone'];
final whatsapp = paciente['whatsapp'];
final email = paciente['email'];
final sexo = paciente['sexo'];

return Card(
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(
Icons.favorite_outline,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(width: 10),
Text(
'Seu resumo',
style: Theme.of(context).textTheme.titleLarge?.copyWith(
fontWeight: FontWeight.bold,
),
),
],
),
const SizedBox(height: 12),
Text(
_nomePaciente(),
style: Theme.of(context).textTheme.titleMedium?.copyWith(
fontSize: 16,
height: 1.15,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 12),
if (sexo != null && sexo.toString().isNotEmpty)
_buildInfoLinha(
Icons.person_outline,
'Sexo',
sexo.toString(),
),
if (telefone != null && telefone.toString().isNotEmpty)
_buildInfoLinha(
Icons.phone_outlined,
'Telefone',
telefone.toString(),
),
if (whatsapp != null && whatsapp.toString().isNotEmpty)
_buildInfoLinha(
Icons.chat_outlined,
'WhatsApp',
whatsapp.toString(),
),
if (email != null && email.toString().isNotEmpty)
_buildInfoLinha(
Icons.email_outlined,
'E-mail',
email.toString(),
),
],
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
padding: const EdgeInsets.only(bottom: 8),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
icon,
size: 19,
color: Theme.of(context).colorScheme.primary,
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

// ==========================================================
// MÓDULOS CLÍNICOS
// ==========================================================

Widget _buildModulos() {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
GridView.count(
crossAxisCount: 2,
crossAxisSpacing: 10,
mainAxisSpacing: 10,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
mainAxisExtent: 132,
children: [
_buildModuloCard(
icon: Icons.restaurant_menu_outlined,
titulo: 'Plano alimentar',
total: _total('plano'),
onTap: _abrirPlanoAlimentar,
),
_buildModuloCard(
icon: Icons.science_outlined,
titulo: 'Exames',
total: _total('exames'),
onTap: _abrirExames,
),
_buildModuloCard(
icon: Icons.monitor_weight_outlined,
titulo: 'Avaliação corporal',
total: _total('avaliacao'),
onTap: _abrirAvaliacao,
),
_buildModuloCard(
icon: Icons.medication_outlined,
titulo: 'Prescrições',
total: _total('prescricao'),
onTap: _abrirPrescricoes,
),
_buildModuloCard(
icon: Icons.show_chart_outlined,
titulo: 'Evolução corporal',
total: _total('avaliacao'),
onTap: _abrirEvolucao,
),
_buildModuloCard(
icon: Icons.calendar_month_outlined,
titulo: 'Agenda',
total: _total('agenda'),
onTap: _abrirAgenda,
),
],
),
],
);
}

// ==========================================================
// TREINOS
// ==========================================================

Widget _buildTreinos() {
return Column(
children: [
_buildTreinoAcessoCard(
icone: Icons.fitness_center_rounded,
titulo: 'Treinos de academia',
descricao:
'Veja os exercícios, séries, repetições, '
'cargas e tempos de descanso.',
cor: const Color(0xFF16A34A),
onTap: _abrirTreinosAcademia,
),
const SizedBox(height: 10),
_buildTreinoAcessoCard(
icone: Icons.directions_run_rounded,
titulo: 'Corrida',
descricao:
'Acompanhe os treinos de corrida prescritos '
'pelo seu profissional.',
cor: const Color(0xFF2563EB),
onTap: _abrirTreinosCorrida,
),
],
);
}

Widget _buildTreinoAcessoCard({
required IconData icone,
required String titulo,
required String descricao,
required Color cor,
required VoidCallback onTap,
}) {
return Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(20),
onTap: onTap,
child: Ink(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: cor.withValues(alpha: 0.12),
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.045),
blurRadius: 12,
offset: const Offset(0, 5),
),
],
),
child: Row(
children: [
Container(
width: 50,
height: 50,
decoration: BoxDecoration(
color: cor.withValues(alpha: 0.10),
borderRadius: BorderRadius.circular(15),
),
child: Icon(
icone,
color: cor,
size: 26,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
titulo,
style: const TextStyle(
fontSize: 16,
height: 1.15,
fontWeight: FontWeight.w800,
color: Color(0xFF1F2937),
),
),
const SizedBox(height: 5),
Text(
descricao,
style: const TextStyle(
fontSize: 12,
height: 1.3,
color: Color(0xFF64748B),
),
),
],
),
),
const SizedBox(width: 8),
Icon(
Icons.chevron_right_rounded,
color: cor,
size: 28,
),
],
),
),
),
);
}

/// Abre exclusivamente os treinos de academia.
void _abrirTreinosAcademia() {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => TreinoAcademiaPage(
treinoService: _treinoService,
),
),
);
}

/// Abre exclusivamente os treinos de corrida.
///
/// A tela utilizada agora é a tela especializada
/// de corrida.
void _abrirTreinosCorrida() {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => TreinoCorridaPage(
treinoService: _treinoService,
),
),
);
}

// ==========================================================
// PLANO ALIMENTAR
// ==========================================================

/// Abre o Plano Alimentar.
void _abrirPlanoAlimentar() {
final planos = _lista('plano');

if (planos.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Nenhum plano alimentar encontrado.',
),
),
);

return;
}

final primeiroPlano = planos.first;

if (primeiroPlano is! Map) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Não foi possível identificar o plano alimentar.',
),
),
);

return;
}

final planoId = primeiroPlano['id'];

if (planoId is! num) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Identificador do plano alimentar inválido.',
),
),
);

return;
}

Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => PlanoAlimentarPage(
planoId: planoId.toInt(),
),
),
);
}

// ==========================================================
// AGENDA
// ==========================================================

/// Abre a agenda do paciente.
void _abrirAgenda() {
final agendaService = AgendaService(
authService: _authService,
pacienteApiService: _pacienteApiService,
);

final teleatendimentoService = TeleatendimentoService(
authService: _authService,
pacienteApiService: _pacienteApiService,
);

Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => AgendaPage(
agendaService: agendaService,
teleatendimentoService: teleatendimentoService,
),
),
);
}

// ==========================================================
// EXAMES
// ==========================================================

/// Abre os exames do paciente.
void _abrirExames() {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const ExamesPage(),
),
);
}

// ==========================================================
// AVALIAÇÃO
// ==========================================================

/// Abre as avaliações corporais do paciente.
void _abrirAvaliacao() {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const AvaliacaoPage(),
),
);
}

// ==========================================================
// EVOLUÇÃO
// ==========================================================

/// Abre a evolução corporal do paciente.
void _abrirEvolucao() {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const EvolucaoPage(),
),
);
}

// ==========================================================
// PRESCRIÇÕES
// ==========================================================

/// Abre as prescrições do paciente.
Future<void> _abrirPrescricoes() async {
await Navigator.of(context).push(
MaterialPageRoute(
builder: (_) => const PrescricaoPage(),
),
);

if (!mounted) {
return;
}

await _carregar();
}

// ==========================================================
// CARD DE MÓDULO
// ==========================================================

Widget _buildModuloCard({
required IconData icon,
required String titulo,
required int total,
VoidCallback? onTap,
}) {
final card = Card(
child: Padding(
padding: const EdgeInsets.all(13),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
icon,
size: 26,
color: Theme.of(context).colorScheme.primary,
),
const Spacer(),
Text(
titulo,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: Theme.of(context).textTheme.titleMedium?.copyWith(
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 4),
Text(
'$total registro${total == 1 ? '' : 's'}',
style: Theme.of(context).textTheme.bodySmall,
),
],
),
),
);

if (onTap == null) {
return card;
}

return InkWell(
borderRadius: BorderRadius.circular(12),
onTap: onTap,
child: card,
);
}

// ==========================================================
// DATAS
// ==========================================================

/// Converte uma data recebida da API para DateTime.
DateTime? _parseData(String? valor) {
if (valor == null || valor.trim().isEmpty) {
return null;
}

final texto = valor.trim();

// Formato ISO.
try {
return DateTime.parse(texto);
} catch (_) {
// Continua tentando o formato brasileiro.
}

// Formato brasileiro: DD/MM/YYYY.
final partes = texto.split('/');

if (partes.length == 3) {
final dia = int.tryParse(partes[0]);
final mes = int.tryParse(partes[1]);
final ano = int.tryParse(partes[2]);

if (dia != null && mes != null && ano != null) {
return DateTime(
ano,
mes,
dia,
);
}
}

return null;
}

/// Converte uma data para o formato brasileiro.
String _formatarData(String? valor) {
final data = _parseData(valor);

if (data == null) {
return valor ?? '-';
}

return '${data.day.toString().padLeft(2, '0')}/'
'${data.month.toString().padLeft(2, '0')}/'
'${data.year}';
}

/// Converte data e horário do agendamento em DateTime.
DateTime? _dataHoraAgendamento(
Map<String, dynamic> agendamento,
) {
final dataTexto = agendamento['data']?.toString();

final data = _parseData(dataTexto);

if (data == null) {
return null;
}

final horaValor =
agendamento['hora_inicio'] ??
agendamento['hora'];

// Se não houver horário, consideramos o final do dia.
if (horaValor == null ||
horaValor.toString().trim().isEmpty) {
return DateTime(
data.year,
data.month,
data.day,
23,
59,
59,
);
}

final horaTexto = horaValor.toString().trim();

final partes = horaTexto.split(':');

if (partes.length < 2) {
return DateTime(
data.year,
data.month,
data.day,
23,
59,
59,
);
}

final hora = int.tryParse(partes[0]);
final minuto = int.tryParse(partes[1]);

if (hora == null || minuto == null) {
return DateTime(
data.year,
data.month,
data.day,
23,
59,
59,
);
}

return DateTime(
data.year,
data.month,
data.day,
hora,
minuto,
);
}

/// Verifica se o status representa um agendamento
/// que não deve aparecer como próximo.
bool _statusAgendamentoIgnorado(
Map<String, dynamic> agendamento,
) {
final status = (agendamento['status'] ?? '')
    .toString()
    .trim()
    .toLowerCase();

const ignorados = {
'cancelado',
'cancelada',
'cancelled',
'remarcado',
'remarcada',
'rescheduled',
'finalizado',
'finalizada',
'concluido',
'concluída',
'realizado',
'realizada',
'faltou',
'falta',
'no_show',
'noshow',
'encerrado',
'encerrada',
};

return ignorados.contains(status);
}

/// Localiza o próximo agendamento realmente futuro.
Map<String, dynamic>? _obterProximoAgendamento() {
final lista = _lista('agenda');

final agora = DateTime.now();

Map<String, dynamic>? proximo;
DateTime? proximaDataHora;

for (final item in lista) {
if (item is! Map) {
continue;
}

final agendamento = Map<String, dynamic>.from(item);

// Ignora status que não representam consultas futuras.
if (_statusAgendamentoIgnorado(agendamento)) {
continue;
}

// Converte data e horário.
final dataHora = _dataHoraAgendamento(
agendamento,
);

if (dataHora == null) {
continue;
}

// Ignora consultas que já passaram.
if (dataHora.isBefore(agora)) {
continue;
}

// Seleciona a consulta futura mais próxima.
if (proximaDataHora == null ||
dataHora.isBefore(proximaDataHora)) {
proximaDataHora = dataHora;
proximo = agendamento;
}
}

return proximo;
}

// ==========================================================
// AGENDA — PRÓXIMO AGENDAMENTO
// ==========================================================

Widget _buildAgenda() {
final primeiro = _obterProximoAgendamento();

// Nenhum agendamento futuro.
if (primeiro == null) {
return Card(
child: Padding(
padding: const EdgeInsets.all(20),
child: Row(
children: [
Icon(
Icons.event_available_outlined,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(width: 12),
const Expanded(
child: Text(
'Você não possui próximos agendamentos.',
),
),
],
),
),
);
}

final data = primeiro['data'];

final horario =
primeiro['hora'] ??
primeiro['hora_inicio'];

final horarioFim = primeiro['hora_fim'];

final status = primeiro['status'];

final tipo = primeiro['tipo'];

final observacoes =
primeiro['observacoes'] ??
primeiro['observacao'];

String horarioFormatado = '-';

if (horario != null &&
horario.toString().trim().isNotEmpty) {
horarioFormatado = horario.toString().trim();

if (horarioFim != null &&
horarioFim.toString().trim().isNotEmpty) {
horarioFormatado =
'$horarioFormatado - '
'${horarioFim.toString().trim()}';
}
}

return Card(
child: Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(
Icons.event_outlined,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(width: 10),
Expanded(
child: Text(
'Próximo agendamento',
style: Theme.of(context)
    .textTheme
    .titleLarge
    ?.copyWith(
fontWeight: FontWeight.bold,
),
),
),
],
),
const SizedBox(height: 16),
if (data != null &&
data.toString().trim().isNotEmpty)
_buildInfoLinha(
Icons.calendar_today_outlined,
'Data',
_formatarData(
data.toString(),
),
),
if (horario != null &&
horario.toString().trim().isNotEmpty)
_buildInfoLinha(
Icons.access_time_outlined,
'Horário',
horarioFormatado,
),
if (tipo != null &&
tipo.toString().trim().isNotEmpty)
_buildInfoLinha(
Icons.category_outlined,
'Tipo',
tipo.toString(),
),
if (status != null &&
status.toString().trim().isNotEmpty)
_buildInfoLinha(
Icons.info_outline,
'Status',
status.toString(),
),
if (observacoes != null &&
observacoes.toString().trim().isNotEmpty &&
observacoes.toString() != 'None')
_buildInfoLinha(
Icons.notes_outlined,
'Observações',
observacoes.toString(),
),
],
),
),
);
}

// ==========================================================
// MENSAGEM
// ==========================================================

Widget _buildMensagem() {
return Card(
child: Padding(
padding: const EdgeInsets.all(20),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.info_outline,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(width: 12),
const Expanded(
child: Text(
'Os dados apresentados são carregados '
'diretamente da sua conta na clínica.',
),
),
],
),
),
);
}

// ==========================================================
// ERRO
// ==========================================================

Widget _buildErro() {
return Scaffold(
appBar: AppBar(
title: const Text('Nexo APP'),
),
body: Center(
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
'Não foi possível carregar seus dados.',
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
_erro!,
textAlign: TextAlign.center,
),
const SizedBox(height: 24),
FilledButton.icon(
onPressed: _carregar,
icon: const Icon(Icons.refresh),
label: const Text('Tentar novamente'),
),
],
),
),
),
);
}
}

