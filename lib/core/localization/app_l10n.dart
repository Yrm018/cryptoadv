import 'package:flutter/material.dart';
import '../../providers/locale_provider.dart';
import 'package:provider/provider.dart';

/// Classe de traductions — fr / en / ar.
///
/// Utilisation dans n'importe quel widget :
///   final t = AppL10n.of(context).t;
///   Text(t('home'))
///
/// La méthode [of] écoute [LocaleProvider] → le widget se reconstruit
/// automatiquement quand l'utilisateur change de langue.
class AppL10n {
  final String lang;

  AppL10n(this.lang);

  static AppL10n of(BuildContext context) =>
      AppL10n(context.watch<LocaleProvider>().languageCode);

  /// Retourne la traduction de [key] dans la langue courante.
  /// Repli sur le français si la clé n'existe pas dans la langue demandée.
  String t(String key) =>
      _strings[lang]?[key] ?? _strings['fr']![key] ?? key;

  // ── Dictionnaire ───────────────────────────────────────────────────────────

  static const Map<String, Map<String, String>> _strings = {
    // ════════════════════════════════════════════════════════════════════════
    'fr': {
      // Navigation
      'home':          'Home',
      'hachage':       'Hachage',
      'chiffrement':   'Chiffrement',
      'mdp':           'Mots de passe',
      'chat':          'Chat',
      'vpn':           'VPN',
      'history':       'Historique',
      'documentation': 'Documentation',

      // Paramètres
      'account_settings': 'Paramètres du compte',
      'light_mode':       'Mode clair',
      'dark_mode':        'Mode sombre',
      'logout':           'Se déconnecter',
      'my_account':       'Mon compte',
      'language':         'Langue',
      'choose_language':  'Choisir la langue',
      'french':           'Français',
      'english':          'Anglais',
      'arabic':           'Arabe',

      // Auth — titres
      'login_title':    'Connexion',
      'signup_title':   'Créer un compte',
      'login_sub':      'Connectez-vous pour accéder à CryptoAdv.',
      'signup_sub':     'Créez un compte pour sauvegarder votre historique.',
      'mobile_login_sub':  'Accédez à votre espace sécurisé.',
      'mobile_signup_sub': 'Rejoignez CryptoAdv dès maintenant.',
      'crypto_subtitle':   'Cryptographie & Sécurité',

      // Auth — champs
      'identifier':        'Email ou nom d\'utilisateur',
      'identifier_hint':   'Email ou @username...',
      'first_name':        'Prénom',
      'first_name_hint':   'Prénom...',
      'last_name':         'Nom',
      'last_name_hint':    'Nom...',
      'email':             'Email',
      'email_hint':        'Email...',
      'username':          'Nom d\'utilisateur',
      'username_hint':     '@username...',
      'password':          'Mot de passe',
      'password_hint':     'Mot de passe...',
      'confirm_password':  'Confirmer le mot de passe',
      'confirm_hint':      'Confirmez...',

      // Auth — boutons / liens
      'login_btn':         'Se connecter',
      'signup_btn':        'S\'inscrire',
      'no_account':        'Pas encore de compte ? S\'inscrire',
      'already_account':   'Déjà un compte ? Se connecter',
      'create_account':    'Créer un compte',
      'or':                'OU',
      'continue_with':     'Continuer avec',

      // Force du mot de passe
      'str_length':  '8 caractères min.',
      'str_upper':   '1 majuscule',
      'str_lower':   '1 minuscule',
      'str_digit':   '1 chiffre',
      'str_special': '1 car. spécial',

      // Dialog paramètres du compte
      'edit_username':       'Modifier le nom d\'utilisateur',
      'edit_password':       'Modifier le mot de passe',
      'edit_profile':        'Modifier le profil',
      'save':                'Enregistrer',
      'change_password_btn': 'Changer le mot de passe',
      'update_btn':          'Mettre à jour',
      'current_password':    'Mot de passe actuel',
      'new_password':        'Nouveau mot de passe',
      'confirm_new_password':'Confirmer le nouveau mot de passe',

      // Messages de succès
      'username_updated': 'Nom d\'utilisateur mis à jour !',
      'password_updated': 'Mot de passe mis à jour !',
      'profile_updated':  'Profil mis à jour !',

      // Erreurs
      'fill_fields':      'Veuillez remplir tous les champs.',
      'pass_no_match':    'Les mots de passe ne correspondent pas.',
      'error_prefix':     'Une erreur est survenue',

      // Codes d'erreur service
      'err_user_not_found':      'Aucun compte trouvé avec cet identifiant.',
      'err_wrong_password':      'Mot de passe incorrect.',
      'err_email_in_use':        'Un compte existe déjà avec cet email.',
      'err_username_in_use':     'Ce nom d\'utilisateur est déjà pris.',
      'err_weak_password':       'Le mot de passe ne respecte pas les critères.',
      'err_invalid_username':    'Nom d\'utilisateur invalide.',
      'err_current_wrong_pass':  'Mot de passe actuel incorrect.',
    },

    // ════════════════════════════════════════════════════════════════════════
    'en': {
      'home':          'Home',
      'hachage':       'Hashing',
      'chiffrement':   'Encryption',
      'mdp':           'Passwords',
      'chat':          'Chat',
      'vpn':           'VPN',
      'history':       'History',
      'documentation': 'Documentation',

      'account_settings': 'Account Settings',
      'light_mode':       'Light mode',
      'dark_mode':        'Dark mode',
      'logout':           'Log out',
      'my_account':       'My account',
      'language':         'Language',
      'choose_language':  'Choose language',
      'french':           'French',
      'english':          'English',
      'arabic':           'Arabic',

      'login_title':    'Login',
      'signup_title':   'Create account',
      'login_sub':      'Log in to access CryptoAdv.',
      'signup_sub':     'Create an account to save your history.',
      'mobile_login_sub':  'Access your secure space.',
      'mobile_signup_sub': 'Join CryptoAdv now.',
      'crypto_subtitle':   'Cryptography & Security',

      'identifier':        'Email or username',
      'identifier_hint':   'Email or @username...',
      'first_name':        'First name',
      'first_name_hint':   'First name...',
      'last_name':         'Last name',
      'last_name_hint':    'Last name...',
      'email':             'Email',
      'email_hint':        'Email...',
      'username':          'Username',
      'username_hint':     '@username...',
      'password':          'Password',
      'password_hint':     'Password...',
      'confirm_password':  'Confirm password',
      'confirm_hint':      'Confirm...',

      'login_btn':         'Log in',
      'signup_btn':        'Sign up',
      'no_account':        'No account yet? Sign up',
      'already_account':   'Already have an account? Log in',
      'create_account':    'Create an account',
      'or':                'OR',
      'continue_with':     'Continue with',

      'str_length':  '8 chars min.',
      'str_upper':   '1 uppercase',
      'str_lower':   '1 lowercase',
      'str_digit':   '1 digit',
      'str_special': '1 special char',

      'edit_username':       'Change username',
      'edit_password':       'Change password',
      'edit_profile':        'Edit profile',
      'save':                'Save',
      'change_password_btn': 'Change password',
      'update_btn':          'Update',
      'current_password':    'Current password',
      'new_password':        'New password',
      'confirm_new_password':'Confirm new password',

      'username_updated': 'Username updated!',
      'password_updated': 'Password updated!',
      'profile_updated':  'Profile updated!',

      'fill_fields':   'Please fill in all fields.',
      'pass_no_match': 'Passwords do not match.',
      'error_prefix':  'An error occurred',

      'err_user_not_found':      'No account found with this identifier.',
      'err_wrong_password':      'Incorrect password.',
      'err_email_in_use':        'An account already exists with this email.',
      'err_username_in_use':     'This username is already taken.',
      'err_weak_password':       'Password does not meet requirements.',
      'err_invalid_username':    'Invalid username.',
      'err_current_wrong_pass':  'Current password is incorrect.',
    },

    // ════════════════════════════════════════════════════════════════════════
    'ar': {
      'home':          'الرئيسية',
      'hachage':       'التجزئة',
      'chiffrement':   'التشفير',
      'mdp':           'كلمات المرور',
      'chat':          'المحادثة',
      'vpn':           'الشبكة الافتراضية',
      'history':       'السجل',
      'documentation': 'التوثيق',

      'account_settings': 'إعدادات الحساب',
      'light_mode':       'الوضع الفاتح',
      'dark_mode':        'الوضع الداكن',
      'logout':           'تسجيل الخروج',
      'my_account':       'حسابي',
      'language':         'اللغة',
      'choose_language':  'اختر اللغة',
      'french':           'الفرنسية',
      'english':          'الإنجليزية',
      'arabic':           'العربية',

      'login_title':    'تسجيل الدخول',
      'signup_title':   'إنشاء حساب',
      'login_sub':      'سجّل دخولك للوصول إلى CryptoAdv.',
      'signup_sub':     'أنشئ حسابًا لحفظ سجلّك.',
      'mobile_login_sub':  'ادخل إلى مساحتك الآمنة.',
      'mobile_signup_sub': 'انضم إلى CryptoAdv الآن.',
      'crypto_subtitle':   'التشفير والأمان',

      'identifier':        'البريد الإلكتروني أو اسم المستخدم',
      'identifier_hint':   'بريد إلكتروني أو @username...',
      'first_name':        'الاسم الأول',
      'first_name_hint':   'الاسم الأول...',
      'last_name':         'اسم العائلة',
      'last_name_hint':    'اسم العائلة...',
      'email':             'البريد الإلكتروني',
      'email_hint':        'البريد الإلكتروني...',
      'username':          'اسم المستخدم',
      'username_hint':     '@username...',
      'password':          'كلمة المرور',
      'password_hint':     'كلمة المرور...',
      'confirm_password':  'تأكيد كلمة المرور',
      'confirm_hint':      'تأكيد...',

      'login_btn':         'تسجيل الدخول',
      'signup_btn':        'إنشاء حساب',
      'no_account':        'ليس لديك حساب؟ إنشاء حساب',
      'already_account':   'لديك حساب؟ تسجيل الدخول',
      'create_account':    'إنشاء حساب',
      'or':                'أو',
      'continue_with':     'المتابعة مع',

      'str_length':  '8 أحرف على الأقل',
      'str_upper':   '1 حرف كبير',
      'str_lower':   '1 حرف صغير',
      'str_digit':   '1 رقم',
      'str_special': '1 رمز خاص',

      'edit_username':       'تغيير اسم المستخدم',
      'edit_password':       'تغيير كلمة المرور',
      'edit_profile':        'تعديل الملف الشخصي',
      'save':                'حفظ',
      'change_password_btn': 'تغيير كلمة المرور',
      'update_btn':          'تحديث',
      'current_password':    'كلمة المرور الحالية',
      'new_password':        'كلمة المرور الجديدة',
      'confirm_new_password':'تأكيد كلمة المرور الجديدة',

      'username_updated': '!تم تحديث اسم المستخدم',
      'password_updated': '!تم تحديث كلمة المرور',
      'profile_updated':  '!تم تحديث الملف الشخصي',

      'fill_fields':   'يرجى ملء جميع الحقول.',
      'pass_no_match': 'كلمات المرور غير متطابقة.',
      'error_prefix':  'حدث خطأ',

      'err_user_not_found':      'لم يُعثر على حساب بهذا المعرّف.',
      'err_wrong_password':      'كلمة المرور غير صحيحة.',
      'err_email_in_use':        'يوجد حساب بهذا البريد الإلكتروني بالفعل.',
      'err_username_in_use':     'اسم المستخدم هذا مستخدم بالفعل.',
      'err_weak_password':       'كلمة المرور لا تستوفي المتطلبات.',
      'err_invalid_username':    'اسم مستخدم غير صالح.',
      'err_current_wrong_pass':  'كلمة المرور الحالية غير صحيحة.',
    },
  };
}

/// Traduit un code d'erreur AuthException en message localisé.
String translateAuthError(String code, AppL10n l) {
  switch (code) {
    case 'user-not-found':        return l.t('err_user_not_found');
    case 'wrong-password':        return l.t('err_wrong_password');
    case 'email-already-in-use':  return l.t('err_email_in_use');
    case 'username-already-in-use': return l.t('err_username_in_use');
    case 'weak-password':         return l.t('err_weak_password');
    case 'invalid-username':      return l.t('err_invalid_username');
    case 'wrong-password-current':return l.t('err_current_wrong_pass');
    default:                      return '${l.t('error_prefix')} : $code';
  }
}
