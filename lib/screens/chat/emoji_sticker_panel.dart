import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kora_colors.dart';

// ── Emoji keyword index for working search ──
const _emojiKeywords = <String, List<String>>{
  '😀': ['face', 'smile', 'happy', 'grin', 'joy', 'laugh'],
  '😃': ['face', 'smile', 'happy', 'joy'],
  '😄': ['face', 'smile', 'happy', 'joy', 'grin'],
  '😁': ['face', 'grin', 'smile', 'happy', 'teeth'],
  '😆': ['face', 'laugh', 'grin', 'squint'],
  '😅': ['face', 'sweat', 'smile', 'laugh', 'relief'],
  '🤣': ['face', 'laugh', 'rolling', 'floor', 'rofl'],
  '😂': ['face', 'laugh', 'tears', 'joy', 'cry'],
  '🙂': ['face', 'smile', 'slight'],
  '🙃': ['face', 'smile', 'upside', 'down', 'sarcastic'],
  '😉': ['face', 'wink', 'smile'],
  '😊': ['face', 'smile', 'blush', 'happy', 'shy'],
  '😇': ['face', 'angel', 'halo', 'innocent'],
  '🥰': ['face', 'love', 'hearts', 'smitten', 'adore'],
  '😍': ['face', 'love', 'heart', 'eyes', 'smile'],
  '🤩': ['face', 'star', 'struck', 'excited', 'eyes'],
  '😘': ['face', 'kiss', 'heart', 'love'],
  '😗': ['face', 'kiss', 'lips'],
  '😚': ['face', 'kiss', 'closed', 'eyes', 'love'],
  '😙': ['face', 'kiss', 'smile'],
  '🥲': ['face', 'tear', 'smile', 'happy', 'sad'],
  '😋': ['face', 'tongue', 'yum', 'delicious', 'taste'],
  '😛': ['face', 'tongue', 'out'],
  '😜': ['face', 'wink', 'tongue', 'crazy'],
  '🤪': ['face', 'crazy', 'zany', 'tongue'],
  '🤨': ['face', 'raised', 'eyebrow', 'skeptical'],
  '🧐': ['face', 'monocle', 'inspect', 'curious'],
  '🤓': ['face', 'nerd', 'glasses', 'smart'],
  '😎': ['face', 'cool', 'sunglasses', 'smile'],
  '🥸': ['face', 'disguise', 'nose', 'glasses'],
  '🥳': ['face', 'party', 'celebrate', 'hat', 'birthday'],
  '😏': ['face', 'smirk', 'smug'],
  '😒': ['face', 'unamused', 'annoyed', 'meh'],
  '😞': ['face', 'sad', 'disappointed'],
  '😔': ['face', 'sad', 'pensive', 'thoughtful'],
  '😟': ['face', 'worried', 'sad', 'concerned'],
  '😕': ['face', 'confused', 'unsure'],
  '🙁': ['face', 'frown', 'slight', 'sad'],
  '☹️': ['face', 'frown', 'sad'],
  '😣': ['face', 'persevere', 'struggle'],
  '😖': ['face', 'confounded', 'struggle', 'frustrated'],
  '😫': ['face', 'tired', 'weary'],
  '😩': ['face', 'weary', 'tired', 'exhausted'],
  '🥺': ['face', 'pleading', 'puppy', 'eyes', 'beg'],
  '😢': ['face', 'cry', 'tear', 'sad'],
  '😭': ['face', 'cry', 'loud', 'tears', 'sob'],
  '😤': ['face', 'huff', 'angry', 'frustrated'],
  '😠': ['face', 'angry', 'mad'],
  '😡': ['face', 'angry', 'rage', 'mad', 'red'],
  '🤬': ['face', 'swearing', 'angry', 'curse'],
  '🤯': ['face', 'mind', 'blown', 'shocked', 'exploding'],
  '😱': ['face', 'scream', 'fear', 'shock'],
  '😨': ['face', 'fearful', 'scared', 'worried'],
  '😰': ['face', 'anxious', 'sweat', 'nervous'],
  '😥': ['face', 'sad', 'relieved', 'sweat'],
  '😓': ['face', 'sweat', 'stress', 'worried'],
  '🤗': ['face', 'hug', 'hugging', 'love'],
  '🤔': ['face', 'think', 'thinking', 'wonder'],
  '🤫': ['face', 'shh', 'quiet', 'silent', 'secret'],
  '🤥': ['face', 'lie', 'pinocchio', 'nose'],
  '😶': ['face', 'mute', 'silent', 'no', 'mouth'],
  '😐': ['face', 'neutral', 'expressionless'],
  '😑': ['face', 'expressionless', 'deadpan'],
  '😬': ['face', 'grimace', 'teeth', 'awkward'],
  '🙄': ['face', 'eye', 'roll', 'annoyed'],
  '😯': ['face', 'hushed', 'surprised', 'shock'],
  '😦': ['face', 'frown', 'open', 'mouth'],
  '😧': ['face', 'anguished', 'sad'],
  '😮': ['face', 'gasp', 'surprised', 'wow'],
  '😲': ['face', 'astonished', 'shock', 'surprised'],
  '🥱': ['face', 'yawn', 'tired', 'bored'],
  '😴': ['face', 'sleep', 'zzz', 'tired'],
  '🤤': ['face', 'drool', 'sleep', 'tired'],
  '😪': ['face', 'sleepy', 'tired', 'sad'],
  '😵': ['face', 'dizzy', 'dazed', 'confused'],
  '🤒': ['face', 'sick', 'thermometer', 'ill'],
  '🤕': ['face', 'injured', 'bandage', 'hurt'],
  '🤢': ['face', 'nauseated', 'sick', 'green', 'vomit'],
  '🤮': ['face', 'vomit', 'sick', 'disgust'],
  '🤧': ['face', 'sneeze', 'sick', 'cold', 'tissue'],
  '🥵': ['face', 'hot', 'sweat', 'heat'],
  '🥶': ['face', 'cold', 'freezing', 'blue'],
  '🥴': ['face', 'woozy', 'dizzy', 'drunk'],
  '🤠': ['face', 'cowboy', 'hat', 'western'],
  '💀': ['skull', 'death', 'dead'],
  '👻': ['ghost', 'spooky', 'halloween'],
  '👽': ['alien', 'ufo', 'space'],
  '🤖': ['robot', 'ai', 'machine'],
  '🎃': ['pumpkin', 'halloween'],
  '😺': ['cat', 'face', 'smile', 'happy'],
  '😸': ['cat', 'face', 'grin', 'smile'],
  '😹': ['cat', 'face', 'joy', 'tears', 'laugh'],
  '😻': ['cat', 'face', 'love', 'heart', 'eyes'],
  '😼': ['cat', 'face', 'wry', 'smile'],
  '😽': ['cat', 'face', 'kiss', 'closed', 'eyes'],
  '🙀': ['cat', 'face', 'scream', 'shock', 'weary'],
  '😿': ['cat', 'face', 'cry', 'sad', 'tears'],
  '😾': ['cat', 'face', 'pouting', 'angry'],
  '❤️': ['heart', 'love', 'red', 'romance'],
  '🧡': ['heart', 'orange', 'love'],
  '💛': ['heart', 'yellow', 'love'],
  '💚': ['heart', 'green', 'love'],
  '💙': ['heart', 'blue', 'love'],
  '💜': ['heart', 'purple', 'love'],
  '🖤': ['heart', 'black', 'love'],
  '🤍': ['heart', 'white', 'love'],
  '🤎': ['heart', 'brown', 'love'],
  '💔': ['heart', 'broken', 'break', 'sad'],
  '❣️': ['heart', 'exclamation', 'love'],
  '💕': ['hearts', 'two', 'love'],
  '💞': ['hearts', 'revolving', 'love'],
  '💓': ['heart', 'beating', 'pulse', 'love'],
  '💗': ['heart', 'growing', 'love'],
  '💖': ['heart', 'sparkling', 'love'],
  '💘': ['heart', 'arrow', 'cupid', 'love'],
  '💝': ['heart', 'ribbon', 'gift', 'love'],
  '💟': ['heart', 'decoration', 'love'],
  '👍': ['thumbs', 'up', 'like', 'yes', 'good'],
  '👎': ['thumbs', 'down', 'dislike', 'no', 'bad'],
  '👌': ['ok', 'okay', 'good', 'perfect', 'hand'],
  '🤌': ['pinched', 'fingers', 'italian', 'hand'],
  '🤏': ['pinching', 'hand', 'small', 'little'],
  '✌️': ['peace', 'victory', 'hand', 'two'],
  '🤞': ['fingers', 'crossed', 'luck', 'hand'],
  '🤟': ['love', 'you', 'hand', 'fingers'],
  '🤘': ['rock', 'on', 'hand', 'horns'],
  '🤙': ['call', 'me', 'hand', 'shaka'],
  '👈': ['point', 'left', 'hand', 'index'],
  '👉': ['point', 'right', 'hand', 'index'],
  '👆': ['point', 'up', 'hand', 'index'],
  '👇': ['point', 'down', 'hand', 'index'],
  '☝️': ['point', 'up', 'one', 'hand'],
  '👋': ['wave', 'hello', 'goodbye', 'hand'],
  '🤚': ['raised', 'back', 'hand', 'stop'],
  '🖐️': ['hand', 'fingers', 'five', 'stop'],
  '✋': ['hand', 'stop', 'raised'],
  '🖖': ['vulcan', 'salute', 'spock', 'hand'],
  '👏': ['clap', 'applause', 'hands', 'praise'],
  '🙌': ['hands', 'up', 'celebrate', 'praise'],
  '🤝': ['handshake', 'deal', 'agreement'],
  '🙏': ['pray', 'thanks', 'please', 'hands'],
  '✍️': ['write', 'writing', 'hand', 'pen'],
  '💪': ['muscle', 'strong', 'arm', 'flex'],
  '👀': ['eyes', 'look', 'see', 'watch'],
  '👁️': ['eye', 'look', 'see'],
  '👅': ['tongue', 'taste'],
  '👄': ['mouth', 'lips'],
  '🧠': ['brain', 'smart', 'mind'],
  '🐶': ['dog', 'puppy', 'pet', 'animal'],
  '🐱': ['cat', 'kitten', 'pet', 'animal'],
  '🐭': ['mouse', 'rat', 'animal'],
  '🐹': ['hamster', 'pet', 'animal'],
  '🐰': ['rabbit', 'bunny', 'pet', 'animal'],
  '🦊': ['fox', 'animal'],
  '🐻': ['bear', 'animal'],
  '🐼': ['panda', 'bear', 'animal'],
  '🐨': ['koala', 'animal'],
  '🐯': ['tiger', 'animal', 'cat'],
  '🦁': ['lion', 'animal', 'cat'],
  '🐮': ['cow', 'animal'],
  '🐷': ['pig', 'animal'],
  '🐸': ['frog', 'animal'],
  '🐵': ['monkey', 'animal'],
  '🐔': ['chicken', 'bird', 'animal'],
  '🐧': ['penguin', 'bird', 'animal'],
  '🐦': ['bird', 'animal'],
  '🦆': ['duck', 'bird', 'animal'],
  '🦅': ['eagle', 'bird', 'animal'],
  '🦉': ['owl', 'bird', 'animal'],
  '🦋': ['butterfly', 'insect', 'animal'],
  '🐝': ['bee', 'insect', 'animal'],
  '🦄': ['unicorn', 'horse', 'animal', 'mythical'],
  '🐴': ['horse', 'animal'],
  '🦓': ['zebra', 'animal'],
  '🦒': ['giraffe', 'animal'],
  '🐘': ['elephant', 'animal'],
  '🐊': ['crocodile', 'alligator', 'reptile'],
  '🐢': ['turtle', 'tortoise', 'reptile'],
  '🐍': ['snake', 'serpent', 'reptile'],
  '🐲': ['dragon', 'mythical', 'reptile'],
  '🐙': ['octopus', 'sea', 'animal'],
  '🐳': ['whale', 'sea', 'mammal'],
  '🐬': ['dolphin', 'sea', 'mammal'],
  '🦈': ['shark', 'sea', 'fish'],
  '🐟': ['fish', 'sea'],
  '🍔': ['burger', 'hamburger', 'food'],
  '🍟': ['fries', 'chips', 'food'],
  '🍕': ['pizza', 'food', 'slice'],
  '🌭': ['hotdog', 'hot', 'dog', 'food'],
  '🥪': ['sandwich', 'food'],
  '🌮': ['taco', 'food', 'mexican'],
  '🌯': ['burrito', 'food', 'mexican'],
  '🥗': ['salad', 'food', 'healthy'],
  '🍝': ['pasta', 'noodle', 'food', 'italian'],
  '🍜': ['noodle', 'ramen', 'food'],
  '🍲': ['pot', 'stew', 'food', 'soup'],
  '🍛': ['curry', 'rice', 'food', 'indian'],
  '🍣': ['sushi', 'food', 'japanese'],
  '🍱': ['bento', 'food', 'japanese', 'lunch'],
  '🍙': ['rice', 'ball', 'food', 'japanese'],
  '🍚': ['rice', 'food', 'bowl'],
  '🍦': ['ice', 'cream', 'dessert', 'food'],
  '🍩': ['donut', 'doughnut', 'dessert', 'food'],
  '🍪': ['cookie', 'dessert', 'food'],
  '🎂': ['cake', 'birthday', 'dessert'],
  '🍰': ['cake', 'slice', 'dessert'],
  '🧁': ['cupcake', 'dessert', 'muffin'],
  '🍫': ['chocolate', 'candy', 'food'],
  '🍬': ['candy', 'sweet', 'food'],
  '🍭': ['lollipop', 'candy', 'sweet'],
  '☕': ['coffee', 'drink', 'hot'],
  '🍵': ['tea', 'drink', 'green'],
  '🍺': ['beer', 'drink', 'alcohol', 'mug'],
  '🍻': ['beers', 'drink', 'alcohol', 'cheers'],
  '🍷': ['wine', 'drink', 'alcohol', 'glass'],
  '🥃': ['whiskey', 'drink', 'alcohol', 'glass'],
  '🍸': ['cocktail', 'drink', 'alcohol', 'martini'],
  '🍹': ['tropical', 'drink', 'cocktail', 'juice'],
  '🥤': ['cup', 'straw', 'drink', 'soda'],
  '🧋': ['boba', 'milk', 'tea', 'drink'],
  '⚽': ['soccer', 'football', 'ball', 'sport'],
  '🏀': ['basketball', 'ball', 'sport'],
  '🏈': ['football', 'american', 'ball', 'sport'],
  '⚾': ['baseball', 'ball', 'sport'],
  '🎾': ['tennis', 'ball', 'sport'],
  '🏐': ['volleyball', 'ball', 'sport'],
  '🏓': ['ping', 'pong', 'table', 'tennis', 'sport'],
  '🏸': ['badminton', 'sport', 'racket'],
  '⛳': ['golf', 'sport', 'flag'],
  '🏹': ['bow', 'arrow', 'archery', 'sport'],
  '🎣': ['fishing', 'fish', 'pole', 'sport'],
  '🥊': ['boxing', 'glove', 'sport'],
  '🥋': ['martial', 'arts', 'judo', 'uniform'],
  '⛸️': ['ice', 'skate', 'sport'],
  '🏂': ['snowboard', 'sport', 'snow'],
  '🏆': ['trophy', 'win', 'champion', 'award'],
  '🥇': ['gold', 'medal', 'first', 'winner'],
  '🥈': ['silver', 'medal', 'second'],
  '🥉': ['bronze', 'medal', 'third'],
  '🏅': ['medal', 'award', 'sport'],
  '🎮': ['game', 'gaming', 'controller', 'video'],
  '🕹️': ['joystick', 'game', 'arcade'],
  '🎲': ['dice', 'game', 'random'],
  '🎯': ['dart', 'target', 'bullseye', 'game'],
  '🎳': ['bowling', 'game', 'sport'],
  '🎨': ['art', 'paint', 'palette', 'color'],
  '🎬': ['movie', 'film', 'clapper', 'cinema'],
  '🎤': ['microphone', 'mic', 'sing', 'karaoke'],
  '🎧': ['headphone', 'music', 'audio', 'listen'],
  '🎵': ['music', 'note', 'song'],
  '🎶': ['music', 'notes', 'song', 'melody'],
  '🎸': ['guitar', 'music', 'rock'],
  '🎹': ['piano', 'keyboard', 'music'],
  '🥁': ['drum', 'music', 'beat'],
  '🎺': ['trumpet', 'music', 'horn'],
  '🎷': ['saxophone', 'sax', 'music', 'jazz'],
  '🚗': ['car', 'vehicle', 'drive'],
  '🚕': ['taxi', 'cab', 'car'],
  '🚙': ['suv', 'car', 'vehicle'],
  '🚌': ['bus', 'vehicle', 'transport'],
  '🚑': ['ambulance', 'vehicle', 'medical'],
  '🚒': ['fire', 'truck', 'engine', 'vehicle'],
  '🚲': ['bicycle', 'bike', 'cycle'],
  '🛵': ['scooter', 'moped', 'vehicle'],
  '🏍️': ['motorcycle', 'bike', 'vehicle'],
  '✈️': ['plane', 'airplane', 'flight', 'travel'],
  '🚀': ['rocket', 'space', 'launch'],
  '🚁': ['helicopter', 'chopper', 'vehicle'],
  '⛵': ['sailboat', 'boat', 'ship', 'sea'],
  '🚢': ['ship', 'boat', 'cruise', 'sea'],
  '🚆': ['train', 'railway', 'transport'],
  '🚄': ['train', 'bullet', 'fast', 'rail'],
  '🏠': ['house', 'home', 'building'],
  '🏡': ['house', 'home', 'garden'],
  '🏢': ['office', 'building', 'work'],
  '🏫': ['school', 'building', 'education'],
  '🏥': ['hospital', 'medical', 'building', 'health'],
  '🏦': ['bank', 'building', 'money'],
  '🏪': ['store', 'shop', 'convenience'],
  '🏰': ['castle', 'fortress', 'building'],
  '🗼': ['tower', 'tokyo', 'building'],
  '🗽': ['statue', 'liberty', 'monument'],
  '🎡': ['ferris', 'wheel', 'amusement'],
  '🎢': ['roller', 'coaster', 'amusement', 'ride'],
  '🌋': ['volcano', 'mountain', 'eruption'],
  '🏔️': ['mountain', 'snow', 'peak'],
  '🏖️': ['beach', 'sand', 'summer', 'umbrella'],
  '🏝️': ['island', 'desert', 'tropical'],
  '🌙': ['moon', 'crescent', 'night'],
  '⭐': ['star', 'night', 'space'],
  '✨': ['sparkles', 'shine', 'stars'],
  '⚡': ['lightning', 'bolt', 'electric', 'fast'],
  '🌈': ['rainbow', 'color', 'pride'],
  '☀️': ['sun', 'sunny', 'weather', 'hot'],
  '☁️': ['cloud', 'weather'],
  '🌧️': ['rain', 'weather', 'cloud'],
  '⛈️': ['storm', 'thunder', 'weather'],
  '❄️': ['snow', 'cold', 'weather', 'flake'],
  '💧': ['drop', 'water', 'droplet'],
  '🔥': ['fire', 'flame', 'hot', 'lit'],
  '🌍': ['earth', 'world', 'globe', 'planet'],
  '💬': ['speech', 'bubble', 'chat', 'talk', 'message'],
  '💭': ['thought', 'bubble', 'thinking'],
  '✔️': ['check', 'mark', 'done', 'yes'],
  '✖️': ['cross', 'mark', 'x', 'no', 'cancel'],
  '❌': ['cross', 'mark', 'x', 'no', 'wrong'],
  '✅': ['check', 'mark', 'button', 'done', 'yes'],
  '❓': ['question', 'mark', 'what', 'ask'],
  '❗': ['exclamation', 'mark', 'attention', 'alert'],
  '💯': ['hundred', '100', 'percent', 'perfect'],
  '🔔': ['bell', 'notification', 'alert', 'ring'],
  '🔕': ['bell', 'mute', 'silent', 'off'],
  '➕': ['plus', 'add', 'math'],
  '➖': ['minus', 'subtract', 'math'],
  '➗': ['divide', 'division', 'math'],
  '💲': ['dollar', 'money', 'currency'],
  '♻️': ['recycle', 'recycling', 'green', 'eco'],
  '⚠️': ['warning', 'alert', 'caution', 'sign'],
  '🚫': ['prohibited', 'no', 'forbidden', 'ban'],
  '🏁': ['checkered', 'flag', 'finish', 'race'],
  '🚩': ['flag', 'red', 'triangular'],
  '📱': ['phone', 'mobile', 'smartphone', 'cell'],
  '💻': ['laptop', 'computer', 'notebook'],
  '⌨️': ['keyboard', 'type', 'computer'],
  '🖱️': ['mouse', 'computer', 'click'],
  '💾': ['floppy', 'disk', 'save', 'retro'],
  '📷': ['camera', 'photo', 'picture'],
  '📸': ['camera', 'flash', 'photo'],
  '📹': ['video', 'camera', 'record'],
  '📺': ['tv', 'television', 'screen'],
  '⏰': ['alarm', 'clock', 'time', 'wake'],
  '⏳': ['hourglass', 'time', 'sand', 'waiting'],
  '💡': ['light', 'bulb', 'idea', 'lamp'],
  '🔦': ['flashlight', 'torch', 'light'],
  '🔋': ['battery', 'power', 'charge', 'energy'],
  '🔌': ['plug', 'power', 'charge', 'electric'],
  '🔑': ['key', 'lock', 'unlock'],
  '🔒': ['lock', 'secure', 'closed', 'padlock'],
  '🔓': ['unlock', 'lock', 'open'],
  '💰': ['money', 'bag', 'cash', 'wealth'],
  '💳': ['credit', 'card', 'payment', 'bank'],
  '💎': ['diamond', 'gem', 'jewel', 'crystal'],
  '🎁': ['gift', 'present', 'box', 'birthday'],
  '🎈': ['balloon', 'party', 'celebration'],
  '🎉': ['party', 'celebrate', 'confetti', 'tada'],
  '🎊': ['confetti', 'celebrate', 'party'],
  '📖': ['book', 'read', 'open'],
  '📚': ['books', 'library', 'read', 'study'],
  '📝': ['write', 'note', 'memo', 'pencil'],
  '✏️': ['pencil', 'write', 'draw'],
  '✂️': ['scissors', 'cut'],
  '🔍': ['search', 'magnifying', 'glass', 'find'],
  '🕯️': ['candle', 'light', 'wax'],
  '💣': ['bomb', 'explosion', 'explode'],
  '🔫': ['water', 'pistol', 'gun', 'toy'],
  '🛡️': ['shield', 'protect', 'defense'],
  '⚔️': ['swords', 'crossed', 'battle', 'fight'],
  '🇳🇬': ['nigeria', 'flag', 'naija', 'africa'],
  '🇺🇸': ['usa', 'flag', 'america', 'united', 'states'],
  '🇬🇧': ['uk', 'flag', 'britain', 'united', 'kingdom'],
  '🇨🇦': ['canada', 'flag', 'canadian'],
  '🇬🇭': ['ghana', 'flag', 'africa'],
  '🇰🇪': ['kenya', 'flag', 'africa'],
  '🇿🇦': ['south', 'africa', 'flag'],
  '🇧🇷': ['brazil', 'flag', 'brasil'],
  '🇲🇽': ['mexico', 'flag', 'mexican'],
  '🇯🇵': ['japan', 'flag', 'japanese'],
  '🇨🇳': ['china', 'flag', 'chinese'],
  '🇮🇳': ['india', 'flag', 'indian'],
  '🇩🇪': ['germany', 'flag', 'german'],
  '🇫🇷': ['france', 'flag', 'french'],
  '🇮🇹': ['italy', 'flag', 'italian'],
  '🇪🇸': ['spain', 'flag', 'spanish'],
  '🇷🇺': ['russia', 'flag', 'russian'],
  '🇦🇪': ['uae', 'emirates', 'flag', 'dubai'],
  '🇸🇦': ['saudi', 'arabia', 'flag'],
};

/// WhatsApp-style emoji & sticker picker panel.
/// Fully functional — working search, persistent recent emojis,
/// sticker pack browsing with pack store, no placeholder tabs.
class KoraEmojiPanel extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final Function(String) onStickerSelected;

  const KoraEmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onStickerSelected,
  });

  @override
  State<KoraEmojiPanel> createState() => _KoraEmojiPanelState();
}

enum _PanelTab { emoji, stickers }

class _KoraEmojiPanelState extends State<KoraEmojiPanel>
    with SingleTickerProviderStateMixin {
  _PanelTab _activeTab = _PanelTab.emoji;
  late TabController _emojiCategoryController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _searchResults = [];
  bool _isSearching = false;

  final List<String> _recentEmojis = [];
  static const _recentKey = 'kora_recent_emojis';

  int _activeStickerPack = 0;
  final List<KoraStickerPack> _installedPacks = List.from(KoraStickerPack.builtIn);

  @override
  void initState() {
    super.initState();
    _emojiCategoryController = TabController(length: 8, vsync: this);
    _emojiCategoryController.addListener(() {
      if (_emojiCategoryController.indexIsChanging) {
        _searchController.clear();
        _searchQuery = '';
        _isSearching = false;
        setState(() {});
      }
    });
    _loadRecentEmojis();
  }

  @override
  void dispose() {
    _emojiCategoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentKey) ?? [];
    if (mounted) setState(() => _recentEmojis.addAll(stored));
  }

  Future<void> _addToRecent(String emoji) async {
    _recentEmojis.remove(emoji);
    _recentEmojis.insert(0, emoji);
    if (_recentEmojis.length > 32) _recentEmojis.removeLast();
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(_recentKey, _recentEmojis);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        final q = query.toLowerCase();
        _searchResults = _emojiKeywords.entries
            .where((e) {
              for (final kw in e.value) {
                if (kw.contains(q)) return true;
              }
              return e.key.toLowerCase().contains(q);
            })
            .map((e) => e.key)
            .toList();
      }
    });
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
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: TextStyle(color: KoraColors.textPrimaryFor(brightness), fontSize: 14),
          decoration: InputDecoration(
            hintText: _activeTab == _PanelTab.emoji ? 'Search emoji' : 'Search stickers',
            hintStyle: TextStyle(color: KoraColors.textMutedFor(brightness), fontSize: 14),
            prefixIcon: Icon(Icons.search, size: 20, color: KoraColors.textMutedFor(brightness)),
            suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 18, color: KoraColors.textMutedFor(brightness)),
                  onPressed: () { _searchController.clear(); _onSearchChanged(''); },
                )
              : null,
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
        return _isSearching
          ? _buildSearchResults(brightness, isDark)
          : _buildEmojiGrid(brightness, isDark);
      case _PanelTab.stickers:
        return _buildStickerContent(brightness, isDark);
    }
  }

  Widget _buildSearchResults(Brightness brightness, bool isDark) {
    if (_searchResults.isEmpty) {
      return Center(child: Text('No emojis found',
        style: TextStyle(color: KoraColors.textMutedFor(brightness), fontSize: 14)));
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, childAspectRatio: 1, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final emoji = _searchResults[i];
        return GestureDetector(
          onTap: () { widget.onEmojiSelected(emoji); _addToRecent(emoji); },
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        );
      },
    );
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
              crossAxisCount: 7, childAspectRatio: 1, mainAxisSpacing: 2, crossAxisSpacing: 2),
            itemCount: emojis.length,
            itemBuilder: (ctx, i) {
              final emoji = emojis[i];
              return GestureDetector(
                onTap: () { widget.onEmojiSelected(emoji); _addToRecent(emoji); setState(() {}); },
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text('Recent', style: TextStyle(
              color: KoraColors.textMutedFor(brightness), fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentEmojis.length,
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () { widget.onEmojiSelected(_recentEmojis[i]); _addToRecent(_recentEmojis[i]); setState(() {}); },
                child: Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(_recentEmojis[i], style: const TextStyle(fontSize: 24)),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticker content (WhatsApp-style browsing) ──
  Widget _buildStickerContent(Brightness brightness, bool isDark) {
    if (_searchQuery.isNotEmpty) {
      final allStickers = <String>[];
      for (final pack in _installedPacks) {
        allStickers.addAll(pack.stickers.where((s) {
          final q = _searchQuery.toLowerCase();
          final keywords = _emojiKeywords[s] ?? [];
          return keywords.any((kw) => kw.contains(q)) || s.toLowerCase().contains(q);
        }));
      }
      if (allStickers.isEmpty) {
        return Center(child: Text('No stickers found',
          style: TextStyle(color: KoraColors.textMutedFor(brightness), fontSize: 14)));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 1, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: allStickers.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => widget.onStickerSelected(allStickers[i]),
          child: Container(
            decoration: BoxDecoration(color: KoraColors.cardFor(brightness), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(allStickers[i], style: const TextStyle(fontSize: 48))),
          ),
        ),
      );
    }

    final pack = _installedPacks[_activeStickerPack.clamp(0, _installedPacks.length - 1)];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Text(pack.name, style: TextStyle(color: KoraColors.textPrimaryFor(brightness),
              fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${pack.stickers.length} stickers', style: TextStyle(
              color: KoraColors.textMutedFor(brightness), fontSize: 12)),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, childAspectRatio: 1, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: pack.stickers.length,
            itemBuilder: (ctx, i) {
              final sticker = pack.stickers[i];
              return GestureDetector(
                onTap: () => widget.onStickerSelected(sticker),
                child: Container(
                  decoration: BoxDecoration(color: KoraColors.cardFor(brightness), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(sticker, style: const TextStyle(fontSize: 48))),
                ),
              );
            },
          ),
        ),
        _buildPackTray(brightness, isDark),
      ],
    );
  }

  Widget _buildPackTray(Brightness brightness, bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2A35) : const Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: KoraColors.borderFor(brightness), width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        itemCount: _installedPacks.length + 1,
        itemBuilder: (ctx, index) {
          if (index == _installedPacks.length) {
            return GestureDetector(
              onTap: () => _showPackStore(brightness, isDark),
              child: Container(
                width: 44, height: 44, margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KoraColors.borderFor(brightness), width: 1)),
                child: Icon(Icons.add, size: 22, color: KoraColors.textMutedFor(brightness)),
              ),
            );
          }
          final pack = _installedPacks[index];
          final isActive = index == _activeStickerPack;
          return GestureDetector(
            onTap: () => setState(() => _activeStickerPack = index),
            child: Container(
              width: 44, height: 44, margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isActive ? KoraColors.purple.withOpacity(0.15) : KoraColors.cardFor(brightness),
                border: isActive ? Border.all(color: KoraColors.purple, width: 2) : null,
              ),
              child: Center(child: Text(pack.trayIcon, style: const TextStyle(fontSize: 26))),
            ),
          );
        },
      ),
    );
  }

  void _showPackStore(Brightness brightness, bool isDark) {
    final installedNames = _installedPacks.map((p) => p.name).toSet();
    final available = KoraStickerPack.storePacks.where((p) => !installedNames.contains(p.name)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('All sticker packs are installed!'),
          backgroundColor: KoraColors.purple, duration: const Duration(seconds: 2)));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: KoraColors.backgroundFor(brightness),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(top: 16),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: KoraColors.borderFor(brightness), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('Sticker Packs', style: TextStyle(color: KoraColors.textPrimaryFor(brightness),
                fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close, color: KoraColors.textMutedFor(brightness))),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: available.length,
              itemBuilder: (c, i) => _buildStorePackItem(available[i], brightness, isDark),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStorePackItem(KoraStickerPack pack, Brightness brightness, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KoraColors.cardFor(brightness),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoraColors.borderFor(brightness), width: 0.5)),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2A35) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(pack.trayIcon, style: const TextStyle(fontSize: 36))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pack.name, style: TextStyle(color: KoraColors.textPrimaryFor(brightness),
              fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${pack.stickers.length} stickers · ${pack.publisher}',
              style: TextStyle(color: KoraColors.textMutedFor(brightness), fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: pack.stickers.take(4).map((s) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(s, style: const TextStyle(fontSize: 22)))).toList()),
          ],
        )),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _installedPacks.add(pack);
              _activeStickerPack = _installedPacks.length - 1;
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${pack.name} installed!'),
                backgroundColor: KoraColors.purple, duration: const Duration(seconds: 2)));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: KoraColors.purple, foregroundColor: Colors.white,
            minimumSize: const Size(72, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          child: const Text('Add', style: TextStyle(fontSize: 13)),
        ),
      ]),
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

  Widget _buildTab({required IconData icon, required bool isActive,
    required Brightness brightness, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22,
              color: isActive ? KoraColors.purple : KoraColors.textMutedFor(brightness)),
            if (isActive) Container(
              width: 18, height: 2, margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: KoraColors.purple, borderRadius: BorderRadius.circular(1))),
          ],
        ),
      ),
    );
  }

  static const _emojiCategories = ['😀','🐶','🍔','⚽','🚗','💡','❤️','🏁'];

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
    '😇','🥰','😍','🤩','😘','😗','😚','😙','🥲','😋','😛','😜',
    '🤪','🤨','🧐','🤓','😎','🥸','🥳','😏','😒','😞','😔','😟',
    '😕','🙁','☹️','😣','😖','😫','😩','🥺','😢','😭','😤','😠',
    '😡','🤬','🤯','😱','😨','😰','😥','😓','🤗','🤔','🤫','🤥',
    '😶','😐','😑','😬','🙄','😯','😦','😧','😮','😲','🥱','😴',
    '🤤','😪','😵','🤒','🤕','🤢','🤮','🤧','🥵','🥶','🥴','🤠',
    '💀','👻','👽','🤖','🎃','😺','😸','😹','😻','😼','😽','🙀',
    '😿','😾','🙌','👏','🙏','🤝','👍','👎','👌','🤌','🤏','✌️',
    '🤞','🤟','🤘','🤙','👈','👉','👆','👇','☝️','👋','🤚','🖐️',
    '✋','🖖','✍️','💪','🦾','🦵','🦶','👂','🦻','👃','🧠','🦷',
    '🦴','👀','👁️','👅','👄','👶','🧒','👦','👧','🧑','👨','👩',
    '🧓','👴','👵','🙋','🙇','🤦','🤷','💆','💇','🚶','🧍','🧎',
    '🏃','💃','🕺','👯','🗣️','👤',
  ];

  static const _animalsNature = [
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮',
    '🐷','🐸','🐵','🐔','🐧','🐦','🦆','🦅','🦉','🦋','🐛','🐝',
    '🐞','🐜','🕷️','🦄','🐴','🦓','🦒','🐘','🦏','🦘','🐊','🐢',
    '🐍','🐲','🦕','🦖','🐙','🦑','🦐','🦀','🐡','🐠','🐟','🐬',
    '🐳','🐋','🦈','🦭','🐾','🐉','🌵','🎄','🌲','🌳','🌴','🌱',
    '🌿','☘️','🍀','🍁','🍂','🍃','🍄','🐚','🌾','💐','🌷','🌹',
    '🥀','🌺','🌸','🌼','🌻','🌞','🌝','🌚','🌛','🌜','⭐','🌟',
    '💫','✨','☄️','🪐','🐂','🐄','🐎','🐖','🐏','🐑','🦙','🐐',
    '🦌','🐕','🐩','🦮','🐈','🐓','🦃','🦚','🦜','🦢','🦩','🕊️',
    '🐇','🦝','🦨','🦡',
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
    KoraStickerPack(name: 'Kora Originals', publisher: 'Kora', trayIcon: '🟣',
      stickers: ['😀','😂','🥰','😎','🤔','😱','🥳','😭','😡','😴','🤯','🤗','🤫','🥺','😏','🤓']),
    KoraStickerPack(name: 'Hearts', publisher: 'Kora', trayIcon: '❤️',
      stickers: ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','💕','💞','💓','💗','💖','💘','💝']),
    KoraStickerPack(name: 'Animals', publisher: 'Kora', trayIcon: '🐶',
      stickers: ['🐶','🐱','🦊','🐻','🐼','🐨','🦁','🐯','🐸','🐵','🦄','🐙','🦋','🐝','🦉','🐺']),
    KoraStickerPack(name: 'Food & Drink', publisher: 'Kora', trayIcon: '🍔',
      stickers: ['🍔','🍕','🍟','🌮','🍣','🍜','🍩','🍦','☕','🍺','🍷','🧋','🍰','🍪','🍫','🍿']),
  ];

  static const storePacks = [
    KoraStickerPack(name: 'Reactions', publisher: 'Kora', trayIcon: '🔥',
      stickers: ['👍','👎','👌','👏','🙌','🙏','🤝','💪','🤜','🤛','✌️','🤞','🤟','🤘','🤙','👋']),
    KoraStickerPack(name: 'Faces', publisher: 'Kora', trayIcon: '🤪',
      stickers: ['🤣','😁','😆','😅','🙃','😉','😇','🥰','😍','🤩','😘','😋','😜','🤪','🤨','🧐']),
    KoraStickerPack(name: 'Sad & Angry', publisher: 'Kora', trayIcon: '😢',
      stickers: ['😢','😭','😞','😔','😟','😕','🙁','☹️','😣','😖','😫','😩','😤','😠','😡','🤬']),
    KoraStickerPack(name: 'Party', publisher: 'Kora', trayIcon: '🎉',
      stickers: ['🎉','🎊','🎈','🎁','🎀','🎂','🥳','🍾','🪅','🎆','🎇','✨','🥂','🍻','💃','🕺']),
    KoraStickerPack(name: 'Nature', publisher: 'Kora', trayIcon: '🌸',
      stickers: ['🌸','🌺','🌻','🌷','🌹','🥀','🌼','🍀','🍁','🍂','🌴','🌵','🌲','🌳','🌊','🌅']),
    KoraStickerPack(name: 'Travel', publisher: 'Kora', trayIcon: '✈️',
      stickers: ['✈️','🚀','🚗','🚕','🚌','🚆','🚢','⛵','🏍️','🚲','🗺️','🗽','🗼','🏰','🏖️','🏝️']),
    KoraStickerPack(name: 'Sports', publisher: 'Kora', trayIcon: '⚽',
      stickers: ['⚽','🏀','🏈','⚾','🎾','🏐','🏉','🏓','🏸','⛳','🏹','🎣','🥊','🏆','🥇','🎮']),
    KoraStickerPack(name: 'Weather', publisher: 'Kora', trayIcon: '☀️',
      stickers: ['☀️','🌤️','⛅','🌥️','☁️','🌦️','🌧️','⛈️','🌩️','🌨️','❄️','💨','💧','🌈','🌙','⭐']),
  ];
}
