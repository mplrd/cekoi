/// Âge minimum porté par une catégorie (R7.4).
///
/// Les valeurs sont volontairement fermées : un profil de partie ne retient
/// que les catégories dont le [MinAge] est inférieur ou égal au sien, et une
/// échelle libre rendrait ce filtre imprévisible.
enum MinAge {
  six(6),
  ten(10),
  thirteen(13),
  eighteen(18);

  const MinAge(this.years);

  final int years;

  static MinAge fromYears(int years) => switch (years) {
    6 => MinAge.six,
    10 => MinAge.ten,
    13 => MinAge.thirteen,
    18 => MinAge.eighteen,
    _ => throw ArgumentError.value(
      years,
      'years',
      'minAge doit valoir 6, 10, 13 ou 18',
    ),
  };

  bool isAllowedBy(MinAge profileMinAge) => years <= profileMinAge.years;
}
