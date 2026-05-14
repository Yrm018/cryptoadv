const int ASCII_START = 32;
const int ASCII_END = 126;
const int ASCII_RANGE = ASCII_END - ASCII_START + 1;

/// ===============================
/// OUTILS PERMUTATION
/// ===============================
List<int> genererPermutation(String cle, int longueur) {
  final indices = List<int>.generate(longueur, (i) => i);

  int seed = 0;
  for (final unit in cle.codeUnits) {
    seed += unit;
  }

  for (int i = 0; i < longueur; i++) {
    final int j = (seed + i * 7) % longueur;
    final tmp = indices[i];
    indices[i] = indices[j];
    indices[j] = tmp;
  }

  return indices;
}

String appliquerPermutation(String texte, List<int> permutation) {
  final units = texte.codeUnits;
  final out = List<int>.filled(permutation.length, 0);

  for (int k = 0; k < permutation.length; k++) {
    out[k] = units[permutation[k]];
  }

  return String.fromCharCodes(out);
}

List<int> inverserPermutation(List<int> permutation) {
  final inverse = List<int>.filled(permutation.length, 0);

  for (int i = 0; i < permutation.length; i++) {
    inverse[permutation[i]] = i;
  }

  return inverse;
}

/// ===============================
/// VIGENERE NORMAL
/// - chiffre uniquement les lettres
/// - garde espaces, chiffres, ponctuation inchangés
/// ===============================
String chiffrerVigenereNormal(String texte, String cle) {
  if (cle.isEmpty) {
    throw ArgumentError("La clé ne doit pas être vide");
  }

  final cleNettoyee = cle.replaceAll(RegExp(r'[^a-zA-Z]'), '');
  if (cleNettoyee.isEmpty) {
    throw ArgumentError("La clé doit contenir au moins une lettre");
  }

  final buffer = StringBuffer();
  int indexCle = 0;

  for (int i = 0; i < texte.length; i++) {
    final ch = texte[i];
    final code = ch.codeUnitAt(0);

    final bool estMajuscule = code >= 65 && code <= 90;
    final bool estMinuscule = code >= 97 && code <= 122;

    if (estMajuscule || estMinuscule) {
      final k = cleNettoyee[indexCle % cleNettoyee.length].toLowerCase();
      final pas = k.codeUnitAt(0) - 97;

      if (estMajuscule) {
        buffer.writeCharCode(((code - 65 + pas) % 26) + 65);
      } else {
        buffer.writeCharCode(((code - 97 + pas) % 26) + 97);
      }

      indexCle++;
    } else {
      buffer.write(ch);
    }
  }

  return buffer.toString();
}

String dechiffrerVigenereNormal(String texte, String cle) {
  if (cle.isEmpty) {
    throw ArgumentError("La clé ne doit pas être vide");
  }

  final cleNettoyee = cle.replaceAll(RegExp(r'[^a-zA-Z]'), '');
  if (cleNettoyee.isEmpty) {
    throw ArgumentError("La clé doit contenir au moins une lettre");
  }

  final buffer = StringBuffer();
  int indexCle = 0;

  for (int i = 0; i < texte.length; i++) {
    final ch = texte[i];
    final code = ch.codeUnitAt(0);

    final bool estMajuscule = code >= 65 && code <= 90;
    final bool estMinuscule = code >= 97 && code <= 122;

    if (estMajuscule || estMinuscule) {
      final k = cleNettoyee[indexCle % cleNettoyee.length].toLowerCase();
      final pas = k.codeUnitAt(0) - 97;

      if (estMajuscule) {
        buffer.writeCharCode(((code - 65 - pas + 26) % 26) + 65);
      } else {
        buffer.writeCharCode(((code - 97 - pas + 26) % 26) + 97);
      }

      indexCle++;
    } else {
      buffer.write(ch);
    }
  }

  return buffer.toString();
}

/// ===============================
/// VIGENERE AVANCE
/// - chiffre tout l'ASCII imprimable
/// - espaces, chiffres, ponctuation inclus
/// ===============================
String chiffrerVigenereAvance(String chaine, String cle) {
  if (cle.isEmpty) {
    throw ArgumentError("La clé ne doit pas être vide");
  }

  final out = <int>[];
  int indexCle = 0;

  final cleUnits = cle.codeUnits;
  final cleLen = cleUnits.length;

  for (final code in chaine.codeUnits) {
    if (code >= ASCII_START && code <= ASCII_END) {
      final int k = cleUnits[indexCle % cleLen];
      final int pas = k % ASCII_RANGE;
      final int newCode =
          ASCII_START + ((code - ASCII_START + pas) % ASCII_RANGE);

      out.add(newCode);
      indexCle++;
    } else {
      out.add(code);
    }
  }

  return String.fromCharCodes(out);
}

String dechiffrerVigenereAvance(String chaine, String cle) {
  if (cle.isEmpty) {
    throw ArgumentError("La clé ne doit pas être vide");
  }

  final out = <int>[];
  int indexCle = 0;

  final cleUnits = cle.codeUnits;
  final cleLen = cleUnits.length;

  for (final code in chaine.codeUnits) {
    if (code >= ASCII_START && code <= ASCII_END) {
      final int k = cleUnits[indexCle % cleLen];
      final int pas = k % ASCII_RANGE;
      final int shifted = (code - ASCII_START - pas) % ASCII_RANGE;
      final int fixed = (shifted + ASCII_RANGE) % ASCII_RANGE;
      final int newCode = ASCII_START + fixed;

      out.add(newCode);
      indexCle++;
    } else {
      out.add(code);
    }
  }

  return String.fromCharCodes(out);
}

/// ===============================
/// VIGENERE AVANCE + PERMUTATION
/// ===============================
String chiffrerVigenerePermute(String texte, String cle) {
  if (cle.isEmpty) {
    throw ArgumentError("La clé ne doit pas être vide");
  }

  final perm = genererPermutation(cle, texte.length);
  final textePerm = appliquerPermutation(texte, perm);
  return chiffrerVigenereAvance(textePerm, cle);
}

String dechiffrerVigenerePermute(String texte, String cle) {
  if (cle.isEmpty) {
    throw ArgumentError("La clé ne doit pas être vide");
  }

  final texteVig = dechiffrerVigenereAvance(texte, cle);
  final perm = genererPermutation(cle, texteVig.length);
  final invPerm = inverserPermutation(perm);
  return appliquerPermutation(texteVig, invPerm);
}