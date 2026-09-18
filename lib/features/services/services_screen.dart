import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/finance/service_charge_repository.dart';
import 'package:saas_app/features/services/service_detail_sheet.dart';
import 'package:saas_app/features/services/service_phase_ui.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';
import 'package:saas_app/shared/widgets/app_tag.dart';

/// Filtros de la pantalla. No son los estados del back uno a uno: son las
/// PREGUNTAS que se hace el empleado — "¿qué me toca?", "¿qué estoy esperando?",
/// "¿qué ya cobré?". Un filtro por estado técnico obligaría a saber el modelo.
enum _Filtro {
  agenda('Agenda'),
  espera('En espera'),
  listos('Contabilizados'),
  todos('Todos');

  const _Filtro(this.label);
  final String label;

  bool acepta(ServicePhase p) => switch (this) {
        _Filtro.agenda => p.esAgenda,
        _Filtro.espera => p == ServicePhase.porAprobar || p == ServicePhase.aprobado,
        _Filtro.listos => p == ServicePhase.abonado || p == ServicePhase.rechazado,
        // Lo cancelado solo sale en "Todos": no es trabajo suyo pendiente ni
        // plata contabilizada, pero borrarlo dejaría un hueco sin explicación
        // en el día donde el cliente no llegó.
        _Filtro.todos => true,
      };
}

/// Mis servicios: la agenda y todo lo prestado, con su estado.
///
/// Es la pantalla del TRABAJO. El dinero vive en Movimientos, y separarlas es lo
/// que evita la pantalla donde citas, saldos y pagos se mezclan.
///
/// Cada fila dice lo justo para reconocer el servicio: cuándo, qué y cuánto se
/// lleva. Lo demás —cliente, forma de pago, qué se queda el negocio— sale al
/// tocarla. Meterlo en la fila haría una lista que hay que leer en vez de ojear.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  _Filtro _filtro = _Filtro.agenda;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<ServiceItem>> all = ref.watch(myServicesProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(myServicesProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis servicios', style: AppTypography.headlineLg(color: scheme.onSurface)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tu agenda y todo lo que has hecho.',
                      style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),

            // Los filtros se quedan arriba al desplazar: cambiar de vista es lo
            // que más se hace aquí, y perseguirlos hacia arriba es un fastidio.
            SliverPersistentHeader(
              pinned: true,
              delegate: _FiltrosHeader(
                actual: _filtro,
                conteos: _conteos(all.valueOrNull ?? const []),
                onChange: (f) => setState(() => _filtro = f),
                background: scheme.surface,
              ),
            ),

            all.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.only(top: AppSpacing.section), child: AppLoader()),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: _Vacio(
                  titulo: 'No se pudo cargar',
                  cuerpo: 'Revisa tu conexión y desliza hacia abajo para reintentar.',
                ),
              ),
              data: (items) => _lista(items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<ServiceItem> items) {
    final List<ServiceItem> visibles = items.where((s) => _filtro.acepta(s.phase)).toList()
      ..sort((a, b) {
        // La agenda va hacia adelante (lo primero que toca, arriba); el resto
        // hacia atrás (lo último que pasó, arriba). Es cómo se mira cada cosa.
        final int c = _filtro == _Filtro.agenda
            ? a.serviceDate.compareTo(b.serviceDate)
            : b.serviceDate.compareTo(a.serviceDate);
        return c != 0 ? c : (a.hora ?? '').compareTo(b.hora ?? '');
      });

    if (visibles.isEmpty) {
      return SliverToBoxAdapter(child: _Vacio(titulo: _vacioTitulo(), cuerpo: _vacioCuerpo()));
    }

    final List<_Grupo> grupos = _agrupar(visibles);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile,
        AppSpacing.bottomForNavBar(context),
      ),
      sliver: SliverList.builder(
        itemCount: grupos.length,
        itemBuilder: (_, i) => _Seccion(grupo: grupos[i]),
      ),
    );
  }

  Map<_Filtro, int> _conteos(List<ServiceItem> items) {
    final Map<_Filtro, int> out = {};
    for (final _Filtro f in _Filtro.values) {
      out[f] = items.where((s) => f.acepta(s.phase)).length;
    }
    return out;
  }

  String _vacioTitulo() => switch (_filtro) {
        _Filtro.agenda => 'No tienes nada agendado',
        _Filtro.espera => 'Nada en espera',
        _Filtro.listos => 'Todavía nada contabilizado',
        _Filtro.todos => 'Aún no tienes servicios',
      };

  String _vacioCuerpo() => switch (_filtro) {
        _Filtro.agenda => 'Cuando te agenden una cita aparecerá aquí con su hora y su cliente.',
        _Filtro.espera => 'Aquí verás lo que marcaste terminado mientras tu jefe lo revisa.',
        _Filtro.listos => 'Aquí queda lo aprobado que ya sumó a tu saldo, y lo que se rechazó.',
        _Filtro.todos => 'Tus servicios aparecerán aquí en cuanto te agenden el primero.',
      };

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Agrupa por día en la agenda y por mes en lo demás: en la agenda importa el
  /// día concreto; en el historial, nadie busca "el 14 de abril".
  List<_Grupo> _agrupar(List<ServiceItem> items) {
    final Map<String, List<ServiceItem>> mapa = {};
    for (final ServiceItem s in items) {
      mapa.putIfAbsent(_etiqueta(s.serviceDate), () => []).add(s);
    }
    return mapa.entries.map((e) => _Grupo(e.key, e.value)).toList();
  }

  String _etiqueta(DateTime d) {
    final DateTime hoy = DateTime.now();
    final bool mismoDia = d.year == hoy.year && d.month == hoy.month && d.day == hoy.day;
    if (_filtro == _Filtro.agenda) {
      if (mismoDia) return 'Hoy';
      final DateTime manana = hoy.add(const Duration(days: 1));
      if (d.year == manana.year && d.month == manana.month && d.day == manana.day) return 'Mañana';
      return '${d.day} de ${_meses[d.month - 1]}';
    }
    if (d.year == hoy.year && d.month == hoy.month) return 'Este mes';
    return d.year == hoy.year ? _meses[d.month - 1] : '${_meses[d.month - 1]} ${d.year}';
  }
}

class _Grupo {
  const _Grupo(this.label, this.items);
  final String label;
  final List<ServiceItem> items;
}

/// Cabecera fija con los filtros. Es un delegate y no un `SliverAppBar` porque
/// solo tiene que quedarse pegada, sin colapsar ni cambiar de alto.
class _FiltrosHeader extends SliverPersistentHeaderDelegate {
  _FiltrosHeader({
    required this.actual,
    required this.conteos,
    required this.onChange,
    required this.background,
  });

  final _Filtro actual;
  final Map<_Filtro, int> conteos;
  final ValueChanged<_Filtro> onChange;
  final Color background;

  static const double _alto = 64;

  @override
  double get minExtent => _alto;
  @override
  double get maxExtent => _alto;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: background,
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
        children: [
          for (final _Filtro f in _Filtro.values) ...[
            _Chip(
              label: f.label,
              // El contador solo cuando hay algo: un "(0)" permanente es ruido
              // que además desanima a entrar.
              count: conteos[f] ?? 0,
              active: f == actual,
              onTap: () => onChange(f),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FiltrosHeader old) =>
      old.actual != actual || old.conteos.toString() != conteos.toString();
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.active, required this.onTap});
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? AppColors.primary : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.labelMd(color: active ? Colors.white : scheme.onSurfaceVariant),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.sm - 2),
                Text(
                  '$count',
                  style: AppTypography.labelSm(
                    color: active ? Colors.white.withValues(alpha: 0.8) : scheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.grupo});
  final _Grupo grupo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.md),
            child: Text(
              grupo.label.toUpperCase(),
              style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppElevation.card,
            ),
            child: Column(
              children: [
                for (int i = 0; i < grupo.items.length; i++) ...[
                  ServiceRow(item: grupo.items[i]),
                  if (i < grupo.items.length - 1)
                    Divider(height: 1, indent: AppSpacing.section + AppSpacing.md,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de servicio. Lo MÍNIMO para reconocerlo: cuándo, qué, cuánto se
/// lleva y en qué va. Público porque Inicio pinta las mismas filas para "hoy":
/// dos maquetados distintos para la misma cosa se desincronizan solos.
class ServiceRow extends StatelessWidget {
  const ServiceRow({super.key, required this.item, this.showDate = false});

  final ServiceItem item;

  /// En Inicio y en la agenda basta la hora; en el historial hace falta el día.
  final bool showDate;

  /// Hoy le toca hacer algo con esto. Es lo único que se resalta: si todo
  /// destaca, nada destaca.
  bool get _accionable =>
      item.phase == ServicePhase.hoy || item.phase == ServicePhase.enCurso;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ServicePhase phase = item.phase;

    return InkWell(
      onTap: () => showServiceDetail(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: _accionable ? AppColors.primaryFixed : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Icon(
                phase.icon,
                size: 20,
                color: _accionable
                    ? AppColors.onPrimaryFixedVariant
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cuando(),
                    style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCOP(item.montoVisible),
                  style: AppTypography.titleMd(color: scheme.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppTag(label: phase.label, tone: phase.tone),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _cuando() {
    final String? franja = item.franja;
    if (!showDate) return franja ?? item.clientName;
    final String dia = '${item.serviceDate.day} ${_meses[item.serviceDate.month - 1]}';
    return franja == null ? dia : '$dia · $franja';
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.titulo, required this.cuerpo});
  final String titulo;
  final String cuerpo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile, AppSpacing.xl, AppSpacing.marginMobile, AppSpacing.section,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          boxShadow: AppElevation.card,
        ),
        child: Column(
          children: [
            Icon(Icons.event_available_outlined, size: 28, color: scheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(titulo, textAlign: TextAlign.center,
                style: AppTypography.titleMd(color: scheme.onSurface),),
            const SizedBox(height: AppSpacing.xs),
            Text(cuerpo, textAlign: TextAlign.center,
                style: AppTypography.bodySm(color: scheme.onSurfaceVariant),),
          ],
        ),
      ),
    );
  }
}
