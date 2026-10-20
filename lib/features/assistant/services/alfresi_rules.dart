import '../domain/alfresi_context.dart';
import '../domain/alfresi_message.dart';
import '../../../core/models/machine_state.dart';
import '../../vision/domain/vision_state.dart';

abstract final class AlfresiRules {
  static AlfresiMessage explain(AlfresiContext c) {
    if (c.machine.finalLimits.hasFault) {
      return const AlfresiMessage(
        'Revisa los finales de carrera',
        'Los dos límites de un mismo eje aparecen activos. Ese eje permanece bloqueado. Revisa los sensores antes de continuar.',
        AlfresiMood.error,
      );
    }
    if (c.machine.finalLimitActive == true && c.canMove) {
      return const AlfresiMessage(
        'Final de carrera activo',
        'La dirección afectada está bloqueada. Revisa los indicadores de seguridad.',
        AlfresiMood.error,
      );
    }
    if (c.machine.finalLimitActive == true) {
      return const AlfresiMessage(
        'Movimiento bloqueado por seguridad',
        'El último estado del ESP32 informa un final de carrera activo. Revisa el diagnóstico de seguridad.',
        AlfresiMood.error,
      );
    }
    if (c.machine.connectionError != null &&
        c.machine.connection != ConnectionPhase.connecting) {
      return AlfresiMessage(
        'La conexión del ESP32 no pudo completarse',
        c.machine.connectionError!,
        AlfresiMood.error,
      );
    }
    if (!c.machine.isConnected && c.transportOpen) {
      return const AlfresiMessage(
        'El dispositivo respondió',
        'El proceso todavía no terminó. Estamos esperando la confirmación READY.',
        AlfresiMood.thinking,
      );
    }
    if (c.machine.connection == ConnectionPhase.connecting) {
      return const AlfresiMessage(
        'Conexión en proceso',
        'Estamos esperando la respuesta del ESP32. El control permanece bloqueado.',
        AlfresiMood.thinking,
      );
    }
    if (!c.machine.isConnected) {
      return const AlfresiMessage(
        'Sin conexión de control',
        'El ESP32 aún no está disponible. Revisa la conexión en Ajustes o consulta Diagnósticos.',
        AlfresiMood.warning,
      );
    }
    if (!c.machine.finalLimits.isComplete &&
        c.machine.finalLimitActive == null) {
      return const AlfresiMessage(
        'Esperando los sensores de seguridad',
        'El ESP32 está conectado. Esperamos las lecturas de los cuatro finales de carrera para habilitar el movimiento.',
        AlfresiMood.thinking,
      );
    }
    if (c.machine.sequence == SequencePhase.requested) {
      return const AlfresiMessage(
        'Esperando confirmación de la secuencia',
        'La orden fue enviada al ESP32. Esperamos su respuesta antes de mostrar la secuencia como iniciada. El control manual permanece bloqueado.',
        AlfresiMood.thinking,
      );
    }
    if (c.machine.sequenceActive) {
      return const AlfresiMessage(
        'Secuencia activa',
        'El ESP32 está ejecutando la secuencia. El movimiento manual permanece bloqueado.',
        AlfresiMood.warning,
      );
    }
    if (c.manualLocked) {
      return const AlfresiMessage(
        'Control manual bloqueado',
        'El bloqueo manual está activado. Puedes revisar su estado en Control.',
        AlfresiMood.warning,
      );
    }
    if (!c.vision.ready) {
      if (c.vision.connection == VisionConnection.connecting ||
          c.vision.connection == VisionConnection.reconnecting ||
          (c.vision.isConnected && !c.vision.stale)) {
        return const AlfresiMessage(
          'Preparando la visión',
          'Esperando la confirmación del servicio de la laptop. La conexión del ESP32 se mantiene independiente.',
          AlfresiMood.thinking,
        );
      }
      return AlfresiMessage(
        c.canMove
            ? 'El control del robot está disponible'
            : 'El ESP32 está conectado',
        'La visión de la laptop no está lista. Su conexión es independiente del ESP32.${c.vision.error == null ? '' : '\n${c.vision.error}'}',
        AlfresiMood.warning,
      );
    }
    if (c.vision.reportStale || c.vision.alerts.isNotEmpty) {
      return const AlfresiMessage(
        'Revisa los datos de visión',
        'La conexión está disponible, pero hay alertas o un reporte caducado. Consulta Visión.',
        AlfresiMood.warning,
      );
    }
    if (c.machine.finalLimitActive == null) {
      return const AlfresiMessage(
        'Ambos enlaces están disponibles',
        'ESP32 conectado y visión lista. El final de carrera aún no tiene datos.',
        AlfresiMood.idle,
      );
    }
    if (c.machine.activeMovement != null) {
      return AlfresiMessage(
        'Movimiento activo',
        '${c.machine.activeMovement!.label}. Suelta el botón para detener.',
        AlfresiMood.warning,
      );
    }
    if (!c.canMove) {
      return const AlfresiMessage(
        'Control temporalmente bloqueado',
        'Ambos enlaces están disponibles. Consulta el diagnóstico para revisar el bloqueo del sistema.',
        AlfresiMood.warning,
      );
    }
    return const AlfresiMessage(
      'Todo está funcionando correctamente',
      'ESP32 conectado. Visión disponible. Final de carrera libre y control manual disponible.',
      AlfresiMood.success,
    );
  }

  static String help(String section) => switch (section) {
    'Control' =>
      'Mantén pulsada una dirección para realizar movimiento manual. Suelta para detener. STOP está en el centro del mando.',
    'Visión' =>
      'Aquí puedes revisar los datos recibidos desde la laptop. Los valores ausentes aparecen como Sin datos o —.',
    'Ajustes' =>
      'Aquí puedes personalizar BLANQUITA y revisar las conexiones de ESP32 y Visión por separado.',
    'Diagnósticos' =>
      'Revisa las fases observadas y la bitácora. Puedes copiar los eventos para compartir el diagnóstico.',
    'Dispositivos' || 'Vinculación' =>
      'Busca los equipos en la misma red Wi-Fi. Selecciona la identidad del ESP32 y revisa su vinculación. La visión de la laptop se conecta por separado.',
    _ =>
      'Aquí tienes el estado general, las conexiones, los sensores informados y la actividad reciente del robot.',
  };
}
