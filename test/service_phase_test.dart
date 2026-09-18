import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/core/business/agenda_repository.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/finance/service_charge_repository.dart';

/// La fase de un servicio sale de DOS fuentes —la cita y el cargo— y el orden
/// en que se miran cambia lo que lee el empleado. Estas pruebas fijan ese orden.
void main() {
  final DateTime hoy = DateTime.now();
  final DateTime manana = hoy.add(const Duration(days: 1));

  AgendaAppointment cita(String estado, {DateTime? dia, double precio = 40000}) {
    final DateTime d = dia ?? hoy;
    return AgendaAppointment(
      id: 'cita-1',
      publicCode: 'ABCD1234',
      employeeId: 'emp-1',
      status: estado,
      channel: 'WEB_PUBLICA',
      startUtc: DateTime(d.year, d.month, d.day, 9),
      endUtc: DateTime(d.year, d.month, d.day, 9, 45),
      localDate: DateTime(d.year, d.month, d.day),
      backdated: false,
      totalPrice: precio,
      totalMinutes: 45,
      serviceName: 'Corte',
      clientName: 'Ana',
    );
  }

  ServiceItem cargo(String estado, {String? settlementId, double neto = 16000}) =>
      ServiceItem.fromJson(<String, dynamic>{
        'id': 'cargo-1',
        'appointmentId': 'cita-1',
        'status': estado,
        'serviceName': 'Corte',
        'serviceDate': '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-'
            '${hoy.day.toString().padLeft(2, '0')}',
        'clientName': 'Ana',
        'grossAmount': 40000,
        'deductionRate': 60,
        'netAmount': neto,
        'settlementId': settlementId,
      });

  group('la cita manda sobre el trabajo', () {
    test('confirmada para hoy es accionable; para mañana no', () {
      expect(ServiceItem.deCita(cita('CONFIRMADA'), null).phase, ServicePhase.hoy);
      expect(
        ServiceItem.deCita(cita('CONFIRMADA', dia: manana), null).phase,
        ServicePhase.agendado,
      );
    });

    test('sin confirmar no es de nadie todavía', () {
      expect(ServiceItem.deCita(cita('PENDIENTE_CONFIRMACION'), null).phase,
          ServicePhase.porConfirmar,);
    });

    test('en curso se distingue de agendada', () {
      expect(ServiceItem.deCita(cita('EN_CURSO'), null).phase, ServicePhase.enCurso);
    });

    test('completada sin cargo todavía ya espera aprobación', () {
      // Pasa entre que el empleado la termina y la siguiente sincronización.
      expect(ServiceItem.deCita(cita('COMPLETADA'), null).phase, ServicePhase.porAprobar,);
    });
  });

  group('el cargo manda sobre el dinero', () {
    test('aprobado sin liquidar todavía no está en el saldo', () {
      final ServiceItem s = ServiceItem.deCita(cita('COMPLETADA'), cargo('CONFIRMED'));
      expect(s.phase, ServicePhase.aprobado);
    });

    test('aprobado y liquidado ya está en el saldo', () {
      final ServiceItem s =
          ServiceItem.deCita(cita('COMPLETADA'), cargo('CONFIRMED', settlementId: 'liq-1'));
      expect(s.phase, ServicePhase.abonado);
    });

    test('descartado por el dueño se lee como rechazado', () {
      final ServiceItem s = ServiceItem.deCita(cita('COMPLETADA'), cargo('DISCARDED'));
      expect(s.phase, ServicePhase.rechazado);
    });
  });

  // El caso que motivó el orden: cancelar una cita también descarta su cargo.
  // Mirando el cargo primero, al empleado le diría "tu jefe no lo aprobó"
  // cuando lo que pasó es que el cliente canceló.
  group('una cita muerta no se lee como un rechazo', () {
    for (final String estado in <String>[
      'CANCELADA_CLIENTE',
      'CANCELADA_NEGOCIO',
      'NO_ASISTIO',
      'EXPIRADA',
    ]) {
      test('$estado con su cargo descartado dice "no se hizo"', () {
        final ServiceItem s = ServiceItem.deCita(cita(estado), cargo('DISCARDED'));
        expect(s.phase, ServicePhase.cancelado);
      });
    }
  });

  group('lo que se enseña en grande', () {
    test('sin cargo se enseña el precio, no un cero', () {
      final ServiceItem s = ServiceItem.deCita(cita('CONFIRMADA'), null);
      expect(s.tieneCargo, isFalse);
      expect(s.montoVisible, 40000);
    });

    test('con cargo se enseña la parte del empleado', () {
      final ServiceItem s = ServiceItem.deCita(cita('CONFIRMADA'), cargo('SCHEDULED'));
      expect(s.tieneCargo, isTrue);
      expect(s.montoVisible, 16000);
    });
  });

  test('un cargo sin cita sigue teniendo fase y llave', () {
    final ServiceItem suelto = ServiceItem.fromJson(<String, dynamic>{
      'id': 'cargo-9',
      'status': 'PENDING',
      'serviceName': 'Corte',
      'serviceDate': '2020-01-01',
      'clientName': 'Ana',
    });
    expect(suelto.id, 'cargo-9');
    expect(suelto.phase, ServicePhase.porAprobar);
  });

  // ── La fusión de las dos fuentes ──────────────────────────────────────────
  // Es donde puede romperse de verdad: dos listas de tipos distintos, unidas
  // por un id que puede faltar en cualquiera de los dos lados.

  group('myServicesProvider une la agenda con el dinero', () {
    ProviderContainer contenedor({
      required List<AgendaAppointment> agenda,
      required List<ServiceItem> cargos,
      String? businessId = 'negocio-1',
    }) {
      return ProviderContainer(overrides: <Override>[
        myBalanceProvider.overrideWith(
          (ref) async => EmployeeBalance(
            balance: 0,
            accrued: 0,
            paid: 0,
            currency: 'COP',
            employeeId: 'emp-1',
            businessId: businessId,
          ),
        ),
        agendaRepositoryProvider.overrideWithValue(_AgendaFalsa(agenda)),
        serviceChargeRepositoryProvider.overrideWithValue(_CargosFalsos(cargos)),
      ],);
    }

    test('cada cita sale una vez, con el dinero de su cargo', () async {
      final c = contenedor(agenda: [cita('CONFIRMADA')], cargos: [cargo('SCHEDULED')]);
      addTearDown(c.dispose);

      final List<ServiceItem> items = await c.read(myServicesProvider.future);
      expect(items, hasLength(1));
      expect(items.single.appointmentId, 'cita-1');
      expect(items.single.chargeId, 'cargo-1');
      expect(items.single.netAmount, 16000);
    });

    test('pide poner los cargos al día antes de leer', () async {
      final _AgendaFalsa fake = _AgendaFalsa([cita('CONFIRMADA')]);
      final c = ProviderContainer(overrides: <Override>[
        myBalanceProvider.overrideWith(
          (ref) async => const EmployeeBalance(
            balance: 0,
            accrued: 0,
            paid: 0,
            currency: 'COP',
            employeeId: 'emp-1',
            businessId: 'negocio-1',
          ),
        ),
        agendaRepositoryProvider.overrideWithValue(fake),
        serviceChargeRepositoryProvider.overrideWithValue(_CargosFalsos(const [])),
      ],);
      addTearDown(c.dispose);

      await c.read(myServicesProvider.future);
      expect(fake.sincronizados, ['negocio-1']);
    });

    test('un cargo viejo sin cita en la ventana no se pierde', () async {
      final ServiceItem viejo = ServiceItem.fromJson(<String, dynamic>{
        'id': 'cargo-viejo',
        'status': 'CONFIRMED',
        'settlementId': 'liq-7',
        'serviceName': 'Corte',
        'serviceDate': '2020-01-01',
        'clientName': 'Ana',
      });
      final c = contenedor(agenda: [cita('CONFIRMADA')], cargos: [cargo('SCHEDULED'), viejo]);
      addTearDown(c.dispose);

      final List<ServiceItem> items = await c.read(myServicesProvider.future);
      expect(items, hasLength(2));
      expect(items.last.id, 'cargo-viejo');
      expect(items.last.phase, ServicePhase.abonado);
    });

    test('si la agenda falla, la pantalla sale vacía y no revienta', () async {
      final c = ProviderContainer(overrides: <Override>[
        myBalanceProvider.overrideWith(
          (ref) async => const EmployeeBalance(
            balance: 0,
            accrued: 0,
            paid: 0,
            currency: 'COP',
            employeeId: 'emp-1',
            businessId: 'negocio-1',
          ),
        ),
        agendaRepositoryProvider.overrideWithValue(_AgendaFalsa(const [], rota: true)),
        serviceChargeRepositoryProvider.overrideWithValue(_CargosFalsos(const [])),
      ],);
      addTearDown(c.dispose);

      expect(await c.read(myServicesProvider.future), isEmpty);
    });

    test('sin negocio no se sincroniza, pero la agenda igual se lee', () async {
      final _AgendaFalsa fake = _AgendaFalsa([cita('CONFIRMADA')]);
      final c = ProviderContainer(overrides: <Override>[
        myBalanceProvider.overrideWith(
          (ref) async => const EmployeeBalance(
            balance: 0,
            accrued: 0,
            paid: 0,
            currency: 'COP',
            employeeId: 'emp-1',
          ),
        ),
        agendaRepositoryProvider.overrideWithValue(fake),
        serviceChargeRepositoryProvider.overrideWithValue(_CargosFalsos(const [])),
      ],);
      addTearDown(c.dispose);

      expect(await c.read(myServicesProvider.future), hasLength(1));
      expect(fake.sincronizados, isEmpty);
    });

    test('sin registro laboral no se pide nada', () async {
      final _AgendaFalsa fake = _AgendaFalsa(const []);
      final c = ProviderContainer(overrides: <Override>[
        myBalanceProvider.overrideWith((ref) async => EmployeeBalance.zero),
        agendaRepositoryProvider.overrideWithValue(fake),
        serviceChargeRepositoryProvider.overrideWithValue(_CargosFalsos(const [])),
      ],);
      addTearDown(c.dispose);

      expect(await c.read(myServicesProvider.future), isEmpty);
      expect(fake.consultas, isEmpty);
    });
  });
}

/// Agenda de mentira. `implements` y no `extends` porque el repositorio real
/// pide un cliente HTTP en el constructor y aquí no hay red que valga.
class _AgendaFalsa implements AgendaRepository {
  _AgendaFalsa(this._citas, {this.rota = false});
  final List<AgendaAppointment> _citas;
  final bool rota;

  final List<String> sincronizados = <String>[];
  final List<String> consultas = <String>[];

  @override
  Future<List<AgendaAppointment>> ofEmployee(
    String employeeId, {
    required DateTime from,
    required DateTime to,
  }) async {
    consultas.add(employeeId);
    if (rota) throw Exception('sin red');
    return _citas;
  }

  @override
  Future<void> changeStatus(String appointmentId, String status) async {}

  @override
  Future<void> syncCharges(String businessId) async => sincronizados.add(businessId);
}

class _CargosFalsos implements ServiceChargeRepository {
  _CargosFalsos(this._cargos);
  final List<ServiceItem> _cargos;

  @override
  Future<List<ServiceItem>> ofEmployee(String employeeId) async => _cargos;
}
