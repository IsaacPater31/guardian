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

  /// No description provided for @emergencyHealth.
  ///
  /// In es, this message translates to:
  /// **'Sanitaria'**
  String get emergencyHealth;

  /// No description provided for @emergencyHomeHelp.
  ///
  /// In es, this message translates to:
  /// **'Ayuda en Casa'**
  String get emergencyHomeHelp;

  /// No description provided for @emergencyPolice.
  ///
  /// In es, this message translates to:
  /// **'Policía'**
  String get emergencyPolice;

  /// No description provided for @emergencyFireNew.
  ///
  /// In es, this message translates to:
  /// **'Bomberos'**
  String get emergencyFireNew;

  /// No description provided for @emergencySecurityBreach.
  ///
  /// In es, this message translates to:
  /// **'Brecha de seguridad'**
  String get emergencySecurityBreach;

  /// No description provided for @emergencyAccompaniment.
  ///
  /// In es, this message translates to:
  /// **'Acompañamiento'**
  String get emergencyAccompaniment;

  /// No description provided for @emergencyEnvironmental.
  ///
  /// In es, this message translates to:
  /// **'Ambiental'**
  String get emergencyEnvironmental;

  /// No description provided for @emergencyRoadEmergency.
  ///
  /// In es, this message translates to:
  /// **'Emergencia Vial'**
  String get emergencyRoadEmergency;

  /// No description provided for @emergencyHarassment.
  ///
  /// In es, this message translates to:
  /// **'Acoso'**
  String get emergencyHarassment;

  /// No description provided for @emergencyUrgency.
  ///
  /// In es, this message translates to:
  /// **'Urgencia'**
  String get emergencyUrgency;

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

  /// No description provided for @alertDetailMainTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo principal'**
  String get alertDetailMainTypeLabel;

  /// No description provided for @alertDetailSubtypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Detalle / subtipo'**
  String get alertDetailSubtypeLabel;

  /// No description provided for @alertDetailNoSubtype.
  ///
  /// In es, this message translates to:
  /// **'Sin detalle específico'**
  String get alertDetailNoSubtype;

  /// No description provided for @alertDetailDatetimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha y hora'**
  String get alertDetailDatetimeLabel;

  /// No description provided for @alertDetailMessageLabel.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get alertDetailMessageLabel;

  /// No description provided for @alertDetailAnonymityHeading.
  ///
  /// In es, this message translates to:
  /// **'Anonimato'**
  String get alertDetailAnonymityHeading;

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

  /// No description provided for @alertSendingToOne.
  ///
  /// In es, this message translates to:
  /// **'Enviando a 1 comunidad...'**
  String get alertSendingToOne;

  /// No description provided for @alertSendingToMany.
  ///
  /// In es, this message translates to:
  /// **'Enviando a {count} comunidades...'**
  String alertSendingToMany(int count);

  /// No description provided for @alertSentToOneCommunity.
  ///
  /// In es, this message translates to:
  /// **'Enviada a 1 comunidad'**
  String get alertSentToOneCommunity;

  /// No description provided for @alertSentToManyCommunities.
  ///
  /// In es, this message translates to:
  /// **'Enviada a {count} comunidades'**
  String alertSentToManyCommunities(int count);

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

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueAction;

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

  /// No description provided for @loadingCommunities.
  ///
  /// In es, this message translates to:
  /// **'Cargando comunidades...'**
  String get loadingCommunities;

  /// No description provided for @communitiesLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las comunidades. Intenta de nuevo.'**
  String get communitiesLoadError;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @createCommunity.
  ///
  /// In es, this message translates to:
  /// **'Crear Comunidad'**
  String get createCommunity;

  /// No description provided for @noCommunities.
  ///
  /// In es, this message translates to:
  /// **'No tienes comunidades'**
  String get noCommunities;

  /// No description provided for @entitiesAppearHere.
  ///
  /// In es, this message translates to:
  /// **'Las entidades aparecerán aquí automáticamente'**
  String get entitiesAppearHere;

  /// No description provided for @searchCommunities.
  ///
  /// In es, this message translates to:
  /// **'Buscar comunidades...'**
  String get searchCommunities;

  /// No description provided for @officialEntity.
  ///
  /// In es, this message translates to:
  /// **'Entidad Oficial'**
  String get officialEntity;

  /// No description provided for @communityCreatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Comunidad creada exitosamente'**
  String get communityCreatedSuccess;

  /// No description provided for @errorCreatingCommunity.
  ///
  /// In es, this message translates to:
  /// **'Error creando la comunidad'**
  String get errorCreatingCommunity;

  /// No description provided for @createNewCommunity.
  ///
  /// In es, this message translates to:
  /// **'Crear Nueva Comunidad'**
  String get createNewCommunity;

  /// No description provided for @communityNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la comunidad *'**
  String get communityNameRequired;

  /// No description provided for @communityNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Vecinos del Barrio'**
  String get communityNameHint;

  /// No description provided for @nameRequired.
  ///
  /// In es, this message translates to:
  /// **'El nombre es requerido'**
  String get nameRequired;

  /// No description provided for @nameMinLength.
  ///
  /// In es, this message translates to:
  /// **'El nombre debe tener al menos 3 caracteres'**
  String get nameMinLength;

  /// No description provided for @descriptionOptional.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get descriptionOptional;

  /// No description provided for @descriptionHint.
  ///
  /// In es, this message translates to:
  /// **'Describe el propósito de la comunidad'**
  String get descriptionHint;

  /// No description provided for @allowForwardToEntities.
  ///
  /// In es, this message translates to:
  /// **'Permitir reenvío a entidades'**
  String get allowForwardToEntities;

  /// No description provided for @allowForwardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Los miembros podrán reenviar alertas a entidades oficiales'**
  String get allowForwardSubtitle;

  /// No description provided for @create.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get create;

  /// No description provided for @joinWithLink.
  ///
  /// In es, this message translates to:
  /// **'Unirse con link'**
  String get joinWithLink;

  /// No description provided for @entityOfficialMessage.
  ///
  /// In es, this message translates to:
  /// **'{name} es una entidad oficial'**
  String entityOfficialMessage(String name);

  /// No description provided for @alertsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las alertas. Desliza hacia abajo para reintentar.'**
  String get alertsLoadError;

  /// No description provided for @alertsUpdateError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron actualizar las alertas. Intenta de nuevo.'**
  String get alertsUpdateError;

  /// No description provided for @alertsLoadErrorFeed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las alertas'**
  String get alertsLoadErrorFeed;

  /// No description provided for @checkConnectionRetry.
  ///
  /// In es, this message translates to:
  /// **'Comprueba tu conexión y vuelve a intentarlo.'**
  String get checkConnectionRetry;

  /// No description provided for @timeNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get timeNow;

  /// No description provided for @timeJustNow.
  ///
  /// In es, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeYesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get timeYesterday;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {n} min'**
  String timeMinutesAgo(int n);

  /// No description provided for @timeHoursAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {n} h'**
  String timeHoursAgo(int n);

  /// No description provided for @timeDaysAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {n} días'**
  String timeDaysAgo(int n);

  /// No description provided for @timeMinutesAgoShort.
  ///
  /// In es, this message translates to:
  /// **'{n}m ago'**
  String timeMinutesAgoShort(int n);

  /// No description provided for @timeHoursAgoShort.
  ///
  /// In es, this message translates to:
  /// **'{n}h ago'**
  String timeHoursAgoShort(int n);

  /// No description provided for @timeDaysAgoShort.
  ///
  /// In es, this message translates to:
  /// **'{n}d ago'**
  String timeDaysAgoShort(int n);

  /// No description provided for @timeYesterdayEn.
  ///
  /// In es, this message translates to:
  /// **'Yesterday'**
  String get timeYesterdayEn;

  /// No description provided for @safetyPriority.
  ///
  /// In es, this message translates to:
  /// **'Tu seguridad es nuestra prioridad'**
  String get safetyPriority;

  /// No description provided for @everythingQuiet.
  ///
  /// In es, this message translates to:
  /// **'Todo está tranquilo en tu zona'**
  String get everythingQuiet;

  /// No description provided for @locationTag.
  ///
  /// In es, this message translates to:
  /// **'📍 Ubicación'**
  String get locationTag;

  /// No description provided for @anonymousTag.
  ///
  /// In es, this message translates to:
  /// **'👤 Anónimo'**
  String get anonymousTag;

  /// No description provided for @viewAction.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get viewAction;

  /// No description provided for @comingSoon.
  ///
  /// In es, this message translates to:
  /// **'Funcionalidad próximamente'**
  String get comingSoon;

  /// No description provided for @editCommunity.
  ///
  /// In es, this message translates to:
  /// **'Editar Comunidad'**
  String get editCommunity;

  /// No description provided for @communityNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la comunidad'**
  String get communityNameLabel;

  /// No description provided for @minChars.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 3 caracteres'**
  String get minChars;

  /// No description provided for @describeYourCommunity.
  ///
  /// In es, this message translates to:
  /// **'Describe tu comunidad'**
  String get describeYourCommunity;

  /// No description provided for @communityIcon.
  ///
  /// In es, this message translates to:
  /// **'Icono de la comunidad'**
  String get communityIcon;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @communityUpdated.
  ///
  /// In es, this message translates to:
  /// **'Comunidad actualizada'**
  String get communityUpdated;

  /// No description provided for @errorUpdatingCommunity.
  ///
  /// In es, this message translates to:
  /// **'Error actualizando la comunidad'**
  String get errorUpdatingCommunity;

  /// No description provided for @inviteLink.
  ///
  /// In es, this message translates to:
  /// **'Link de Invitación'**
  String get inviteLink;

  /// No description provided for @shareInviteLinkText.
  ///
  /// In es, this message translates to:
  /// **'Comparte este link para invitar a otros:'**
  String get shareInviteLinkText;

  /// No description provided for @linkExpiresHours.
  ///
  /// In es, this message translates to:
  /// **'El link expira en 12 horas'**
  String get linkExpiresHours;

  /// No description provided for @copy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @joinCommunityShareText.
  ///
  /// In es, this message translates to:
  /// **'¡Únete a {name} en Guardian!'**
  String joinCommunityShareText(String name);

  /// No description provided for @invitationTo.
  ///
  /// In es, this message translates to:
  /// **'Invitación a {name} - Guardian'**
  String invitationTo(String name);

  /// No description provided for @linkCopied.
  ///
  /// In es, this message translates to:
  /// **'Link copiado al portapapeles'**
  String get linkCopied;

  /// No description provided for @errorGeneratingLink.
  ///
  /// In es, this message translates to:
  /// **'Error generando link de invitación'**
  String get errorGeneratingLink;

  /// No description provided for @communitySection.
  ///
  /// In es, this message translates to:
  /// **'COMUNIDAD'**
  String get communitySection;

  /// No description provided for @viewMembers.
  ///
  /// In es, this message translates to:
  /// **'Ver Miembros'**
  String get viewMembers;

  /// No description provided for @allMembers.
  ///
  /// In es, this message translates to:
  /// **'Todos los integrantes'**
  String get allMembers;

  /// No description provided for @reports.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get reports;

  /// No description provided for @pendingCount.
  ///
  /// In es, this message translates to:
  /// **'{n} pendiente{plural}'**
  String pendingCount(int n, String plural);

  /// No description provided for @noPendingReports.
  ///
  /// In es, this message translates to:
  /// **'Sin reportes pendientes'**
  String get noPendingReports;

  /// No description provided for @addMembersSection.
  ///
  /// In es, this message translates to:
  /// **'AGREGAR MIEMBROS'**
  String get addMembersSection;

  /// No description provided for @searchAndAdd.
  ///
  /// In es, this message translates to:
  /// **'Buscar y agregar'**
  String get searchAndAdd;

  /// No description provided for @addByEmailOrName.
  ///
  /// In es, this message translates to:
  /// **'Agrega miembros por email o nombre'**
  String get addByEmailOrName;

  /// No description provided for @generateInviteLink.
  ///
  /// In es, this message translates to:
  /// **'Generar link de invitación'**
  String get generateInviteLink;

  /// No description provided for @generating.
  ///
  /// In es, this message translates to:
  /// **'Generando...'**
  String get generating;

  /// No description provided for @shareToInvite.
  ///
  /// In es, this message translates to:
  /// **'Comparte para invitar a otros'**
  String get shareToInvite;

  /// No description provided for @administrationSection.
  ///
  /// In es, this message translates to:
  /// **'ADMINISTRACIÓN'**
  String get administrationSection;

  /// No description provided for @forwardToEntities.
  ///
  /// In es, this message translates to:
  /// **'Reenvío a entidades'**
  String get forwardToEntities;

  /// No description provided for @alertsCanBeForwarded.
  ///
  /// In es, this message translates to:
  /// **'Alertas pueden reenviarse a entidades oficiales'**
  String get alertsCanBeForwarded;

  /// No description provided for @forwardEnabled.
  ///
  /// In es, this message translates to:
  /// **'Reenvío a entidades habilitado'**
  String get forwardEnabled;

  /// No description provided for @forwardDisabled.
  ///
  /// In es, this message translates to:
  /// **'Reenvío a entidades deshabilitado'**
  String get forwardDisabled;

  /// No description provided for @onlyCreatorCanModify.
  ///
  /// In es, this message translates to:
  /// **'Solo el creador puede modificar la configuración'**
  String get onlyCreatorCanModify;

  /// No description provided for @errorUpdatingConfig.
  ///
  /// In es, this message translates to:
  /// **'Error actualizando configuración'**
  String get errorUpdatingConfig;

  /// No description provided for @dangerZone.
  ///
  /// In es, this message translates to:
  /// **'ZONA DE PELIGRO'**
  String get dangerZone;

  /// No description provided for @deleteCommunityAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar comunidad'**
  String get deleteCommunityAction;

  /// No description provided for @deletePermanently.
  ///
  /// In es, this message translates to:
  /// **'Elimina permanentemente'**
  String get deletePermanently;

  /// No description provided for @leaveCommunity.
  ///
  /// In es, this message translates to:
  /// **'Abandonar comunidad'**
  String get leaveCommunity;

  /// No description provided for @stopReceivingAlerts.
  ///
  /// In es, this message translates to:
  /// **'Dejarás de recibir alertas'**
  String get stopReceivingAlerts;

  /// No description provided for @deleteCommunityTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar Comunidad'**
  String get deleteCommunityTitle;

  /// No description provided for @irreversibleAction.
  ///
  /// In es, this message translates to:
  /// **'Esta acción es irreversible y eliminará:'**
  String get irreversibleAction;

  /// No description provided for @allMembersBullet.
  ///
  /// In es, this message translates to:
  /// **'Todos los miembros'**
  String get allMembersBullet;

  /// No description provided for @allInvitationsBullet.
  ///
  /// In es, this message translates to:
  /// **'Todas las invitaciones'**
  String get allInvitationsBullet;

  /// No description provided for @entireCommunityBullet.
  ///
  /// In es, this message translates to:
  /// **'La comunidad por completo'**
  String get entireCommunityBullet;

  /// No description provided for @alertsRemainHistory.
  ///
  /// In es, this message translates to:
  /// **'Las alertas enviadas permanecerán en el historial.'**
  String get alertsRemainHistory;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @leaveCommunityTitle.
  ///
  /// In es, this message translates to:
  /// **'Abandonar Comunidad'**
  String get leaveCommunityTitle;

  /// No description provided for @leaveConfirmation.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro? No podrás ver las alertas ni participar en ella.'**
  String get leaveConfirmation;

  /// No description provided for @leave.
  ///
  /// In es, this message translates to:
  /// **'Abandonar'**
  String get leave;

  /// No description provided for @communityDeleted.
  ///
  /// In es, this message translates to:
  /// **'Comunidad eliminada'**
  String get communityDeleted;

  /// No description provided for @errorDeletingCommunity.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar la comunidad'**
  String get errorDeletingCommunity;

  /// No description provided for @leftCommunity.
  ///
  /// In es, this message translates to:
  /// **'Has abandonado la comunidad'**
  String get leftCommunity;

  /// No description provided for @errorLoadingCommunity.
  ///
  /// In es, this message translates to:
  /// **'Error cargando comunidad'**
  String get errorLoadingCommunity;

  /// No description provided for @configurationTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get configurationTitle;

  /// No description provided for @membersTitle.
  ///
  /// In es, this message translates to:
  /// **'Miembros'**
  String get membersTitle;

  /// No description provided for @memberCount.
  ///
  /// In es, this message translates to:
  /// **'{n} {label}'**
  String memberCount(int n, String label);

  /// No description provided for @memberSingular.
  ///
  /// In es, this message translates to:
  /// **'miembro'**
  String get memberSingular;

  /// No description provided for @memberPlural.
  ///
  /// In es, this message translates to:
  /// **'miembros'**
  String get memberPlural;

  /// No description provided for @adminLabel.
  ///
  /// In es, this message translates to:
  /// **'Admin'**
  String get adminLabel;

  /// No description provided for @officialLabel.
  ///
  /// In es, this message translates to:
  /// **'Oficial'**
  String get officialLabel;

  /// No description provided for @memberLabel.
  ///
  /// In es, this message translates to:
  /// **'Miembro'**
  String get memberLabel;

  /// No description provided for @promoteToAdmin.
  ///
  /// In es, this message translates to:
  /// **'Promover a Administrador'**
  String get promoteToAdmin;

  /// No description provided for @promoteQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres hacer administrador a {name}? Podrá gestionar miembros y la configuración de la comunidad.'**
  String promoteQuestion(String name);

  /// No description provided for @promote.
  ///
  /// In es, this message translates to:
  /// **'Promover'**
  String get promote;

  /// No description provided for @expelMember.
  ///
  /// In es, this message translates to:
  /// **'Expulsar Miembro'**
  String get expelMember;

  /// No description provided for @expelConfirmation.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres expulsar a {name}? No podrá ver alertas de esta comunidad.'**
  String expelConfirmation(String name);

  /// No description provided for @expel.
  ///
  /// In es, this message translates to:
  /// **'Expulsar'**
  String get expel;

  /// No description provided for @reportUser.
  ///
  /// In es, this message translates to:
  /// **'Reportar a {name}'**
  String reportUser(String name);

  /// No description provided for @reportDescription.
  ///
  /// In es, this message translates to:
  /// **'Describe el motivo del reporte. Un administrador revisará tu solicitud.'**
  String get reportDescription;

  /// No description provided for @reportReasonHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe el motivo del reporte...'**
  String get reportReasonHint;

  /// No description provided for @sendReport.
  ///
  /// In es, this message translates to:
  /// **'Enviar Reporte'**
  String get sendReport;

  /// No description provided for @nowAdmin.
  ///
  /// In es, this message translates to:
  /// **'{name} ahora es administrador'**
  String nowAdmin(String name);

  /// No description provided for @errorPromoting.
  ///
  /// In es, this message translates to:
  /// **'Error al promover miembro'**
  String get errorPromoting;

  /// No description provided for @userExpelled.
  ///
  /// In es, this message translates to:
  /// **'{name} ha sido expulsado'**
  String userExpelled(String name);

  /// No description provided for @couldNotExpel.
  ///
  /// In es, this message translates to:
  /// **'No se pudo expulsar al miembro'**
  String get couldNotExpel;

  /// No description provided for @reportSentToAdmins.
  ///
  /// In es, this message translates to:
  /// **'Reporte enviado a los administradores'**
  String get reportSentToAdmins;

  /// No description provided for @errorSendingReport.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar el reporte'**
  String get errorSendingReport;

  /// No description provided for @addMember.
  ///
  /// In es, this message translates to:
  /// **'Agregar Miembro'**
  String get addMember;

  /// No description provided for @searchByEmailOrName.
  ///
  /// In es, this message translates to:
  /// **'Buscar por email o nombre...'**
  String get searchByEmailOrName;

  /// No description provided for @addingUser.
  ///
  /// In es, this message translates to:
  /// **'Agregando {name}...'**
  String addingUser(String name);

  /// No description provided for @memberAdded.
  ///
  /// In es, this message translates to:
  /// **'¡Miembro agregado!'**
  String get memberAdded;

  /// No description provided for @couldNotAdd.
  ///
  /// In es, this message translates to:
  /// **'No se pudo agregar'**
  String get couldNotAdd;

  /// No description provided for @noUsersFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron usuarios'**
  String get noUsersFound;

  /// No description provided for @verifyAndRetry.
  ///
  /// In es, this message translates to:
  /// **'Verifica el email o nombre e intenta de nuevo'**
  String get verifyAndRetry;

  /// No description provided for @minCharsToSearch.
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 2 caracteres para buscar'**
  String get minCharsToSearch;

  /// No description provided for @noMembers.
  ///
  /// In es, this message translates to:
  /// **'Sin miembros'**
  String get noMembers;

  /// No description provided for @noMembersFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron miembros en esta comunidad'**
  String get noMembersFound;

  /// No description provided for @thisIsYou.
  ///
  /// In es, this message translates to:
  /// **'Este eres tú'**
  String get thisIsYou;

  /// No description provided for @you.
  ///
  /// In es, this message translates to:
  /// **'(tú)'**
  String get you;

  /// No description provided for @makeAdmin.
  ///
  /// In es, this message translates to:
  /// **'Hacer Administrador'**
  String get makeAdmin;

  /// No description provided for @giveManagementPerms.
  ///
  /// In es, this message translates to:
  /// **'Dar permisos de gestión'**
  String get giveManagementPerms;

  /// No description provided for @removeFromCommunity.
  ///
  /// In es, this message translates to:
  /// **'Remover de la comunidad'**
  String get removeFromCommunity;

  /// No description provided for @report.
  ///
  /// In es, this message translates to:
  /// **'Reportar'**
  String get report;

  /// No description provided for @sendReportToAdmins.
  ///
  /// In es, this message translates to:
  /// **'Enviar reporte a los administradores'**
  String get sendReportToAdmins;

  /// No description provided for @adminCount.
  ///
  /// In es, this message translates to:
  /// **'{n} admin{plural}'**
  String adminCount(int n, String plural);

  /// No description provided for @communityLabel.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get communityLabel;

  /// No description provided for @noAlerts.
  ///
  /// In es, this message translates to:
  /// **'No hay alertas'**
  String get noAlerts;

  /// No description provided for @alertsAppearHere.
  ///
  /// In es, this message translates to:
  /// **'Las alertas aparecerán aquí cuando se envíen a esta comunidad'**
  String get alertsAppearHere;

  /// No description provided for @officialEntities.
  ///
  /// In es, this message translates to:
  /// **'Entidades Oficiales'**
  String get officialEntities;

  /// No description provided for @myCommunities.
  ///
  /// In es, this message translates to:
  /// **'Mis Comunidades'**
  String get myCommunities;

  /// No description provided for @noResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get noResults;

  /// No description provided for @communityCount.
  ///
  /// In es, this message translates to:
  /// **'{n} comunidad{plural}'**
  String communityCount(int n, String plural);

  /// No description provided for @official.
  ///
  /// In es, this message translates to:
  /// **'Oficial'**
  String get official;

  /// No description provided for @reportsTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get reportsTitle;

  /// No description provided for @pendingLabel.
  ///
  /// In es, this message translates to:
  /// **'{n} pendiente{plural}'**
  String pendingLabel(int n, String plural);

  /// No description provided for @allGood.
  ///
  /// In es, this message translates to:
  /// **'Todo en orden'**
  String get allGood;

  /// No description provided for @noPendingReportsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay reportes pendientes'**
  String get noPendingReportsEmpty;

  /// No description provided for @dismissReport.
  ///
  /// In es, this message translates to:
  /// **'Descartar Reporte'**
  String get dismissReport;

  /// No description provided for @dismissQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar el reporte contra {name}? El reporte será archivado.'**
  String dismissQuestion(String name);

  /// No description provided for @dismiss.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get dismiss;

  /// No description provided for @reportDismissed.
  ///
  /// In es, this message translates to:
  /// **'Reporte descartado'**
  String get reportDismissed;

  /// No description provided for @errorDismissingReport.
  ///
  /// In es, this message translates to:
  /// **'Error al descartar el reporte'**
  String get errorDismissingReport;

  /// No description provided for @expelFromReports.
  ///
  /// In es, this message translates to:
  /// **'Expulsar Miembro'**
  String get expelFromReports;

  /// No description provided for @expelFromReportsConfirmation.
  ///
  /// In es, this message translates to:
  /// **'¿Expulsar a {name} de la comunidad? Esta acción no se puede deshacer.'**
  String expelFromReportsConfirmation(String name);

  /// No description provided for @reportedByLabel.
  ///
  /// In es, this message translates to:
  /// **'Reportado por {name}'**
  String reportedByLabel(String name);

  /// No description provided for @reason.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get reason;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// No description provided for @alertsSection.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get alertsSection;

  /// No description provided for @quickAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas Rápidas'**
  String get quickAlerts;

  /// No description provided for @configQuickAlerts.
  ///
  /// In es, this message translates to:
  /// **'Configurar destinos de alertas rápidas'**
  String get configQuickAlerts;

  /// No description provided for @swipeAlertsConfig.
  ///
  /// In es, this message translates to:
  /// **'Alertas por Tipo'**
  String get swipeAlertsConfig;

  /// No description provided for @configSwipeAlerts.
  ///
  /// In es, this message translates to:
  /// **'Configurar comunidades por tipo de alerta'**
  String get configSwipeAlerts;

  /// No description provided for @swipeAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Alertas por Tipo'**
  String get swipeAlertsTitle;

  /// No description provided for @swipeAlertsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Define a qué comunidades se enviará cada tipo de alerta al arrastrar el botón. Si no hay ninguna configurada, se te pedirá al momento de enviar.'**
  String get swipeAlertsSubtitle;

  /// No description provided for @noDefaultCommunity.
  ///
  /// In es, this message translates to:
  /// **'Sin comunidad por defecto'**
  String get noDefaultCommunity;

  /// No description provided for @tapToConfigureType.
  ///
  /// In es, this message translates to:
  /// **'Toca para configurar'**
  String get tapToConfigureType;

  /// No description provided for @defaultCommunitiesFor.
  ///
  /// In es, this message translates to:
  /// **'Comunidades para {type}'**
  String defaultCommunitiesFor(String type);

  /// No description provided for @generalSection.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get generalSection;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @appInfo.
  ///
  /// In es, this message translates to:
  /// **'Información de la aplicación'**
  String get appInfo;

  /// No description provided for @quickAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Alertas Rápidas'**
  String get quickAlertsTitle;

  /// No description provided for @quickAlertsConfig.
  ///
  /// In es, this message translates to:
  /// **'Configuración de Alertas Rápidas'**
  String get quickAlertsConfig;

  /// No description provided for @selectCommunitiesForQuickAlerts.
  ///
  /// In es, this message translates to:
  /// **'Selecciona a qué comunidades se enviarán las alertas rápidas cuando presiones el botón de emergencia.'**
  String get selectCommunitiesForQuickAlerts;

  /// No description provided for @defaultAllEntities.
  ///
  /// In es, this message translates to:
  /// **'Por defecto: todas las entidades'**
  String get defaultAllEntities;

  /// No description provided for @saveConfig.
  ///
  /// In es, this message translates to:
  /// **'Guardar Configuración'**
  String get saveConfig;

  /// No description provided for @configSaved.
  ///
  /// In es, this message translates to:
  /// **'✅ Configuración guardada'**
  String get configSaved;

  /// No description provided for @errorSavingConfig.
  ///
  /// In es, this message translates to:
  /// **'❌ Error guardando configuración'**
  String get errorSavingConfig;

  /// No description provided for @joinCommunityTitle.
  ///
  /// In es, this message translates to:
  /// **'Unirse a Comunidad'**
  String get joinCommunityTitle;

  /// No description provided for @joinACommunity.
  ///
  /// In es, this message translates to:
  /// **'Únete a una comunidad'**
  String get joinACommunity;

  /// No description provided for @enterInviteLinkOrCode.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el link o código de invitación que te compartieron'**
  String get enterInviteLinkOrCode;

  /// No description provided for @inviteLinkOrCode.
  ///
  /// In es, this message translates to:
  /// **'Link o código de invitación'**
  String get inviteLinkOrCode;

  /// No description provided for @inviteLinkHint.
  ///
  /// In es, this message translates to:
  /// **'guardian.app/join/xxx o código'**
  String get inviteLinkHint;

  /// No description provided for @invalidToken.
  ///
  /// In es, this message translates to:
  /// **'Token o link inválido'**
  String get invalidToken;

  /// No description provided for @inviteExpiredOrInvalid.
  ///
  /// In es, this message translates to:
  /// **'Invitación no válida o expirada'**
  String get inviteExpiredOrInvalid;

  /// No description provided for @invalidInviteData.
  ///
  /// In es, this message translates to:
  /// **'Datos de invitación inválidos'**
  String get invalidInviteData;

  /// No description provided for @communityNotFound.
  ///
  /// In es, this message translates to:
  /// **'Comunidad no encontrada'**
  String get communityNotFound;

  /// No description provided for @errorValidatingInvite.
  ///
  /// In es, this message translates to:
  /// **'Error validando invitación'**
  String get errorValidatingInvite;

  /// No description provided for @validateInvitation.
  ///
  /// In es, this message translates to:
  /// **'Validar invitación'**
  String get validateInvitation;

  /// No description provided for @joining.
  ///
  /// In es, this message translates to:
  /// **'Uniéndose...'**
  String get joining;

  /// No description provided for @joinCommunityAction.
  ///
  /// In es, this message translates to:
  /// **'Unirse a la comunidad'**
  String get joinCommunityAction;

  /// No description provided for @joinedCommunityName.
  ///
  /// In es, this message translates to:
  /// **'¡Te has unido a {name}!'**
  String joinedCommunityName(String name);

  /// No description provided for @joinedCommunity.
  ///
  /// In es, this message translates to:
  /// **'¡Te has unido a la comunidad!'**
  String get joinedCommunity;

  /// No description provided for @couldNotJoinExpired.
  ///
  /// In es, this message translates to:
  /// **'No se pudo unir a la comunidad. El link puede haber expirado.'**
  String get couldNotJoinExpired;

  /// No description provided for @errorJoining.
  ///
  /// In es, this message translates to:
  /// **'Error al unirse a la comunidad'**
  String get errorJoining;

  /// No description provided for @howItWorks.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo funciona?'**
  String get howItWorks;

  /// No description provided for @howItWorksDetails.
  ///
  /// In es, this message translates to:
  /// **'• Los links de invitación expiran en 12 horas\n• Puedes pegar el link completo o solo el código\n• Una vez unido, recibirás las alertas de la comunidad'**
  String get howItWorksDetails;

  /// No description provided for @validInvitation.
  ///
  /// In es, this message translates to:
  /// **'Invitación válida'**
  String get validInvitation;

  /// No description provided for @enterLinkOrCode.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un link o código'**
  String get enterLinkOrCode;

  /// No description provided for @mapRefreshing.
  ///
  /// In es, this message translates to:
  /// **'Actualizando...'**
  String get mapRefreshing;

  /// No description provided for @anonymousReportMap.
  ///
  /// In es, this message translates to:
  /// **'Reporte Anónimo'**
  String get anonymousReportMap;

  /// No description provided for @reportedByMap.
  ///
  /// In es, this message translates to:
  /// **'Reportado por:'**
  String get reportedByMap;

  /// No description provided for @unknownUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario Desconocido'**
  String get unknownUser;

  /// No description provided for @justNowMap.
  ///
  /// In es, this message translates to:
  /// **'Justo ahora'**
  String get justNowMap;

  /// No description provided for @minutesAgoMap.
  ///
  /// In es, this message translates to:
  /// **'Hace {n} minutos'**
  String minutesAgoMap(int n);

  /// No description provided for @hoursAgoMap.
  ///
  /// In es, this message translates to:
  /// **'Hace {n} horas'**
  String hoursAgoMap(int n);

  /// No description provided for @daysAgoMap.
  ///
  /// In es, this message translates to:
  /// **'Hace {n} días'**
  String daysAgoMap(int n);

  /// No description provided for @alertStatusPendingShort.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get alertStatusPendingShort;

  /// No description provided for @alertStatusAttendedShort.
  ///
  /// In es, this message translates to:
  /// **'Atendida'**
  String get alertStatusAttendedShort;

  /// No description provided for @alertStatusNotAttendedShort.
  ///
  /// In es, this message translates to:
  /// **'No atendida'**
  String get alertStatusNotAttendedShort;

  /// No description provided for @alertStatusSectionHeading.
  ///
  /// In es, this message translates to:
  /// **'Estado de la alerta'**
  String get alertStatusSectionHeading;

  /// No description provided for @alertStatusPendingLong.
  ///
  /// In es, this message translates to:
  /// **'Esta alerta está pendiente de atención.'**
  String get alertStatusPendingLong;

  /// No description provided for @alertStatusAttendedLong.
  ///
  /// In es, this message translates to:
  /// **'Esta alerta fue marcada como atendida por las autoridades.'**
  String get alertStatusAttendedLong;

  /// No description provided for @communitiesHeadingShort.
  ///
  /// In es, this message translates to:
  /// **'Comunidades'**
  String get communitiesHeadingShort;

  /// No description provided for @changeAlertStatusTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar estado'**
  String get changeAlertStatusTitle;

  /// No description provided for @onlyOfficialsCanChangeStatus.
  ///
  /// In es, this message translates to:
  /// **'Solo los oficiales pueden cambiar el estado.'**
  String get onlyOfficialsCanChangeStatus;

  /// No description provided for @errorUpdatingAlertStatus.
  ///
  /// In es, this message translates to:
  /// **'Error al actualizar el estado'**
  String get errorUpdatingAlertStatus;

  /// No description provided for @communityFeedEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin alertas por ahora'**
  String get communityFeedEmptyTitle;

  /// No description provided for @communityFeedEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Las alertas de esta comunidad aparecerán aquí'**
  String get communityFeedEmptySubtitle;

  /// No description provided for @addedToCommunityBody.
  ///
  /// In es, this message translates to:
  /// **'Te agregaron a {name}'**
  String addedToCommunityBody(String name);

  /// No description provided for @quickAddMember.
  ///
  /// In es, this message translates to:
  /// **'Agregar miembro'**
  String get quickAddMember;

  /// No description provided for @swipeAlertsByTypeTitle.
  ///
  /// In es, this message translates to:
  /// **'Alertas por tipo'**
  String get swipeAlertsByTypeTitle;

  /// No description provided for @swipeAlertsByTypeBanner.
  ///
  /// In es, this message translates to:
  /// **'Define a qué comunidades se enviará cada tipo de alerta cuando arrastres el botón. Si no configuras un tipo, se te pedirá al enviar.'**
  String get swipeAlertsByTypeBanner;

  /// No description provided for @swipeAlertsSectionLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipos de alerta'**
  String get swipeAlertsSectionLabel;

  /// No description provided for @swipeConfigSaved.
  ///
  /// In es, this message translates to:
  /// **'Configuración guardada'**
  String get swipeConfigSaved;

  /// No description provided for @swipeConfigSavePartial.
  ///
  /// In es, this message translates to:
  /// **'Algunos tipos no se guardaron'**
  String get swipeConfigSavePartial;

  /// No description provided for @unknownCommunityFallback.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get unknownCommunityFallback;

  /// No description provided for @adminOnlyAddMembers.
  ///
  /// In es, this message translates to:
  /// **'Solo un administrador de la comunidad puede agregar miembros.'**
  String get adminOnlyAddMembers;

  /// No description provided for @identifiedAlert.
  ///
  /// In es, this message translates to:
  /// **'Identificada'**
  String get identifiedAlert;

  /// No description provided for @myAlertsStatisticsSectionLabel.
  ///
  /// In es, this message translates to:
  /// **'Historial personal'**
  String get myAlertsStatisticsSectionLabel;

  /// No description provided for @myAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis alertas'**
  String get myAlertsTitle;

  /// No description provided for @myAlertsProfileSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de alertas que enviaste'**
  String get myAlertsProfileSubtitle;

  /// No description provided for @myAlertsEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin alertas aún'**
  String get myAlertsEmptyTitle;

  /// No description provided for @myAlertsEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Las alertas que envíes desde el botón principal aparecerán aquí.'**
  String get myAlertsEmptySubtitle;

  /// No description provided for @myAlertsEmptyFilteredTitle.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con los filtros'**
  String get myAlertsEmptyFilteredTitle;

  /// No description provided for @myAlertsEmptyFilteredSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Prueba a limpiar filtros o ajustar la búsqueda.'**
  String get myAlertsEmptyFilteredSubtitle;

  /// No description provided for @myAlertsFilters.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get myAlertsFilters;

  /// No description provided for @myAlertsApplyFilters.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get myAlertsApplyFilters;

  /// No description provided for @myAlertsClearFilters.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get myAlertsClearFilters;

  /// No description provided for @myAlertsAllCommunities.
  ///
  /// In es, this message translates to:
  /// **'Todas las comunidades'**
  String get myAlertsAllCommunities;

  /// No description provided for @myAlertsEngagementFilter.
  ///
  /// In es, this message translates to:
  /// **'Vistas'**
  String get myAlertsEngagementFilter;

  /// No description provided for @myAlertsEngagementAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get myAlertsEngagementAll;

  /// No description provided for @myAlertsEngagementSeen.
  ///
  /// In es, this message translates to:
  /// **'Con vistas'**
  String get myAlertsEngagementSeen;

  /// No description provided for @myAlertsEngagementNone.
  ///
  /// In es, this message translates to:
  /// **'Sin vistas'**
  String get myAlertsEngagementNone;

  /// No description provided for @myAlertsSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en mensaje o tipo'**
  String get myAlertsSearchHint;

  /// No description provided for @myAlertsSignInRequired.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para ver tus alertas.'**
  String get myAlertsSignInRequired;

  /// No description provided for @myAlertsFilterCommunitySection.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get myAlertsFilterCommunitySection;

  /// No description provided for @myAlertsFilterDateSection.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get myAlertsFilterDateSection;

  /// No description provided for @myAlertsFilterStatusSection.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get myAlertsFilterStatusSection;

  /// No description provided for @myAlertsFilterTypeSection.
  ///
  /// In es, this message translates to:
  /// **'Tipo de alerta'**
  String get myAlertsFilterTypeSection;

  /// No description provided for @myAlertsPickStartDate.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get myAlertsPickStartDate;

  /// No description provided for @myAlertsPickEndDate.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get myAlertsPickEndDate;

  /// No description provided for @myAlertsListCapHint.
  ///
  /// In es, this message translates to:
  /// **'Se muestran como máximo las {n} alertas más recientes enviadas desde este dispositivo.'**
  String myAlertsListCapHint(int n);

  /// No description provided for @reportAlertConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportar alerta'**
  String get reportAlertConfirmTitle;

  /// No description provided for @reportAlertConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'¿Deseas reportar esta alerta como inapropiada o con contenido problemático? Solo puedes reportar una vez.'**
  String get reportAlertConfirmBody;

  /// No description provided for @alertReportedOkSnack.
  ///
  /// In es, this message translates to:
  /// **'Alerta reportada correctamente'**
  String get alertReportedOkSnack;

  /// No description provided for @noCommunitiesToForward.
  ///
  /// In es, this message translates to:
  /// **'No hay comunidades disponibles para reenviar'**
  String get noCommunitiesToForward;

  /// No description provided for @alertForwardedToOne.
  ///
  /// In es, this message translates to:
  /// **'✅ Alerta reenviada a 1 comunidad'**
  String get alertForwardedToOne;

  /// No description provided for @alertForwardedToMany.
  ///
  /// In es, this message translates to:
  /// **'✅ Alerta reenviada a {count} comunidades'**
  String alertForwardedToMany(int count);

  /// No description provided for @forwardErrorPrefix.
  ///
  /// In es, this message translates to:
  /// **'Error reenviando:'**
  String get forwardErrorPrefix;

  /// No description provided for @genericErrorPrefix.
  ///
  /// In es, this message translates to:
  /// **'Error:'**
  String get genericErrorPrefix;

  /// No description provided for @forwardAlertDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Reenviar alerta'**
  String get forwardAlertDialogTitle;

  /// No description provided for @forwardSelectTargetsHint.
  ///
  /// In es, this message translates to:
  /// **'Selecciona a qué comunidades reenviar:'**
  String get forwardSelectTargetsHint;

  /// No description provided for @forwardActionCount.
  ///
  /// In es, this message translates to:
  /// **'Reenviar ({count})'**
  String forwardActionCount(int count);

  /// No description provided for @detailRelativeNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora mismo'**
  String get detailRelativeNow;

  /// No description provided for @detailRelativeMinutes.
  ///
  /// In es, this message translates to:
  /// **'Hace {n}m'**
  String detailRelativeMinutes(int n);

  /// No description provided for @detailRelativeHours.
  ///
  /// In es, this message translates to:
  /// **'Hace {n}h'**
  String detailRelativeHours(int n);

  /// No description provided for @detailRelativeDays.
  ///
  /// In es, this message translates to:
  /// **'Hace {n}d'**
  String detailRelativeDays(int n);

  /// No description provided for @selectCommunitiesDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar comunidades'**
  String get selectCommunitiesDialogTitle;

  /// No description provided for @selectCommunitiesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una o más comunidades'**
  String get selectCommunitiesSubtitle;

  /// No description provided for @noCommunitiesAvailableSnack.
  ///
  /// In es, this message translates to:
  /// **'No tienes comunidades disponibles'**
  String get noCommunitiesAvailableSnack;

  /// No description provided for @errorLoadingCommunitiesDetail.
  ///
  /// In es, this message translates to:
  /// **'Error cargando comunidades'**
  String get errorLoadingCommunitiesDetail;

  /// No description provided for @microphonePermissionSnack.
  ///
  /// In es, this message translates to:
  /// **'Se necesita permiso de micrófono'**
  String get microphonePermissionSnack;

  /// No description provided for @recordingFailedWithError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo grabar: {error}'**
  String recordingFailedWithError(String error);

  /// No description provided for @alertDetailSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de alerta'**
  String get alertDetailSheetTitle;

  /// No description provided for @selectedCommunitiesPrefix.
  ///
  /// In es, this message translates to:
  /// **'Comunidades seleccionadas:'**
  String get selectedCommunitiesPrefix;

  /// No description provided for @subtypeOrReasonLabel.
  ///
  /// In es, this message translates to:
  /// **'Subtipo o motivo'**
  String get subtypeOrReasonLabel;

  /// No description provided for @describeCaseLabel.
  ///
  /// In es, this message translates to:
  /// **'Describe el caso'**
  String get describeCaseLabel;

  /// No description provided for @describeCaseHint.
  ///
  /// In es, this message translates to:
  /// **'Especifica el detalle (obligatorio)'**
  String get describeCaseHint;

  /// No description provided for @sendAsAnonymousTitle.
  ///
  /// In es, this message translates to:
  /// **'Enviar como anónima'**
  String get sendAsAnonymousTitle;

  /// No description provided for @sendAsAnonymousSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre no se mostrará en la alerta'**
  String get sendAsAnonymousSubtitle;

  /// No description provided for @photosAndAudioSection.
  ///
  /// In es, this message translates to:
  /// **'Fotos y audio'**
  String get photosAndAudioSection;

  /// No description provided for @photosAndAudioPolicy.
  ///
  /// In es, this message translates to:
  /// **'Puedes añadir hasta {maxPhotos} fotos y un audio de hasta 10 s. El tamaño total de fotos y audio no debe superar aproximadamente 1 MB.'**
  String photosAndAudioPolicy(int maxPhotos);

  /// No description provided for @photoGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get photoGallery;

  /// No description provided for @photoCamera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get photoCamera;

  /// No description provided for @photoChipLabel.
  ///
  /// In es, this message translates to:
  /// **'Foto {n}'**
  String photoChipLabel(int n);

  /// No description provided for @recordingProgress.
  ///
  /// In es, this message translates to:
  /// **'Grabando… {elapsed} / 10 s'**
  String recordingProgress(int elapsed);

  /// No description provided for @audioReadyToSend.
  ///
  /// In es, this message translates to:
  /// **'Audio listo para enviar'**
  String get audioReadyToSend;

  /// No description provided for @audioOptionalMaxTen.
  ///
  /// In es, this message translates to:
  /// **'Audio opcional (máx. 10 s)'**
  String get audioOptionalMaxTen;

  /// No description provided for @stopRecording.
  ///
  /// In es, this message translates to:
  /// **'Detener'**
  String get stopRecording;

  /// No description provided for @startRecording.
  ///
  /// In es, this message translates to:
  /// **'Grabar'**
  String get startRecording;

  /// No description provided for @removeAudio.
  ///
  /// In es, this message translates to:
  /// **'Quitar audio'**
  String get removeAudio;

  /// No description provided for @attachmentListenPreview.
  ///
  /// In es, this message translates to:
  /// **'Escuchar'**
  String get attachmentListenPreview;

  /// No description provided for @attachmentPausePreview.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get attachmentPausePreview;

  /// No description provided for @selectSubtypeRequired.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un subtipo para continuar'**
  String get selectSubtypeRequired;

  /// No description provided for @describeOtherCaseRequired.
  ///
  /// In es, this message translates to:
  /// **'Describe el caso para la opción Otro'**
  String get describeOtherCaseRequired;

  /// No description provided for @passwordReqMinLength.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get passwordReqMinLength;

  /// No description provided for @passwordReqUppercase.
  ///
  /// In es, this message translates to:
  /// **'Al menos 1 mayúscula'**
  String get passwordReqUppercase;

  /// No description provided for @passwordReqLowercase.
  ///
  /// In es, this message translates to:
  /// **'Al menos 1 minúscula'**
  String get passwordReqLowercase;

  /// No description provided for @passwordReqDigit.
  ///
  /// In es, this message translates to:
  /// **'Al menos 1 número'**
  String get passwordReqDigit;

  /// No description provided for @passwordReqSymbol.
  ///
  /// In es, this message translates to:
  /// **'Al menos 1 símbolo especial'**
  String get passwordReqSymbol;

  /// No description provided for @eventualityEnvironmentalTitle.
  ///
  /// In es, this message translates to:
  /// **'Ambiental'**
  String get eventualityEnvironmentalTitle;

  /// No description provided for @eventualityEnvironmentalSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Eventualidad ambiental'**
  String get eventualityEnvironmentalSubtitle;

  /// No description provided for @eventualityPoliceTitle.
  ///
  /// In es, this message translates to:
  /// **'Policial'**
  String get eventualityPoliceTitle;

  /// No description provided for @eventualityPoliceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Eventualidad policial'**
  String get eventualityPoliceSubtitle;
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
