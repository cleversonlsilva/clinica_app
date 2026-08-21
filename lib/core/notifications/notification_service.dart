import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Serviço central responsável pelas notificações locais
/// do Nexo APP.
///
/// Responsabilidades:
///
/// - inicializar o sistema de notificações;
/// - configurar o fuso horário do aparelho;
/// - solicitar permissões;
/// - agendar notificações;
/// - cancelar notificações;
/// - consultar notificações pendentes.
///
/// Este serviço não conhece regras de negócio da Agenda.
/// Ele apenas executa as operações relacionadas às
/// notificações locais.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _inicializado = false;

  // ============================================================
  // TIMEZONE
  // ============================================================

  /// Inicializa a base de fusos horários e configura
  /// o fuso local utilizado pelo aplicativo.
  ///
  /// O flutter_timezone retorna o identificador IANA
  /// do aparelho através de TimezoneInfo.identifier.
  ///
  /// Alguns emuladores Android podem retornar "GMT".
  /// Como o pacote timezone trabalha melhor com os
  /// identificadores da base IANA, fazemos a conversão:
  ///
  /// GMT -> Etc/GMT
  /// UTC -> Etc/UTC
  ///
  /// Caso o identificador não exista na base instalada,
  /// utilizamos UTC como fallback para impedir que o
  /// aplicativo inteiro falhe durante a inicialização.
  Future<void> _configurarTimezone() async {
    // Carrega a base de fusos horários.
    tz.initializeTimeZones();

    try {
      final timezoneInfo =
      await FlutterTimezone.getLocalTimezone();

      final identificador =
      timezoneInfo.identifier.trim();

      final identificadorNormalizado =
      _normalizarIdentificadorTimezone(
        identificador,
      );

      try {
        tz.setLocalLocation(
          tz.getLocation(
            identificadorNormalizado,
          ),
        );
      } catch (_) {
        // --------------------------------------------------------
        // FALLBACK
        // --------------------------------------------------------
        //
        // Se o identificador retornado pelo sistema não existir
        // na base do pacote timezone, usamos UTC.
        //
        // Isso impede que um problema de configuração do
        // emulador impeça a Agenda de carregar.
        //
        tz.setLocalLocation(
          tz.getLocation('Etc/UTC'),
        );
      }
    } catch (_) {
      // ----------------------------------------------------------
      // FALLBACK FINAL
      // ----------------------------------------------------------
      //
      // Caso não seja possível obter o timezone do sistema,
      // o aplicativo continua funcionando usando UTC.
      // ----------------------------------------------------------

      tz.setLocalLocation(
        tz.getLocation('Etc/UTC'),
      );
    }
  }

  /// Normaliza identificadores que podem ser retornados
  /// pelo sistema operacional, mas que não correspondem
  /// diretamente aos nomes utilizados pelo pacote timezone.
  String _normalizarIdentificadorTimezone(
      String identificador,
      ) {
    if (identificador.isEmpty) {
      return 'Etc/UTC';
    }

    switch (identificador) {
      case 'GMT':
        return 'Etc/GMT';

      case 'UTC':
        return 'Etc/UTC';

      case 'GMT+00:00':
        return 'Etc/GMT';

      case 'GMT-00:00':
        return 'Etc/GMT';

      default:
        return identificador;
    }
  }

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  /// Inicializa o serviço de notificações.
  ///
  /// A inicialização é executada apenas uma vez.
  Future<void> inicializar() async {
    if (_inicializado) {
      return;
    }

    // ==========================================================
    // TIMEZONE
    // ==========================================================

    await _configurarTimezone();

    // ==========================================================
    // ANDROID
    // ==========================================================

    const androidSettings =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ==========================================================
    // IOS
    // ==========================================================

    const darwinSettings =
    DarwinInitializationSettings();

    // ==========================================================
    // CONFIGURAÇÃO GERAL
    // ==========================================================

    const initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    _inicializado = true;
  }

  // ============================================================
  // PERMISSÕES
  // ============================================================

  /// Solicita permissão para exibir notificações.
  ///
  /// No Android, solicita a permissão de notificações
  /// quando a plataforma disponibilizar esse recurso.
  ///
  /// No iOS, solicita alertas, sons e badges.
  Future<bool> solicitarPermissao() async {
    await inicializar();

    // ==========================================================
    // ANDROID
    // ==========================================================

    final android =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final concedida =
      await android.requestNotificationsPermission();

      return concedida ?? false;
    }

    // ==========================================================
    // IOS
    // ==========================================================

    final ios =
    _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      final concedida =
      await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return concedida ?? false;
    }

    // ==========================================================
    // OUTRAS PLATAFORMAS
    // ==========================================================

    return true;
  }

  // ============================================================
  // AGENDAR
  // ============================================================

  /// Agenda uma notificação local.
  ///
  /// [id]
  /// Identificador único da notificação.
  ///
  /// [titulo]
  /// Título apresentado ao paciente.
  ///
  /// [mensagem]
  /// Mensagem apresentada ao paciente.
  ///
  /// [dataHora]
  /// Data e horário em que a notificação deverá aparecer.
  Future<void> agendar({
    required int id,
    required String titulo,
    required String mensagem,
    required DateTime dataHora,
  }) async {
    await inicializar();

    // ==========================================================
    // DATA NO FUSO LOCAL
    // ==========================================================
    //
    // A data recebida é convertida para o timezone configurado
    // em tz.local.
    //
    // Isso é importante para que um lembrete de consulta,
    // por exemplo:
    //
    // 19/08/2026 às 09:00
    //
    // seja interpretado no horário local do dispositivo.
    // ==========================================================

    final momento = tz.TZDateTime.from(
      dataHora,
      tz.local,
    );

    // ==========================================================
    // ANDROID
    // ==========================================================

    const androidDetails =
    AndroidNotificationDetails(
      'nexo_app_agendamentos',
      'Agendamentos',
      channelDescription:
      'Lembretes de consultas e agendamentos do Nexo APP.',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    // ==========================================================
    // IOS
    // ==========================================================

    const darwinDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // ==========================================================
    // CONFIGURAÇÃO DA NOTIFICAÇÃO
    // ==========================================================

    const notificationDetails =
    NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // ==========================================================
    // AGENDAMENTO
    // ==========================================================

    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: mensagem,
      scheduledDate: momento,
      notificationDetails: notificationDetails,
      androidScheduleMode:
      AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ============================================================
  // CANCELAR
  // ============================================================

  /// Cancela uma notificação específica.
  Future<void> cancelar(
      int id,
      ) async {
    await inicializar();

    await _plugin.cancel(
      id: id,
    );
  }

  // ============================================================
  // CANCELAR TODAS
  // ============================================================

  /// Cancela todas as notificações programadas.
  Future<void> cancelarTodas() async {
    await inicializar();

    await _plugin.cancelAll();
  }

  // ============================================================
  // PENDENTES
  // ============================================================

  /// Retorna as notificações atualmente programadas
  /// no dispositivo.
  Future<List<PendingNotificationRequest>>
  obterPendentes() async {
    await inicializar();

    return _plugin.pendingNotificationRequests();
  }
}