import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'dart:async';

import 'package:saas_app/core/notifications/device_notifier.dart';
import 'package:saas_app/core/notifications/inbox_repository.dart';
import 'package:saas_app/core/notifications/inbox_stream.dart';

/// Bandeja de notificaciones del teléfono.
///
/// Lee lo mismo que la campana de la web: el backend escribe una entrada por
/// destinatario en cada envío, salga por el canal que salga. Que aquí aparezca
/// algo no significa que haya sonado el teléfono — eso lo hace el canal PUSH
/// cuando haya credenciales de Firebase; esto es el registro, y existe igual.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<InboxItem> _items = const [];
  bool _loading = true;
  String? _error;

  /// Lo que llega en vivo mientras esta pantalla esta abierta. Sin esto habria
  /// que arrastrar para recargar y ver algo que ya habia llegado.
  StreamSubscription<InboxItem>? _enVivo;

  /// Los avisos del sistema estan apagados: se ofrece encenderlos AQUI, que es
  /// donde la persona esta pensando en notificaciones. Pedir el permiso nada
  /// mas instalar se deniega, y en Android denegarlo dos veces lo bloquea.
  bool _avisosApagados = false;
  bool _pidiendoPermiso = false;

  @override
  void initState() {
    super.initState();
    _load();
    _revisarPermiso();
    _enVivo = ref.read(inboxStreamProvider).incoming.listen((InboxItem nueva) {
      if (!mounted) return;
      setState(() {
        _items = <InboxItem>[nueva, ..._items.where((InboxItem x) => x.id != nueva.id)];
      });
      ref.invalidate(unreadCountProvider);
    });
  }

  @override
  void dispose() {
    _enVivo?.cancel();
    super.dispose();
  }

  Future<void> _revisarPermiso() async {
    final bool ok = await ref.read(deviceNotifierProvider).enabled();
    if (!mounted) return;
    setState(() => _avisosApagados = !ok);
  }

  Future<void> _pedirPermiso() async {
    setState(() => _pidiendoPermiso = true);
    final bool ok = await ref.read(deviceNotifierProvider).requestPermission();
    if (!mounted) return;
    setState(() {
      _pidiendoPermiso = false;
      _avisosApagados = !ok;
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puedes activarlos en los ajustes del teléfono, en Moda ERP.'),
        ),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<InboxItem> items = await ref.read(inboxRepositoryProvider).mine();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar tus notificaciones.';
      });
    }
  }

  Future<void> _open(InboxItem n) async {
    if (n.unread) {
      // Optimista: la marca se ve al instante y se confirma contra el servidor.
      // Si falla, la próxima carga devuelve la verdad; no vale la pena bloquear
      // la interfaz por un acuse de lectura.
      setState(() {
        _items = _items
            .map(
              (x) => x.id == n.id
                  ? InboxItem(
                      id: x.id,
                      title: x.title,
                      body: x.body,
                      typeCode: x.typeCode,
                      readAt: DateTime.now(),
                      createdDate: x.createdDate,
                    )
                  : x,
            )
            .toList();
      });
      try {
        await ref.read(inboxRepositoryProvider).markRead(n.id);
        ref.invalidate(unreadCountProvider);
      } catch (_) {/* se corrige en la próxima carga */}
    }
    if (!mounted) return;
    _showDetail(n);
  }

  void _showDetail(InboxItem n) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              0,
              AppSpacing.marginMobile,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title ?? 'Notificación',
                  style: AppTypography.titleMd(color: scheme.onSurface),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _when(n.createdDate),
                  style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      n.plainBody,
                      style: AppTypography.bodyMd(color: scheme.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAll() async {
    try {
      await ref.read(inboxRepositoryProvider).markAllRead();
      ref.invalidate(unreadCountProvider);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo marcar como leídas.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hayNoLeidas = _items.any((n) => n.unread);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (hayNoLeidas)
            TextButton(
              onPressed: _markAll,
              child: const Text('Marcar leídas'),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_avisosApagados) _AvisoPermiso(
            cargando: _pidiendoPermiso,
            onActivar: _pedirPermiso,
            scheme: scheme,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(scheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _Centrado(
        icon: Icons.cloud_off_rounded,
        title: 'Sin conexión',
        message: _error!,
        scheme: scheme,
      );
    }

    if (_items.isEmpty) {
      // ListView y no Center: RefreshIndicator necesita algo desplazable para
      // que el gesto de arrastrar funcione tambien con la lista vacia.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          _Centrado(
            icon: Icons.notifications_none_rounded,
            title: 'Sin notificaciones',
            message: 'Aquí aparecerá lo que el sistema te vaya comunicando.',
            scheme: scheme,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: AppSpacing.bottomForNavBar(context)),
      itemCount: _items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
      itemBuilder: (_, i) {
        final InboxItem n = _items[i];
        return ListTile(
          onTap: () => _open(n),
          tileColor: n.unread ? scheme.surfaceContainerHighest : null,
          leading: CircleAvatar(
            backgroundColor: n.unread ? AppColors.primary : scheme.surfaceContainerHighest,
            child: Icon(
              _iconFor(n.typeCode),
              size: 18,
              color: n.unread ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            n.title ?? 'Notificación',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMd(color: scheme.onSurface),
          ),
          subtitle: Text(
            n.plainBody,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
          ),
          trailing: Text(
            _when(n.createdDate),
            style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
          ),
        );
      },
    );
  }

  /// El icono dice por dónde salió, que es información real: no es lo mismo que
  /// te lo hayan mandado por correo que por WhatsApp.
  static IconData _iconFor(String? typeCode) => switch (typeCode) {
        'EMAIL' => Icons.mail_outline_rounded,
        'SMS' => Icons.sms_outlined,
        'WHATSAPP' => Icons.chat_bubble_outline_rounded,
        'PUSH' => Icons.notifications_active_outlined,
        _ => Icons.notifications_none_rounded,
      };

  static String _when(DateTime d) {
    final Duration diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _Centrado extends StatelessWidget {
  const _Centrado({
    required this.icon,
    required this.title,
    required this.message,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final String message;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.titleMd(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
}

/// Banda para encender los avisos del sistema cuando estan apagados.
///
/// Dice QUE se pierde, no "activa las notificaciones": nadie concede un permiso
/// por un imperativo, y si por lo que se concede es por no enterarse tarde de
/// un pago, eso es lo que hay que decir.
class _AvisoPermiso extends StatelessWidget {
  const _AvisoPermiso({
    required this.cargando,
    required this.onActivar,
    required this.scheme,
  });

  final bool cargando;
  final VoidCallback onActivar;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.md,
        AppSpacing.marginMobile,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.notifications_off_outlined, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Los avisos están apagados. Enciéndelos y te enteras de un pago '
              'sin tener que abrir la app.',
              style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton.tonal(
                  onPressed: onActivar,
                  child: const Text('Activar'),
                ),
        ],
      ),
    );
  }
}
