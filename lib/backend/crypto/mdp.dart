import 'dart:math';

bool mdp(String password) {
  if (password.length < 12 ||
      !password.contains(RegExp(r'[A-Z]')) ||
      !password.contains(RegExp(r'[0-9]')) ||
      !password.contains(RegExp(r'[^a-zA-Z0-9]'))) {
    return false;
  } else {
    return true;
  }
}

class PasswordAnalysis {
  final int length;
  final int score;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumbers;
  final bool hasSymbols;
  final bool hasMinLength;
  final bool hasRepeatedChars;
  final List<String> suggestions;
  final String strengthLabel;
  final double progress;

  PasswordAnalysis({
    required this.length,
    required this.score,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumbers,
    required this.hasSymbols,
    required this.hasMinLength,
    required this.hasRepeatedChars,
    required this.suggestions,
    required this.strengthLabel,
    required this.progress,
  });
}

PasswordAnalysis analyzePassword(String password) {
  final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
  final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
  final hasNumbers = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbols = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);
  final hasMinLength = password.length >= 12;
  final hasRepeatedChars = RegExp(r'(.)\1{2,}').hasMatch(password);

  int score = 0;

  if (hasUppercase) score++;
  if (hasLowercase) score++;
  if (hasNumbers) score++;
  if (hasSymbols) score++;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  if (password.length >= 20) score++;
  if (!hasRepeatedChars && password.isNotEmpty) score++;

  final suggestions = <String>[];

  if (!hasUppercase) suggestions.add("Ajoutez des majuscules");
  if (!hasLowercase) suggestions.add("Ajoutez des minuscules");
  if (!hasNumbers) suggestions.add("Ajoutez des chiffres");
  if (!hasSymbols) suggestions.add("Ajoutez des symboles");
  if (!hasMinLength) suggestions.add("Utilisez au moins 12 caractères");
  if (hasRepeatedChars) suggestions.add("Évitez les caractères répétés");

  String strengthLabel;
  if (score <= 2) {
    strengthLabel = "Faible";
  } else if (score <= 4) {
    strengthLabel = "Moyen";
  } else if (score <= 6) {
    strengthLabel = "Bon";
  } else {
    strengthLabel = "Fort";
  }

  return PasswordAnalysis(
    length: password.length,
    score: score,
    hasUppercase: hasUppercase,
    hasLowercase: hasLowercase,
    hasNumbers: hasNumbers,
    hasSymbols: hasSymbols,
    hasMinLength: hasMinLength,
    hasRepeatedChars: hasRepeatedChars,
    suggestions: suggestions,
    strengthLabel: strengthLabel,
    progress: score / 8,
  );
}

String generatePassword(
    bool majuscules,
    bool chiffres,
    bool caracteresSpeciaux,
    bool minuscules,
    double longueur,
    ) {
  const String upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  const String lower = "abcdefghijklmnopqrstuvwxyz";
  const String numbers = "0123456789";
  const String special = "!@#\$%^&*()_+-=[]{}|;:,.<>?";

  String allowedChars = "";
  List<String> requiredChars = [];

  final random = Random();

  if (majuscules) {
    allowedChars += upper;
    requiredChars.add(upper[random.nextInt(upper.length)]);
  }

  if (minuscules) {
    allowedChars += lower;
    requiredChars.add(lower[random.nextInt(lower.length)]);
  }

  if (chiffres) {
    allowedChars += numbers;
    requiredChars.add(numbers[random.nextInt(numbers.length)]);
  }

  if (caracteresSpeciaux) {
    allowedChars += special;
    requiredChars.add(special[random.nextInt(special.length)]);
  }

  if (allowedChars.isEmpty || longueur <= 0) {
    return "";
  }

  final int len = longueur.toInt();
  List<String> passwordChars = [];

  passwordChars.addAll(requiredChars);

  while (passwordChars.length < len) {
    int index = random.nextInt(allowedChars.length);
    passwordChars.add(allowedChars[index]);
  }

  passwordChars.shuffle(random);

  return passwordChars.join();
}