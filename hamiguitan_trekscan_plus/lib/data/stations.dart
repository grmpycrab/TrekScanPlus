class Station {
  final String name;
  final String difficulty;
  final int elevation;
  final String coordinates;
  final int? steps;

  const Station({
    required this.name,
    required this.difficulty,
    required this.elevation,
    required this.coordinates,
    this.steps,
  });
}

const List<Station> stations = [
  Station(
    name: 'UNESCO MARKER',
    difficulty: 'Easy',
    elevation: 449,
    coordinates: 'N:06°44\'10.65\'\' E:126°08\'29.99\'\'',
  ),
  Station(
    name: 'Crossing Stampa',
    difficulty: 'Moderate',
    elevation: 682,
    coordinates: 'N:06°44\'05.54\'\' E:126°08\'34.09\'\'',
  ),
  Station(
    name: 'Puting Bato',
    difficulty: 'Moderate',
    elevation: 623,
    coordinates: 'N:06°43\'46.66\'\' E:126°09\'22.06\'\'',
  ),
  Station(
    name: 'Lantawan 1',
    difficulty: 'Moderate',
    elevation: 830,
    coordinates: 'N:06°43\'23.06\'\' E:126°09\'38.12\'\'',
    steps: 5194,
  ),
  Station(
    name: 'Camp 4',
    difficulty: 'Difficult',
    elevation: 908,
    coordinates: 'N:06°43\'23.06\'\' E:126°09\'38.21\'\'',
    steps: 8200,
  ),
  Station(
    name: 'Uwang-Uwang Trail',
    difficulty: 'Difficult',
    elevation: 1121,
    coordinates: 'N:06°43\'56.04\'\' E:126°10\'38.58\'\'',
  ),
  Station(
    name: 'Lantawan 2',
    difficulty: 'Difficult',
    elevation: 1215,
    coordinates: 'N:06°43\'53.30\'\' E:126°10\'41.70\'\'',
    steps: 3767,
  ),
  Station(
    name: 'Camp 3',
    difficulty: 'Difficult',
    elevation: 1190,
    coordinates: 'N:06°43\'34.44\'\' E:126°11\'03.75\'\'',
    steps: 6627,
  ),
  Station(
    name: 'Pygmy Field',
    difficulty: 'Difficult',
    elevation: 1214,
    coordinates: 'N:06°43\'12.97\'\' E:126°11\'00.22\'\'',
    steps: 1595,
  ),
  Station(
    name: 'Lantawan 3 / Mossy Forest',
    difficulty: 'Difficult',
    elevation: 1363,
    coordinates: 'N:06°42\'46.08\'\' E:126°11\'14.02\'\'',
    steps: 5241,
  ),
  Station(
    name: 'Tinagong Dagat',
    difficulty: 'Difficult',
    elevation: 1108,
    coordinates: 'N:06°42\'27.55\'\' E:126°11\'43.11\'\'',
    steps: 8895,
  ),
  Station(
    name: 'Peak',
    difficulty: 'Difficult',
    elevation: 1641,
    coordinates: 'N:06°44\'23.90\'\' E:126°10\'55.25\'\'',
    steps: 6342,
  ),
  Station(
    name: 'Black Mountain',
    difficulty: 'Difficult',
    elevation: 1238,
    coordinates: 'N:06°43\'35.73\'\' E:126°10\'49.34\'\'',
    steps: 1709,
  ),
  Station(
    name: 'Twin Falls',
    difficulty: 'Difficult',
    elevation: 1130,
    coordinates: 'N:06°43\'25.74\'\' E:126°10\'59.02\'\'',
    steps: 4133,
  ),
];
