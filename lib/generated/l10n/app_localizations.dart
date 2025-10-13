import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardian'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get home;

  /// No description provided for @alerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get alerts;

  /// No description provided for @map.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get map;

  /// No description provided for @profile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profile;

  /// No description provided for @communities.
  ///
  /// In es, this message translates to:
  /// **'Comunidades'**
  String get communities;

  /// No description provided for @statistics.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get statistics;

  /// No description provided for @createAlert.
  ///
  /// In es, this message translates to:
  /// **'Crear Alerta'**
  String get createAlert;

  /// No description provided for @recentAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas Recientes'**
  String get recentAlerts;

  /// No description provided for @serviceStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado del Servicio'**
  String get serviceStatus;

  /// No description provided for @serviceActive.
  ///
  /// In es, this message translates to:
  /// **'Servicio Activo'**
  String get serviceActive;

  /// No description provided for @serviceInactive.
  ///
  /// In es, this message translates to:
  /// **'Servicio Inactivo'**
  String get serviceInactive;

  /// No description provided for @startService.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Servicio'**
  String get startService;

  /// No description provided for @stopService.
  ///
  /// In es, this message translates to:
  /// **'Detener Servicio'**
  String get stopService;

  /// No description provided for @notifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Idioma'**
  String get selectLanguage;

  /// No description provided for @spanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get loading;

  /// No description provided for @noRecentAlerts.
  ///
  /// In es, this message translates to:
  /// **'No hay alertas recientes'**
  String get noRecentAlerts;

  /// No description provided for @tapToCreateAlert.
  ///
  /// In es, this message translates to:
  /// **'Toca para crear una alerta'**
  String get tapToCreateAlert;

  /// No description provided for @alertDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles de la Alerta'**
  String get alertDetails;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @viewOnMap.
  ///
  /// In es, this message translates to:
  /// **'Ver en el Mapa'**
  String get viewOnMap;

  /// No description provided for @anonymous.
  ///
  /// In es, this message translates to:
  /// **'Anónimo'**
  String get anonymous;

  /// No description provided for @locationShared.
  ///
  /// In es, this message translates to:
  /// **'Ubicación Compartida'**
  String get locationShared;

  /// No description provided for @locationNotShared.
  ///
  /// In es, this message translates to:
  /// **'Ubicación No Compartida'**
  String get locationNotShared;

  /// No description provided for @imagesAttached.
  ///
  /// In es, this message translates to:
  /// **'Imágenes Adjuntas'**
  String get imagesAttached;

  /// No description provided for @createdBy.
  ///
  /// In es, this message translates to:
  /// **'Creado por'**
  String get createdBy;

  /// No description provided for @createdAt.
  ///
  /// In es, this message translates to:
  /// **'Creado el'**
  String get createdAt;

  /// No description provided for @viewCount.
  ///
  /// In es, this message translates to:
  /// **'Vistas'**
  String get viewCount;

  /// No description provided for @respondToAlert.
  ///
  /// In es, this message translates to:
  /// **'Responder a la Alerta'**
  String get respondToAlert;

  /// No description provided for @shareAlert.
  ///
  /// In es, this message translates to:
  /// **'Compartir Alerta'**
  String get shareAlert;

  /// No description provided for @reportInappropriate.
  ///
  /// In es, this message translates to:
  /// **'Reportar como Inapropiado'**
  String get reportInappropriate;

  /// No description provided for @emergencyRobbery.
  ///
  /// In es, this message translates to:
  /// **'Robo Reportado'**
  String get emergencyRobbery;

  /// No description provided for @emergencyFire.
  ///
  /// In es, this message translates to:
  /// **'Incendio Reportado'**
  String get emergencyFire;

  /// No description provided for @emergencyAccident.
  ///
  /// In es, this message translates to:
  /// **'Accidente Reportado'**
  String get emergencyAccident;

  /// No description provided for @emergencyStreetEscort.
  ///
  /// In es, this message translates to:
  /// **'Acompañamiento Solicitado'**
  String get emergencyStreetEscort;

  /// No description provided for @emergencyUnsafety.
  ///
  /// In es, this message translates to:
  /// **'Zona Insegura'**
  String get emergencyUnsafety;

  /// No description provided for @emergencyPhysicalRisk.
  ///
  /// In es, this message translates to:
  /// **'Riesgo Físico'**
  String get emergencyPhysicalRisk;

  /// No description provided for @emergencyPublicServices.
  ///
  /// In es, this message translates to:
  /// **'Emergencia Servicios Públicos'**
  String get emergencyPublicServices;

  /// No description provided for @emergencyVial.
  ///
  /// In es, this message translates to:
  /// **'Emergencia Vial'**
  String get emergencyVial;

  /// No description provided for @emergencyAssistance.
  ///
  /// In es, this message translates to:
  /// **'Asistencia Necesaria'**
  String get emergencyAssistance;

  /// No description provided for @emergencyGeneral.
  ///
  /// In es, this message translates to:
  /// **'Emergencia General'**
  String get emergencyGeneral;

  /// No description provided for @alertNotification.
  ///
  /// In es, this message translates to:
  /// **'🚨 Alerta de Emergencia'**
  String get alertNotification;

  /// No description provided for @locationIncluded.
  ///
  /// In es, this message translates to:
  /// **'📍 Ubicación incluida'**
  String get locationIncluded;

  /// No description provided for @anonymousReport.
  ///
  /// In es, this message translates to:
  /// **'👤 Reporte anónimo'**
  String get anonymousReport;

  /// No description provided for @guardianActive.
  ///
  /// In es, this message translates to:
  /// **'🛡️ Guardian Protección Activa'**
  String get guardianActive;

  /// No description provided for @monitoringAlerts.
  ///
  /// In es, this message translates to:
  /// **'Monitoreando alertas de emergencia • Toca para abrir'**
  String get monitoringAlerts;

  /// No description provided for @backgroundService.
  ///
  /// In es, this message translates to:
  /// **'Servicio de seguridad en segundo plano'**
  String get backgroundService;

  /// No description provided for @newAlertInArea.
  ///
  /// In es, this message translates to:
  /// **'Nueva alerta en tu área'**
  String get newAlertInArea;

  /// No description provided for @emergencyNearby.
  ///
  /// In es, this message translates to:
  /// **'Emergencia cerca de ti'**
  String get emergencyNearby;

  /// No description provided for @helpNeeded.
  ///
  /// In es, this message translates to:
  /// **'Se necesita ayuda'**
  String get helpNeeded;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get login;

  /// No description provided for @register.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar Sesión'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Contraseña'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta?'**
  String get alreadyHaveAccount;

  /// No description provided for @signInWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar con Google'**
  String get signInWithGoogle;

  /// No description provided for @locationPermission.
  ///
  /// In es, this message translates to:
  /// **'Permiso de Ubicación'**
  String get locationPermission;

  /// No description provided for @notificationPermission.
  ///
  /// In es, this message translates to:
  /// **'Permiso de Notificaciones'**
  String get notificationPermission;

  /// No description provided for @cameraPermission.
  ///
  /// In es, this message translates to:
  /// **'Permiso de Cámara'**
  String get cameraPermission;

  /// No description provided for @permissionRequired.
  ///
  /// In es, this message translates to:
  /// **'Permiso Requerido'**
  String get permissionRequired;

  /// No description provided for @permissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Permiso Denegado'**
  String get permissionDenied;

  /// No description provided for @goToSettings.
  ///
  /// In es, this message translates to:
  /// **'Ir a Configuración'**
  String get goToSettings;

  /// No description provided for @allowAccess.
  ///
  /// In es, this message translates to:
  /// **'Permitir Acceso'**
  String get allowAccess;

  /// No description provided for @errorOccurred.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un error'**
  String get errorOccurred;

  /// No description provided for @tryAgain.
  ///
  /// In es, this message translates to:
  /// **'Intentar de nuevo'**
  String get tryAgain;

  /// No description provided for @networkError.
  ///
  /// In es, this message translates to:
  /// **'Error de red'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In es, this message translates to:
  /// **'Error del servidor'**
  String get serverError;

  /// No description provided for @unknownError.
  ///
  /// In es, this message translates to:
  /// **'Error desconocido'**
  String get unknownError;

  /// No description provided for @profileInfo.
  ///
  /// In es, this message translates to:
  /// **'Aquí irá tu información de perfil'**
  String get profileInfo;

  /// No description provided for @alertType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de Alerta'**
  String get alertType;

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @location.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get location;

  /// No description provided for @alertLocation.
  ///
  /// In es, this message translates to:
  /// **'📍 Ubicación de la Alerta'**
  String get alertLocation;

  /// No description provided for @additionalInfo.
  ///
  /// In es, this message translates to:
  /// **'Información Adicional'**
  String get additionalInfo;

  /// No description provided for @identifiedReport.
  ///
  /// In es, this message translates to:
  /// **'Reporte Identificado'**
  String get identifiedReport;

  /// No description provided for @viewedBy.
  ///
  /// In es, this message translates to:
  /// **'Visto por'**
  String get viewedBy;

  /// No description provided for @people.
  ///
  /// In es, this message translates to:
  /// **'personas'**
  String get people;

  /// No description provided for @person.
  ///
  /// In es, this message translates to:
  /// **'persona'**
  String get person;

  /// No description provided for @reportedBy.
  ///
  /// In es, this message translates to:
  /// **'Reportado por'**
  String get reportedBy;

  /// No description provided for @images.
  ///
  /// In es, this message translates to:
  /// **'Imágenes'**
  String get images;

  /// No description provided for @errorLoadingImage.
  ///
  /// In es, this message translates to:
  /// **'Error cargando imagen'**
  String get errorLoadingImage;

  /// No description provided for @respond.
  ///
  /// In es, this message translates to:
  /// **'Responder'**
  String get respond;

  /// No description provided for @sendingAlert.
  ///
  /// In es, this message translates to:
  /// **'Enviando alerta...'**
  String get sendingAlert;

  /// No description provided for @alertSent.
  ///
  /// In es, this message translates to:
  /// **'Alerta Enviada'**
  String get alertSent;

  /// No description provided for @alertSentToCommunity.
  ///
  /// In es, this message translates to:
  /// **'La alerta de emergencia ha sido enviada a la comunidad'**
  String get alertSentToCommunity;

  /// No description provided for @errorSendingAlert.
  ///
  /// In es, this message translates to:
  /// **'Error enviando alerta. Por favor intenta de nuevo'**
  String get errorSendingAlert;

  /// No description provided for @confirmEmergencyReport.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres reportar esta emergencia? Esto notificará inmediatamente a la comunidad y guardianes cercanos'**
  String get confirmEmergencyReport;

  /// No description provided for @actionCannotBeUndone.
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer. La comunidad será notificada inmediatamente'**
  String get actionCannotBeUndone;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @sendAlert.
  ///
  /// In es, this message translates to:
  /// **'Enviar Alerta'**
  String get sendAlert;

  /// No description provided for @reportSent.
  ///
  /// In es, this message translates to:
  /// **'Reporte Enviado'**
  String get reportSent;

  /// No description provided for @emergencyReportedToCommunity.
  ///
  /// In es, this message translates to:
  /// **'La emergencia ha sido reportada a la comunidad'**
  String get emergencyReportedToCommunity;

  /// No description provided for @drag.
  ///
  /// In es, this message translates to:
  /// **'ARRASTRAR'**
  String get drag;

  /// No description provided for @help.
  ///
  /// In es, this message translates to:
  /// **'AYUDA'**
  String get help;

  /// No description provided for @emergencyButton.
  ///
  /// In es, this message translates to:
  /// **'Botón de Emergencia'**
  String get emergencyButton;

  /// No description provided for @dragForEmergencyTypes.
  ///
  /// In es, this message translates to:
  /// **'Arrastra en cualquier dirección para ver tipos de emergencia en tiempo real'**
  String get dragForEmergencyTypes;

  /// No description provided for @emergencyTypes.
  ///
  /// In es, this message translates to:
  /// **'Tipos de Emergencia'**
  String get emergencyTypes;

  /// No description provided for @selectEmergencyType.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el tipo de emergencia'**
  String get selectEmergencyType;

  /// No description provided for @confirmReport.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Reporte'**
  String get confirmReport;

  /// No description provided for @reportEmergency.
  ///
  /// In es, this message translates to:
  /// **'Reportar Emergencia'**
  String get reportEmergency;

  /// No description provided for @unknown.
  ///
  /// In es, this message translates to:
  /// **'DESCONOCIDO'**
  String get unknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
