import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// WhatsApp-style emoji & sticker picker panel.
class KoraEmojiPanel extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final Function(String) onStickerSelected;
  final Function(String) onGifSelected;

  const KoraEmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onStickerSelected,
    required this.onGifSelected,
  });

  @override
  State<KoraEmojiPanel> createState() => _KoraEmojiPanelState();
}

enum _PanelTab { emoji, gif, stickers }

class _KoraEmojiPanelState extends State<KoraEmojiPanel>
    with SingleTickerProviderStateMixin {
  _PanelTab _activeTab = _PanelTab.emoji;
  late TabController _emojiCategoryController;

  static const _emojiCategories = [
    '😀','🐶','🍔','⚽','🚗','💡','❤️','🏁',
  ];

  final List<String> _recentEmojis = [];
  final List<KoraStickerPack> _stickerPacks = KoraStickerPack.builtIn;

  @override
  void initState() {
    super.initState();
    _emojiCategoryController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _emojiCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final isDark = brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.42,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildSearchBar(brightness, isDark),
          Expanded(child: _buildContent(brightness, isDark)),
          _buildBottomTabs(brightness, isDark),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Brightness brightness, bool isDark) {
    final searchBg = isDark ? const Color(0xFF1A2A35) : const Color(0xFFF0F0F0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: searchBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextField(
          style: TextStyle(color: KoraColors.textPrimaryFor(brightness), fontSize: 14),
          decoration: InputDecoration(
            hintText: _activeTab == _PanelTab.emoji
                ? 'Search emoji'
                : _activeTab == _PanelTab.stickers
                    ? 'Search stickers'
                    : 'Search GIFs',
            hintStyle: TextStyle(color: KoraColors.textMutedFor(brightness), fontSize: 14),
            prefixIcon: Icon(Icons.search, size: 20, color: KoraColors.textMutedFor(brightness)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Brightness brightness, bool isDark) {
    switch (_activeTab) {
      case _PanelTab.emoji:
        return _buildEmojiGrid(brightness, isDark);
      case _PanelTab.stickers:
        return _buildStickerGrid(brightness, isDark);
      case _PanelTab.gif:
        return _buildGifPlaceholder(brightness, isDark);
    }
  }

  Widget _buildEmojiGrid(Brightness brightness, bool isDark) {
    final emojis = _emojisForCategory(_emojiCategoryController.index);
    return Column(
      children: [
        if (_recentEmojis.isNotEmpty && _emojiCategoryController.index == 0)
          _buildRecentRow(brightness, isDark),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1,
              mainAxisSpacing: 2, crossAxisSpacing: 2,
            ),
            itemCount: emojis.length,
            itemBuilder: (ctx, i) {
              final emoji = emojis[i];
              return GestureDetector(
                onTap: () { widget.onEmojiSelected(emoji); _addToRecent(emoji); },
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
              );
            },
          ),
        ),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2A35) : const Color(0xFFF5F5F5),
            border: Border(top: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5)),
          ),
          child: TabBar(
            controller: _emojiCategoryController,
            tabs: _emojiCategories.map((e) => Tab(text: e)).toList(),
            labelColor: KoraColors.purple,
            unselectedLabelColor: KoraColors.textMutedFor(brightness),
            indicatorColor: KoraColors.purple,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 20),
            onTap: (i) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRow(Brightness brightness, bool isDark) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentEmojis.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => widget.onEmojiSelected(_recentEmojis[i]),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(_recentEmojis[i], style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerGrid(Brightness brightness, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _stickerPacks.length,
      itemBuilder: (ctx, packIdx) {
        final pack = _stickerPacks[packIdx];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: KoraColors.cardFor(brightness),
                  ),
                  child: Center(child: Text(pack.trayIcon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 8),
                Text(pack.name, style: TextStyle(
                  color: KoraColors.textPrimaryFor(brightness),
                  fontSize: 13, fontWeight: FontWeight.w600,
                )),
              ]),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, childAspectRatio: 1,
                mainAxisSpacing: 4, crossAxisSpacing: 4,
              ),
              itemCount: pack.stickers.length,
              itemBuilder: (ctx, i) {
                final sticker = pack.stickers[i];
                return GestureDetector(
                  onTap: () => widget.onStickerSelected(sticker),
                  child: Container(
                    decoration: BoxDecoration(
                      color: KoraColors.cardFor(brightness),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(sticker, style: const TextStyle(fontSize: 40))),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildGifPlaceholder(Brightness brightness, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gif_rounded, size: 48, color: KoraColors.textMutedFor(brightness)),
          const SizedBox(height: 8),
          Text('GIF search coming soon', style: TextStyle(
            color: KoraColors.textMutedFor(brightness), fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _buildBottomTabs(Brightness brightness, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2A35) : const Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTab(icon: Icons.emoji_emotions_outlined, isActive: _activeTab == _PanelTab.emoji,
            brightness: brightness, onTap: () => setState(() => _activeTab = _PanelTab.emoji)),
          _buildTab(icon: Icons.gif_rounded, isActive: _activeTab == _PanelTab.gif,
            brightness: brightness, onTap: () => setState(() => _activeTab = _PanelTab.gif)),
          _buildTab(icon: Icons.sticky_note_2_outlined, isActive: _activeTab == _PanelTab.stickers,
            brightness: brightness, onTap: () => setState(() => _activeTab = _PanelTab.stickers)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.keyboard_outlined, color: KoraColors.textMutedFor(brightness), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required IconData icon, required bool isActive,
    required Brightness brightness, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22,
              color: isActive ? KoraColors.purple : KoraColors.textMutedFor(brightness)),
            if (isActive) Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20, height: 2,
              decoration: BoxDecoration(color: KoraColors.purple, borderRadius: BorderRadius.circular(1)),
            ),
          ],
        ),
      ),
    );
  }

  void _addToRecent(String emoji) {
    setState(() {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 32) _recentEmojis.removeLast();
    });
  }

  List<String> _emojisForCategory(int index) {
    switch (index) {
      case 0: return _smileysPeople;
      case 1: return _animalsNature;
      case 2: return _foodDrink;
      case 3: return _activities;
      case 4: return _travelPlaces;
      case 5: return _objects;
      case 6: return _symbols;
      case 7: return _flags;
      default: return _smileysPeople;
    }
  }

  static const _smileysPeople = [
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊',
    '😇','🥰','😍','🤩','😘','😗','😚','😙','😋','😛','😜','🤪',
    '😝','🤗','🤭','🤫','🤔','🤐','🤨','😐','😑','😶','😏','😒',
    '🙄','😬','🤥','😌','😔','😪','🤤','😴','😷','🤒','🤕','🤢',
    '🤧','🥵','🥶','😎','🤓','🧐','😕','😟','🙁','😮','😯','😲',
    '😳','🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖','😣',
    '😞','😓','😩','😫','🥱','😤','😡','😠','🤬','😈','👿','💀',
    '💩','🤡','👹','👺','👻','👽','🤖','🥳','👋','🤚','🖐️','✋',
    '🖖','👌','🤏','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇',
    '☝️','👍','👎','✊','👊','🤛','🤜','👏','🙌','👐','🤲','🤝',
    '🙏','💪','👀','👁️','👅','👄','💋','🧠','🫀','🫁','🦷','🦴',
  ];

  static const _animalsNature = [
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮',
    '🐷','🐸','🐵','🙈','🙉','🙊','🐒','🐔','🐧','🐦','🐤','🦆',
    '🦅','🦉','🦇','🐺','🐗','🐴','🦄','🐝','🐛','🦋','🐌','🐞',
    '🐜','🦟','🦗','🕷️','🦂','🐢','🐍','🦎','🦖','🦕','🐙','🦑',
    '🦐','🦞','🦀','🐡','🐠','🐟','🐬','🐳','🐋','🦈','🐊','🐅',
    '🐆','🦓','🦍','🦧','🐘','🦛','🦏','🐪','🐫','🦒','🦘','🐃',
    '🐂','🐄','🐎','🐖','🐏','🐑','🦙','🐐','🦌','🐕','🐩','🦮',
    '🐈','🐓','🦃','🦚','🦜','🦢','🦩','🕊️','🐇','🦝','🦨','🦡',
    '🌵','🎄','🌲','🌳','🌴','🌱','🌿','☘️','🍀','🍁','🍂','🍃',
    '🍄','🐚','🌾','💐','🌷','🌹','🥀','🌺','🌸','🌼','🌻','🌞',
  ];

  static const _foodDrink = [
    '🍏','🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍈','🍒',
    '🍑','🥭','🍍','🥥','🥝','🍅','🍆','🥑','🥦','🥬','🥒','🌶️',
    '🫑','🌽','🥕','🫒','🧄','🧅','🥔','🍠','🥐','🥯','🍞','🥖',
    '🥨','🧀','🥚','🍳','🧈','🥞','🧇','🥓','🥩','🍗','🍖','🌭',
    '🍔','🍟','🍕','🥪','🥙','🧆','🌮','🌯','🫔','🥗','🥘','🍝',
    '🍜','🍲','🍛','🍣','🍱','🥟','🦪','🍤','🍙','🍚','🍘','🍥',
    '🥠','🥮','🍢','🍡','🍧','🍨','🍦','🥧','🧁','🍰','🎂','🍮',
    '🍭','🍬','🍫','🍿','🍩','🍪','🌰','🥜','🍯','🥛','🍼','☕',
    '🍵','🫖','🥤','🧋','🍶','🍺','🍻','🥂','🍷','🥃','🍸','🍹',
  ];

  static const _activities = [
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱','🪀','🏓',
    '🏸','🏒','🏑','🥍','🏏','🥅','⛳','🪁','🏹','🎣','🤿','🥊',
    '🥋','🎽','🛹','🛼','🛷','⛸️','🥌','🎿','⛷️','🏂','🪂','🏆',
    '🥇','🥈','🥉','🏅','🎖️','🏵️','🎗️','🎫','🎟️','🎪','🤹','🎭',
    '🩰','🎨','🎬','🎤','🎧','🎼','🎵','🎶','🪘','🥁','🎷','🎺',
    '🎸','🪕','🎻','🎲','♟️','🎯','🎳','🎮','🕹️','🧩','🃏','🀄',
  ];

  static const _travelPlaces = [
    '🚗','🚕','🚙','🚌','🚎','🏎️','🚓','🚑','🚒','🚐','🛻','🚚',
    '🚛','🚜','🦯','🦽','🦼','🛴','🚲','🛵','🏍️','🛺','🚨','🚔',
    '🚍','🚘','🚖','🚡','🚠','🚟','🚃','🚋','🚞','🚝','🚄','🚅',
    '🚈','🚂','🚆','🚇','🚊','🚉','✈️','🛫','🛬','🛩️','💺','🛰️',
    '🚀','🛸','🚁','🛶','⛵','🚤','🛥️','🛳️','⛴️','🚢','⚓','🗺️',
    '🗿','🗽','🗼','🏰','🏯','🏟️','🎡','🎢','🎠','⛲','⛱️','🏖️',
    '🏝️','🏜️','🌋','⛰️','🏔️','🗻','🏕️','⛺','🛖','🏠','🏡','🏘️',
    '🏚️','🏗️','🏭','🏢','🏬','🏣','🏤','🏥','🏦','🏨','🏪','🏫',
  ];

  static const _objects = [
    '⌚','📱','💻','⌨️','🖥️','🖨️','🖱️','💽','💾','💿','📀','📷',
    '📸','📹','🎥','📽️','🎞️','📞','☎️','📟','📠','📺','📻','🎙️',
    '⏱️','⏲️','⏰','🕰️','⌛','⏳','📡','🔋','🔌','💡','🔦','🕯️',
    '🗑️','🛢️','💸','💵','💴','💶','💷','💰','💳','💎','⚖️','🧰',
    '🔧','🔨','⚒️','🛠️','⛏️','🧲','🔫','💣','🧨','🪓','🔪','🗡️',
    '⚔️','🛡️','🚬','⚰️','⚱️','🏺','🔮','📿','🧿','💈','⚗️','🔭',
    '🔬','🩺','💊','🩹','🩸','🧬','🦠','🧫','🧪','🌡️','🧹','🧺',
  ];

  static const _symbols = [
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️','💕',
    '💞','💓','💗','💖','💘','💝','💟','♥️','💌','💤','💢','💥',
    '💫','💦','💨','🕳️','💣','💬','🗨️','🗯️','💭','✔️','✖️','❌',
    '❎','✅','☑️','🔘','🔴','🟠','🟡','🟢','🔵','🟣','⚫','⚪',
    '🟤','🔺','🔻','🔸','🔹','🔶','🔷','🔳','🔲','▪️','▫️','◾',
    '◽','◼️','◻️','🟥','🟧','🟨','🟩','🟦','🟪','⬛','⬜','🟫',
    '🔔','🔕','➕','➖','➗','✖️','♾️','💲','💱','〰️','➰','➿',
    '🔚','🔙','🔛','🔝','🔜','❓','❗','❕','❔','‼️','⁉️','🔱',
  ];

  static const _flags = [
    '🏁','🚩','🎌','🏴','🏳️','🏳️‍🌈','🏳️‍⚧️','🏴‍☠️',
    '🇺🇸','🇬🇧','🇨🇦','🇦🇺','🇳🇬','🇰🇪','🇿🇦','🇬🇭',
    '🇧🇷','🇲🇽','🇯🇵','🇨🇳','🇮🇳','🇩🇪','🇫🇷','🇮🇹',
    '🇪🇸','🇵🇹','🇳🇱','🇧🇪','🇨🇭','🇦🇹','🇸🇪','🇳🇴',
    '🇩🇰','🇫🇮','🇮🇸','🇮🇪','🇵🇱','🇷🇺','🇺🇦','🇹🇷',
    '🇬🇷','🇪🇬','🇲🇦','🇸🇦','🇦🇪','🇶🇦','🇰🇼','🇮🇶',
    '🇮🇷','🇵🇰','🇮🇩','🇲🇾','🇸🇬','🇵🇭','🇹🇭','🇻🇳',
    '🇰🇷','🇹🇼','🇭🇰','🇳🇿','🇦🇷','🇨🇱','🇨🇴','🇵🇪',
  ];
}

/// A sticker pack — mirrors WhatsApp's WAStickerApps format.
class KoraStickerPack {
  final String name;
  final String publisher;
  final String trayIcon;
  final List<String> stickers;

  const KoraStickerPack({
    required this.name,
    required this.publisher,
    required this.trayIcon,
    required this.stickers,
  });

  static const builtIn = [
    KoraStickerPack(
      name: 'Kora Originals', publisher: 'Kora', trayIcon: '🟣',
      stickers: ['😀','😂','🥰','😎','🤔','😱','🥳','😭','😡','😴','🤯','🤗','🤫','🥺','😏','🤓'],
    ),
    KoraStickerPack(
      name: 'Hearts', publisher: 'Kora', trayIcon: '❤️',
      stickers: ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','💕','💞','💓','💗','💖','💘','💝'],
    ),
    KoraStickerPack(
      name: 'Animals', publisher: 'Kora', trayIcon: '🐶',
      stickers: ['🐶','🐱','🦊','🐻','🐼','🐨','🦁','🐯','🐸','🐵','🦄','🐙','🦋','🐝','🦉','🐺'],
    ),
  ];
}
