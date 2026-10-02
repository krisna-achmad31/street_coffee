import 'dart:async';
import 'dart:math';

import '../../domain/entities/comment.dart';
import '../../domain/entities/social.dart';
import '../../domain/repositories/social_repository.dart';

class _Persona {
  final String id;
  final String handle;
  final String photoUrl;
  final bool isPass;

  /// Treated as "followed" by whoever is logged in (tab Teman).
  final bool friend;
  const _Persona(this.id, this.handle, this.photoUrl,
      {this.isPass = false, this.friend = false});
}

class _Shop {
  final String id;
  final String name;
  final String vibe;
  final double distanceKm;
  final List<String> photos;
  final List<(String, int)> menu;
  const _Shop(this.id, this.name, this.vibe, this.distanceKm, this.photos,
      this.menu);
}

String _img(String id) => 'https://images.unsplash.com/photo-$id?w=900';

const _personas = [
  _Persona('demo_u_raka', '@rakaseduh', 'https://i.pravatar.cc/150?img=12',
      isPass: true, friend: true),
  _Persona('demo_u_nadia', '@nadiangopi', 'https://i.pravatar.cc/150?img=47',
      friend: true),
  _Persona('demo_u_bimo', '@bimo.v60', 'https://i.pravatar.cc/150?img=15'),
  _Persona('demo_u_sekar', '@sekarsenja', 'https://i.pravatar.cc/150?img=44',
      isPass: true),
  _Persona('demo_u_dimas', '@dimaskopijoss', 'https://i.pravatar.cc/150?img=33',
      friend: true),
  _Persona('demo_u_ayu', '@ayu.oatlatte', 'https://i.pravatar.cc/150?img=32'),
  _Persona('demo_u_fajar', '@fajarbegadang', 'https://i.pravatar.cc/150?img=59'),
  _Persona('demo_u_tari', '@tarikopisusu', 'https://i.pravatar.cc/150?img=26',
      friend: true),
];

final _shops = [
  _Shop('demo_s_skena', 'KOPI SKENA', 'Nongkrong Skena', 0.4, [
    _img('1554118811-1e0d58224f24'),
    _img('1509042239860-f550ce710b93'),
  ], [
    ('Kopi Susu Gula Aren', 22000),
    ('V60 Flores', 35000),
  ]),
  _Shop('demo_s_joss', 'GEROBAK KOPI JOSS', 'Kaki Lima', 1.2, [
    _img('1521017432531-fbd92d768814'),
    _img('1514432324607-a09d9b4aefdd'),
  ], [
    ('Kopi Joss Hitam', 8000),
    ('Kopi Tubruk', 6000),
  ]),
  _Shop('demo_s_bbg', 'STREET BREW BBG', 'Manual Brew', 2.7, [
    _img('1501339847302-ac426a4a7cbb'),
    _img('1568649929103-28ffbefaca1e'),
  ], [
    ('Oat Latte', 32000),
    ('Japanese Iced Kenya', 38000),
  ]),
  _Shop('demo_s_senja', 'TEPI SENJA KOPI', 'Rooftop', 3.5, [
    _img('1495474472287-4d71bcdd2085'),
    _img('1461023058943-07fcbe16d735'),
  ], [
    ('Es Kopi Pandan', 25000),
    ('Affogato', 30000),
  ]),
  _Shop('demo_s_lorong', 'LORONG ROASTERY', 'Manual Brew', 5.1, [
    _img('1447933601403-0c6688de566e'),
    _img('1442512595331-e89e73853f31'),
  ], [
    ('Aeropress Gayo', 33000),
    ('Piccolo', 27000),
  ]),
];

const _captions = [
  'Gula arennya pas, nggak bikin eneg. Wajib balik.',
  'Spot colokan banyak, WFC aman sampai sore ☕',
  'Barista-nya ramah banget, dijelasin beannya panjang lebar.',
  'Hujan + kopi tubruk = sempurna.',
  'Antre 15 menit tapi worth it sih.',
  'Playlist-nya skena parah, betah.',
  'Harga mahasiswa, rasa juara.',
  'Sunset dari rooftop-nya nggak ada obat.',
  'Acidity-nya cerah, aftertaste-nya manis. Rekomen!',
  'Tempat nugas paling nyaman minggu ini.',
];

const _comments = [
  'Wah besok ke sini ah',
  'Ini yang deket stasiun kan?',
  'Gula arennya emang juara',
  'Parkirnya susah nggak?',
  'Fix masuk list Mau ke sini',
  'Barista-nya yang gondrong itu ya? 😆',
  'Bukanya sampai jam berapa kak?',
  'Mantap, cheers!',
];

/// In-memory "live" social feed for demos: seeds a believable timeline,
/// then on every [tick] bumps Cheers, posts comments, rotates who is
/// "lagi di kedai" and occasionally drops a brand-new post on top.
///
/// The ticker only runs while someone is listening, so an idle app does
/// no work. Every id starts with `demo_` (see [isDemoId]).
class DemoFeedSimulator {
  final Random _rnd;
  final DateTime Function() _now;
  final Duration tick;

  /// Every Nth tick publishes a new Drop.
  final int newDropEvery;

  DemoFeedSimulator({
    Random? random,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 5),
    this.newDropEvery = 4,
  })  : _rnd = random ?? Random(),
        _now = clock ?? DateTime.now {
    _seed();
  }

  late final _changes = StreamController<void>.broadcast(
      onListen: _start, onCancel: _stop);
  Timer? _timer;
  int _ticks = 0;
  int _seq = 0;

  final _drops = <Drop>[]; // newest first
  final _commentsByDrop = <String, List<Comment>>{};
  final _presence = <String, List<_Persona>>{}; // shopId -> people there
  final _cheers = <String>{}; // "$dropId|$uid"
  final _wants = <String>{}; // "$uid|$shopId"
  final _pendingReplies = <Timer>{};

  bool get isRunning => _timer != null;

  // ---------------------------------------------------------------- reads

  List<Drop> feed(FeedTab tab, {String? uid}) {
    final now = _now();
    return switch (tab) {
      FeedTab.nearby => List.of(_drops),
      FeedTab.friends => uid == null
          ? const []
          : _drops.where((d) => _persona(d.userId)?.friend ?? false).toList(),
      FeedTab.trending => _drops
          .where((d) => now.difference(d.publishAt) < const Duration(days: 7))
          .toList()
        ..sort((a, b) => b.cheersCount.compareTo(a.cheersCount)),
    };
  }

  Drop? drop(String id) => _drops.where((d) => d.id == id).firstOrNull;

  List<Drop> shopDrops(String shopId) =>
      _drops.where((d) => d.shopId == shopId).toList();

  List<Drop> userDrops(String uid) =>
      _drops.where((d) => d.userId == uid).toList();

  List<LiveCheckin> liveCheckins() {
    final entries = _presence.entries.where((e) => e.value.isNotEmpty).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return [
      for (final e in entries)
        LiveCheckin(
          shopId: e.key,
          shopName: _shop(e.key).name,
          shopImageUrl: _shop(e.key).photos.first,
          userPhotos: e.value.map<String?>((p) => p.photoUrl).take(3).toList(),
          handles: e.value.map((p) => p.handle).toList(),
        ),
    ];
  }

  List<Comment> comments(String dropId) =>
      List.of(_commentsByDrop[dropId] ?? const <Comment>[]);

  bool cheered(String dropId, String uid) => _cheers.contains('$dropId|$uid');
  bool wanted(String uid, String shopId) => _wants.contains('$uid|$shopId');

  /// Emits [read]'s current value now and again after every change.
  Stream<T> watch<T>(T Function() read) => Stream.multi((c) {
        c.add(read());
        final sub = _changes.stream.listen((_) => c.add(read()));
        c.onCancel = sub.cancel;
      });

  // --------------------------------------------------------------- writes

  void setCheers(String dropId, String uid, bool on) {
    final key = '$dropId|$uid';
    if (on == _cheers.contains(key)) return;
    on ? _cheers.add(key) : _cheers.remove(key);
    _update(dropId, (d) => _copy(d, cheers: d.cheersCount + (on ? 1 : -1)));
    _notify();
  }

  void setWant(String uid, String shopId, bool on) {
    on ? _wants.add('$uid|$shopId') : _wants.remove('$uid|$shopId');
    _notify();
  }

  /// Adds the user's comment, then the Drop's author replies a few
  /// seconds later so the thread feels alive.
  void addComment(String dropId, Comment comment) {
    _addComment(dropId, comment);
    final d = drop(dropId);
    if (d == null) return;
    late final Timer t;
    t = Timer(Duration(seconds: 3 + _rnd.nextInt(4)), () {
      _pendingReplies.remove(t);
      final author = _persona(d.userId);
      if (author == null) return;
      _addComment(
          dropId,
          _comment(author, dropId,
              'Thanks ${comment.userName.split(' ').first}! Cobain juga '
              '${d.menuItem ?? 'menu andalannya'} ya 🙌'));
      _notify();
    });
    _pendingReplies.add(t);
    _notify();
  }

  // ----------------------------------------------------------- simulation

  /// One step of "life". Public so tests can drive it without a timer.
  void step() {
    _ticks++;
    // Cheers trickle in, mostly on fresh posts.
    final hot = min(_drops.length, 6);
    for (var i = 0, n = 1 + _rnd.nextInt(3); i < n && hot > 0; i++) {
      final d = _drops[_rnd.nextInt(hot)];
      _update(d.id, (d) => _copy(d, cheers: d.cheersCount + 1 + _rnd.nextInt(3)));
    }
    if (_rnd.nextDouble() < 0.35 && hot > 0) {
      final d = _drops[_rnd.nextInt(hot)];
      _addComment(d.id, _comment(_pick(_personas), d.id, _pick(_comments)));
    }
    // People walk in and out of shops.
    final shop = _pick(_shops);
    final here = _presence.putIfAbsent(shop.id, () => []);
    if (here.isNotEmpty && _rnd.nextBool()) {
      here.removeAt(_rnd.nextInt(here.length));
    } else {
      final p = _pick(_personas);
      if (!here.contains(p)) here.insert(0, p);
    }
    if (_ticks % newDropEvery == 0) _publishNew();
    _notify();
  }

  void dispose() {
    _stop();
    for (final t in _pendingReplies) {
      t.cancel();
    }
    _changes.close();
  }

  void _start() =>
      _timer ??= Timer.periodic(tick, (_) => step());

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _seed() {
    const agesMin = [3, 12, 27, 49, 85, 150, 300, 560, 1220, 1830, 2900];
    final now = _now();
    for (final m in agesMin) {
      final at = now.subtract(Duration(minutes: m));
      final d = _newDrop(at, cheers: max(0, 140 - m ~/ 12 + _rnd.nextInt(60)));
      _drops.add(d);
      for (var i = 0, n = _rnd.nextInt(4); i < n; i++) {
        _addComment(
            d.id,
            _comment(_pick(_personas), d.id, _pick(_comments),
                at: at.add(Duration(minutes: 1 + i * 3))));
      }
      if (m <= 120) {
        final here = _presence.putIfAbsent(d.shopId, () => []);
        final p = _persona(d.userId)!;
        if (!here.contains(p)) here.add(p);
      }
    }
  }

  void _publishNew() {
    final d = _newDrop(_now());
    _drops.insert(0, d);
    if (_drops.length > 40) _commentsByDrop.remove(_drops.removeLast().id);
    final here = _presence.putIfAbsent(d.shopId, () => []);
    final p = _persona(d.userId)!;
    if (!here.contains(p)) here.insert(0, p);
  }

  Drop _newDrop(DateTime at, {int cheers = 0}) {
    final p = _pick(_personas);
    final s = _pick(_shops);
    final (item, price) = _pick(s.menu);
    final id = 'demo_d_${_seq++}';
    return Drop(
      id: id,
      userId: p.id,
      userHandle: p.handle,
      userPhotoUrl: p.photoUrl,
      userIsPass: p.isPass,
      shopId: s.id,
      shopName: s.name,
      shopVibe: s.vibe,
      photoUrls: [s.photos[_rnd.nextInt(s.photos.length)]],
      caption: _pick(_captions),
      menuItem: item,
      menuPrice: price,
      rating: 3 + _rnd.nextInt(3),
      vibe: s.vibe,
      stampNumber: 1 + _rnd.nextInt(30),
      isFirstAtShop: _rnd.nextDouble() < 0.1,
      cheersCount: cheers,
      commentCount: 0,
      createdAt: at,
      publishAt: at,
      distanceKm: s.distanceKm,
    );
  }

  Comment _comment(_Persona p, String dropId, String text, {DateTime? at}) =>
      Comment(
        id: 'demo_c_${_seq++}',
        shopId: '',
        userId: p.id,
        userName: p.handle,
        userPhotoUrl: p.photoUrl,
        text: text,
        createdAt: at ?? _now(),
      );

  void _addComment(String dropId, Comment c) {
    // Newest first, matching the Firestore query.
    _commentsByDrop.putIfAbsent(dropId, () => []).insert(0, c);
    _update(dropId, (d) => _copy(d, comments: d.commentCount + 1));
  }

  void _update(String id, Drop Function(Drop) f) {
    final i = _drops.indexWhere((d) => d.id == id);
    if (i >= 0) _drops[i] = f(_drops[i]);
  }

  T _pick<T>(List<T> xs) => xs[_rnd.nextInt(xs.length)];
  _Persona? _persona(String id) =>
      _personas.where((p) => p.id == id).firstOrNull;
  _Shop _shop(String id) => _shops.firstWhere((s) => s.id == id);
}

Drop _copy(Drop d, {int? cheers, int? comments}) => Drop(
      id: d.id,
      userId: d.userId,
      userHandle: d.userHandle,
      userPhotoUrl: d.userPhotoUrl,
      userIsPass: d.userIsPass,
      shopId: d.shopId,
      shopName: d.shopName,
      shopVibe: d.shopVibe,
      photoUrls: d.photoUrls,
      caption: d.caption,
      menuItem: d.menuItem,
      menuPrice: d.menuPrice,
      rating: d.rating,
      vibe: d.vibe,
      stampNumber: d.stampNumber,
      isFirstAtShop: d.isFirstAtShop,
      cheersCount: max(0, cheers ?? d.cheersCount),
      commentCount: comments ?? d.commentCount,
      createdAt: d.createdAt,
      publishAt: d.publishAt,
      distanceKm: d.distanceKm,
    );
