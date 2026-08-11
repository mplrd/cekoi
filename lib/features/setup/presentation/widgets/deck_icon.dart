import 'package:flutter/material.dart';

/// L'icône d'une catégorie, à partir du nom porté par son JSON.
///
/// La table est **statique et exhaustive**, et ne se remplace pas par un
/// `IconData(codePoint)` calculé : la compilation en release ne garde que les
/// glyphes référencés littéralement dans le code (`--tree-shake-icons`), et
/// une icône construite à la volée s'afficherait comme un carré vide sur le
/// téléphone alors qu'elle est correcte en développement.
///
/// Un nom inconnu retombe sur [_defaut] plutôt que de laisser un trou : une
/// catégorie livrée sans icône, ou avec une icône mal orthographiée, doit
/// rester présentable.
IconData deckIcon(String? name) => _icones[name] ?? _defaut;

const IconData _defaut = Icons.style;

const Map<String, IconData> _icones = {
  // Mode famille
  'cookie': Icons.cookie,
  'pets': Icons.pets,
  'home': Icons.home,
  'mood': Icons.mood,
  'work': Icons.work,
  'sports_soccer': Icons.sports_soccer,
  'music_note': Icons.music_note,
  'rocket_launch': Icons.rocket_launch,
  'auto_awesome': Icons.auto_awesome,
  'location_city': Icons.location_city,
  'directions_run': Icons.directions_run,
  'bolt': Icons.bolt,
  'castle': Icons.castle,
  'movie': Icons.movie,
  'history_edu': Icons.history_edu,
  'star': Icons.star,
  // Mode Sans filtres
  'mood_bad': Icons.mood_bad,
  'sentiment_dissatisfied': Icons.sentiment_dissatisfied,
  'local_bar': Icons.local_bar,
  'favorite': Icons.favorite,
  'live_tv': Icons.live_tv,
  // Catégories du joueur : elles n'en portent pas, mais un nom peut arriver
  // par l'import d'un fichier partagé.
  'edit': Icons.edit,
  'group': Icons.group,
};
