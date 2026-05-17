import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Avatar circulaire universel.
///
/// Affiche la photo de profil (base64) si disponible, sinon l'icône ou l'initiale.
class UserAvatar extends StatelessWidget {
  /// Image encodée en base64. null = pas de photo.
  final String? photoBase64;

  /// Lettre de secours affichée quand il n'y a pas de photo.
  final String initial;

  /// Rayon du cercle (défaut 18).
  final double radius;

  /// Couleur de fond quand on affiche l'initiale ou l'icône.
  final Color backgroundColor;

  /// Taille de la police de l'initiale (auto = radius * 0.75 si null).
  final double? fontSize;

  /// Icône optionnelle à afficher à la place de l'initiale.
  final IconData? icon;

  const UserAvatar({
    super.key,
    required this.initial,
    this.photoBase64,
    this.radius = 18,
    this.backgroundColor = const Color(0xFF0047AB),
    this.fontSize,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(photoBase64!);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
          backgroundColor: backgroundColor,
        );
      } catch (_) {
        // Base64 invalide → repli
      }
    }

    if (icon != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Icon(
          icon,
          color: Colors.white,
          size: radius * 1.1,
        ),
      );
    }

    final letter = initial.isNotEmpty ? initial[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? radius * 0.75,
        ),
      ),
    );
  }
}
