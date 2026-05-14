String chiffrerCesar(String chaine, int pas) {
  /*
  Fonction chiffrer(message, decalage) :
  Chiffrement type César.
  Chaque lettre est décalée dans l’alphabet.

  Exemple avec décalage 3 :
  A → D, B → E, C → F, ..., X → A, Y → B, Z → C
  */

  String resultat = "";
  pas = pas % 26;

  for (int i = 0; i < chaine.length; i++) {
    String m = chaine[i];

    if (RegExp(r'[a-zA-Z]').hasMatch(m)) {
      int code = m.codeUnitAt(0);

      if (RegExp(r'[A-Z]').hasMatch(m)) {
        resultat += String.fromCharCode(
            (code - 'A'.codeUnitAt(0) + pas) % 26 + 'A'.codeUnitAt(0));
      } else {
        resultat += String.fromCharCode(
            (code - 'a'.codeUnitAt(0) + pas) % 26 + 'a'.codeUnitAt(0));
      }
    } else {
      resultat += m;
    }
  }

  return resultat;
}


String dechiffrerCesar(String chaine, int pas) {
  /*
  Fait l'inverse de chiffrer.
  */
  return chiffrerCesar(chaine, -pas);
}