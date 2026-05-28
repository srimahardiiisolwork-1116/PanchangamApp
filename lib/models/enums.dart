enum Paksha { shukla, krishna }

class Nakshatra {
  static const double spanDegrees = 13 + (20 / 60); // 13°20'
  static const List<String> names = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishtha',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];
}

class Tithi {
  static const double spanDegrees = 12.0; // 360/30
  static const List<String> names = [
    'Pratipada',
    'Dvitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dvadashi',
    'Trayodashi',
    'Chaturdashi',
    'Purnima/Amavasya'
  ];
}

class TeluguMonth {
  static const List<String> names = [
    'Chaitra',
    'Vaisakha',
    'Jyeshtha',
    'Ashadha',
    'Shravana',
    'Bhadrapada',
    'Ashwayuja',
    'Kartika',
    'Margashirsha',
    'Pushya',
    'Magha',
    'Phalguna'
  ];
}
