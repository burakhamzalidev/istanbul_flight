import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/istanbul_flight_game.dart';
import '../../progression/cosmetics.dart';
import '../../services/audio_service.dart';
import '../../services/progress.dart';
import '../pixel.dart';
import '../simit_frame_view.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'menu_overlays.dart';

// Phase 2.2: Simit Mağazası ve Martı Görünümü (docs/13_phase2_cosmetics_shop.md).
// Simitler yalnızca oyunda kazanılır; gerçek para, reklam ya da abonelik yok.

/// Görünümün sprite sheet'i (yüklenemediyse klasik; testlerde null).
ui.Image? sheetOf(IstanbulFlightGame game, String id) => game.art.sheetFor(id);

/// Animasyonlu Simit önizlemesi: kanat çırpar, süzülür (oyundaki karelerle). Ölçek tam sayı
/// ([scale]× 48×42) → pikseller keskin. Animasyonları azalt açıkken sabit süzülme karesi.
class SimitPreview extends StatefulWidget {
  const SimitPreview({
    super.key,
    required this.image,
    this.scale = 3,
    this.animate = true,
    this.staticFrame = 6,
  });

  final ui.Image? image;
  final int scale;
  final bool animate;
  final int staticFrame;

  @override
  State<SimitPreview> createState() => _SimitPreviewState();
}

class _SimitPreviewState extends State<SimitPreview>
    with SingleTickerProviderStateMixin {
  // 0,54 sn kanat döngüsü (6 × 90 ms) + 0,66 sn süzülme
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(SimitPreview old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _frame(double v) {
    final ms = v * 1200;
    return ms < 540 ? (ms / 90).floor().clamp(0, 5) : 6;
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(48.0 * widget.scale, 42.0 * widget.scale);
    return SizedBox.fromSize(
      size: size,
      child: widget.animate
          ? AnimatedBuilder(
              animation: _c,
              builder: (_, _) =>
                  SimitFrameView(image: widget.image, frame: _frame(_c.value)),
            )
          : SimitFrameView(image: widget.image, frame: widget.staticFrame),
    );
  }
}

/// Önizleme sahnesi: gök tonunda pixel çerçeve.
class _Stage extends StatelessWidget {
  const _Stage({required this.child, this.padding = 8});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: pixelBox(
      color: const Color(0xFF9DB0D8),
      border: UiColors.navy,
      steps: 2,
    ),
    child: child,
  );
}

class _Balance extends StatelessWidget {
  const _Balance({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: pixelBox(
      color: UiColors.cream,
      border: UiColors.mustard,
      steps: 2,
    ),
    child: Row(
      children: [
        const SimitIcon(size: 24),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Simit bakiyen', style: TextStyle(color: UiColors.navy)),
        ),
        Text(
          '$balance',
          key: const Key('shopBalance'),
          style: const TextStyle(color: UiColors.navy, fontSize: 20),
        ),
      ],
    ),
  );
}

// ======================= Mağaza =======================

class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  late String _focus = effectiveCosmetic(widget.game.services.progress.value)
      .id;
  String? _confirm;
  String? _justBought;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  IstanbulFlightGame get g => widget.game;

  void _select(String id) => setState(() {
    _focus = id;
    if (_confirm != id) _confirm = null;
    _message = null;
  });

  final _panelKey = GlobalKey();

  /// Onay paneli listenin üstünde: aşağıdaki bir kartta "Satın al"a basılınca görünür alana kaydırılır.
  void _askPurchase(String id) {
    setState(() {
      _focus = id;
      _confirm = id;
      _justBought = null;
      _message = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _panelKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: g.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _purchase(String id) async {
    if (_busy) return; // çift dokunma
    setState(() => _busy = true);
    final r = await g.services.progress.purchase(id);
    if (!mounted) return;
    final c = cosmeticById(id);
    setState(() {
      _busy = false;
      _confirm = null;
      _messageIsError = r != PurchaseResult.purchased;
      _message = switch (r) {
        PurchaseResult.purchased => '${c?.name} artık senin!',
        PurchaseResult.alreadyOwned => 'Bu görünüm zaten sende.',
        PurchaseResult.insufficientFunds =>
          'Yetersiz simit. Uçarak ve görev tamamlayarak simit kazanabilirsin.',
        PurchaseResult.levelLocked =>
          'Bu görünüm ${c?.minLevel}. seviyede açılır.',
        PurchaseResult.unknownItem => 'Bu görünüm bulunamadı.',
        PurchaseResult.busy => 'Satın alma sürüyor…',
        PurchaseResult.saveFailed =>
          'Satın alma kaydedilemedi; simit düşülmedi. Lütfen tekrar dene.',
      };
      if (r == PurchaseResult.purchased) _justBought = id;
    });
    if (r == PurchaseResult.purchased) {
      g.services.audio.playSfx(Sfx.record);
      g.services.haptics.medium();
    }
  }

  void _equip(String id) {
    if (g.services.progress.equip(id)) {
      setState(() {
        _justBought = null;
        _messageIsError = false;
        _message =
            '${cosmeticById(id)?.name} seçildi. Sonraki uçuşunda görünecek.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ModalCard(
    game: g,
    title: 'Simit Mağazası',
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: g.services.progress,
      builder: (_, p, _) {
        final focus = cosmeticById(_focus) ?? cosmeticCatalog.first;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Balance(balance: p.simitBalance),
            const SizedBox(height: 10),
            _FocusPanel(
              key: _panelKey,
              game: g,
              item: focus,
              progress: p,
              confirming: _confirm == focus.id,
              busy: _busy,
              justBought: _justBought == focus.id,
              onConfirm: () => _purchase(focus.id),
              onCancel: () => setState(() => _confirm = null),
              onEquip: () => _equip(focus.id),
            ),
            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(
                _message!,
                key: const Key('shopMessage'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _messageIsError ? UiColors.action : UiColors.navy,
                  fontSize: 15,
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final c in cosmeticCatalog) ...[
              _ShopCard(
                game: g,
                item: c,
                progress: p,
                focused: c.id == focus.id,
                busy: _busy,
                onTap: () => _select(c.id),
                onBuy: () => _askPurchase(c.id),
                onEquip: () => _equip(c.id),
              ),
              const SizedBox(height: 6),
            ],
            const Text(
              'Simitler yalnızca oyunda kazanılır. Görünümler sadece görseldir; '
              'uçuşu, çarpışmayı ve skoru etkilemez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: UiColors.navySoft, fontSize: 10),
            ),
          ],
        );
      },
    ),
  );
}

/// Üstteki büyük önizleme + seçili ürünün işlemi (onay, satın alındı damgası, kullan).
class _FocusPanel extends StatelessWidget {
  const _FocusPanel({
    super.key,
    required this.game,
    required this.item,
    required this.progress,
    required this.confirming,
    required this.busy,
    required this.justBought,
    required this.onConfirm,
    required this.onCancel,
    required this.onEquip,
  });

  final IstanbulFlightGame game;
  final CosmeticDef item;
  final PlayerProgress progress;
  final bool confirming;
  final bool busy;
  final bool justBought;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final status = cosmeticStatus(progress, item);
    final left = progress.simitBalance - item.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Stage(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Semantics(
                  label: '${item.name} önizlemesi',
                  image: true,
                  child: SimitPreview(
                    key: const Key('shopPreview'),
                    image: sheetOf(game, item.id),
                    animate: !game.reduceMotion,
                  ),
                ),
              ),
              if (justBought)
                Positioned(
                  top: 0,
                  child: _BoughtStamp(reduce: game.reduceMotion),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.name,
          key: const Key('shopFocusName'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: UiColors.navy, fontSize: 20),
        ),
        Text(
          '${item.category.label} · ${item.description}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
        ),
        const SizedBox(height: 8),
        if (confirming)
          Container(
            key: const Key('purchaseConfirm'),
            padding: const EdgeInsets.all(10),
            decoration: pixelBox(
              color: const Color(0xFFF6EBC8),
              border: UiColors.mustard,
              steps: 2,
            ),
            child: Column(
              children: [
                Text(
                  '${item.name} alınsın mı?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: UiColors.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fiyat ${item.price} simit · Kalan ${left < 0 ? 0 : left} simit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MartiButton(
                        key: const Key('cancelPurchase'),
                        game: game,
                        label: 'Vazgeç',
                        style: MartiButtonStyle.secondary,
                        height: 48,
                        onPressed: busy ? null : onCancel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MartiButton(
                        key: const Key('confirmPurchase'),
                        game: game,
                        label: busy ? 'Bekle' : 'Satın al',
                        height: 48,
                        onPressed: busy ? null : onConfirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else if (justBought && status == CosmeticStatus.owned)
          MartiButton(
            key: const Key('equipAfterBuy'),
            game: game,
            label: 'Hemen kullan',
            height: 52,
            onPressed: onEquip,
          ),
      ],
    );
  }
}

/// "SATIN ALINDI!" damgası: rekor damgası gibi 3 sabit ölçek adımında basılır (bulanıklık yok).
class _BoughtStamp extends StatefulWidget {
  const _BoughtStamp({required this.reduce});

  final bool reduce;

  @override
  State<_BoughtStamp> createState() => _BoughtStampState();
}

class _BoughtStampState extends State<_BoughtStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stamp = Container(
      key: const Key('boughtStamp'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: pixelBox(
        color: UiColors.paper,
        border: UiColors.action,
        borderWidth: kUiPx * 2,
        steps: 1,
      ),
      child: const Text(
        'SATIN ALINDI!',
        style: TextStyle(
          color: UiColors.action,
          fontSize: 15,
          letterSpacing: 2,
        ),
      ),
    );
    if (widget.reduce) return stamp;
    return AnimatedBuilder(
      animation: _c,
      child: stamp,
      builder: (_, child) {
        final t = _c.value;
        final scale = t < 0.25
            ? 2.0
            : t < 0.5
            ? 1.5
            : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.game,
    required this.item,
    required this.progress,
    required this.focused,
    required this.busy,
    required this.onTap,
    required this.onBuy,
    required this.onEquip,
  });

  final IstanbulFlightGame game;
  final CosmeticDef item;
  final PlayerProgress progress;
  final bool focused;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final status = cosmeticStatus(progress, item);
    final missing = item.price - progress.simitBalance;
    final statusText = switch (status) {
      CosmeticStatus.equipped => 'Kullanılıyor',
      CosmeticStatus.owned => 'Sende',
      CosmeticStatus.levelLocked => '${item.minLevel}. seviyede açılır',
      CosmeticStatus.affordable => '${item.price} simit',
      CosmeticStatus.tooExpensive => '${item.price} simit · $missing eksik',
    };
    final action = switch (status) {
      CosmeticStatus.equipped => MartiButton(
        key: Key('equipped_${item.id}'),
        game: game,
        label: 'Kullanılıyor',
        style: MartiButtonStyle.ghost,
        height: 44,
        onPressed: null,
      ),
      CosmeticStatus.owned => MartiButton(
        key: Key('equip_${item.id}'),
        game: game,
        label: 'Kullan',
        style: MartiButtonStyle.secondary,
        height: 44,
        onPressed: busy ? null : onEquip,
      ),
      CosmeticStatus.levelLocked => MartiButton(
        key: Key('locked_${item.id}'),
        game: game,
        label: 'Kilitli',
        style: MartiButtonStyle.ghost,
        height: 44,
        onPressed: null,
      ),
      CosmeticStatus.affordable || CosmeticStatus.tooExpensive => MartiButton(
        key: Key('buy_${item.id}'),
        game: game,
        label: 'Satın al',
        height: 44,
        onPressed: busy || status == CosmeticStatus.tooExpensive ? null : onBuy,
      ),
    };
    return Semantics(
      container: true,
      label: '${item.name}, $statusText',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: Key('shopItem_${item.id}'),
          padding: const EdgeInsets.all(8),
          decoration: pixelBox(
            color: focused ? const Color(0xFFF6EBC8) : UiColors.cream,
            border: focused ? UiColors.mustard : const Color(0xFFD8CDB6),
            steps: 2,
          ),
          child: Row(
            children: [
              _Stage(
                padding: 2,
                child: SimitPreview(
                  image: sheetOf(game, item.id),
                  scale: 2,
                  animate: false,
                  staticFrame: item.previewFrame,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(color: UiColors.navy),
                    ),
                    Row(
                      children: [
                        if (status == CosmeticStatus.affordable ||
                            status == CosmeticStatus.tooExpensive) ...[
                          const SimitIcon(size: 18),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            statusText,
                            key: Key('shopStatus_${item.id}'),
                            style: TextStyle(
                              fontSize: 10,
                              color: status == CosmeticStatus.tooExpensive
                                  ? UiColors.action
                                  : UiColors.navySoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    action,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= Martı Görünümü =======================

class WardrobeOverlay extends StatelessWidget {
  const WardrobeOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Martı Görünümü',
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: game.services.progress,
      builder: (_, p, _) {
        final current = effectiveCosmetic(p);
        final owned = cosmeticCatalog
            .where((c) => ownsCosmetic(p, c.id))
            .toList();
        final notOwned = cosmeticCatalog.length - owned.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stage(
              child: Center(
                child: SimitPreview(
                  key: const Key('wardrobePreview'),
                  image: sheetOf(game, current.id),
                  animate: !game.reduceMotion,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              current.name,
              key: const Key('wardrobeCurrent'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.navy, fontSize: 20),
            ),
            const Text(
              'Seçimin menüde hemen, uçuşta bir sonraki turda görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(color: UiColors.navySoft, fontSize: 10),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in owned)
                  _OwnedTile(game: game, item: c, selected: c.id == current.id),
              ],
            ),
            const SizedBox(height: 10),
            MartiButton(
              key: const Key('resetClassic'),
              game: game,
              label: 'Klasik görünüme dön',
              style: MartiButtonStyle.secondary,
              height: 48,
              onPressed: current.id == classicCosmeticId
                  ? null
                  : () => game.services.progress.equip(classicCosmeticId),
            ),
            const SizedBox(height: 8),
            MartiButton(
              key: const Key('openShop'),
              game: game,
              label: notOwned > 0 ? 'Mağaza · $notOwned yeni' : 'Mağaza',
              style: MartiButtonStyle.secondary,
              height: 48,
              onPressed: () => game.openModal(Overlays.shop),
            ),
          ],
        );
      },
    ),
  );
}

class _OwnedTile extends StatelessWidget {
  const _OwnedTile({
    required this.game,
    required this.item,
    required this.selected,
  });

  final IstanbulFlightGame game;
  final CosmeticDef item;
  final bool selected;

  @override
  Widget build(BuildContext context) => Pressable(
    key: Key('wear_${item.id}'),
    game: game,
    semanticLabel: selected
        ? '${item.name}, kullanılıyor'
        : '${item.name}, kullanmak için dokun',
    onTap: selected ? null : () => game.services.progress.equip(item.id),
    child: Container(
      width: 116,
      padding: const EdgeInsets.all(6),
      decoration: pixelBox(
        color: selected ? const Color(0xFFF6EBC8) : UiColors.cream,
        border: selected ? UiColors.mustard : const Color(0xFFD8CDB6),
        borderWidth: selected ? kUiPx * 2 : kUiPx,
        steps: 2,
      ),
      child: Column(
        children: [
          _Stage(
            padding: 2,
            child: SimitPreview(
              image: sheetOf(game, item.id),
              scale: 2,
              animate: false,
              staticFrame: item.previewFrame,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(color: UiColors.navy, fontSize: 10),
          ),
          Text(
            selected ? 'KULLANILIYOR' : 'KULLAN',
            style: TextStyle(
              fontSize: 10,
              color: selected ? UiColors.action : UiColors.navySoft,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Menüdeki simit rozeti: bakiyeyi gösterir, dokununca mağazayı açar.
class ShopChip extends StatelessWidget {
  const ShopChip({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlayerProgress>(
    valueListenable: game.services.progress,
    builder: (context, p, _) {
      final narrow = MediaQuery.sizeOf(context).width < 360;
      return Pressable(
        key: const Key('shopButton'),
        game: game,
        semanticLabel: 'Simit mağazası, bakiye ${p.simitBalance}',
        onTap: () => game.openModal(Overlays.shop),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pixelBox(
            color: UiColors.scrim,
            border: const Color(0x66FBF7EE),
            steps: 3,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: UiColors.paper, fontSize: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SimitIcon(size: 18),
                const SizedBox(width: 6),
                Text('${p.simitBalance}', key: const Key('totalSimits')),
                if (!narrow) ...[
                  const SizedBox(width: 6),
                  const Text(
                    '· Mağaza',
                    style: TextStyle(color: UiColors.mustard),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
