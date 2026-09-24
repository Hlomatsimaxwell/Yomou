// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get remove => 'Quitar';

  @override
  String get retry => 'Reintentar';

  @override
  String get close => 'Cerrar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get today => 'hoy';

  @override
  String get yesterday => 'ayer';

  @override
  String get history => 'Historial';

  @override
  String get favorites => 'Favoritos';

  @override
  String get suggestions => 'Sugerencias';

  @override
  String get explore => 'Explorar';

  @override
  String get updates => 'Actualizaciones';

  @override
  String get settings => 'Ajustes';

  @override
  String get downloads => 'Descargas';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get mangaSources => 'Fuentes de manga';

  @override
  String get searchManga => 'Buscar manga';

  @override
  String get lastUsed => 'Usado por última vez';

  @override
  String get jan => 'ene';

  @override
  String get feb => 'feb';

  @override
  String get mar => 'mar';

  @override
  String get apr => 'abr';

  @override
  String get may => 'may';

  @override
  String get jun => 'jun';

  @override
  String get jul => 'jul';

  @override
  String get aug => 'ago';

  @override
  String get sep => 'sep';

  @override
  String get oct => 'oct';

  @override
  String get nov => 'nov';

  @override
  String get dec => 'dic';

  @override
  String dateLong(Object month, Object day, Object year) {
    return '$month $day, $year';
  }

  @override
  String get pressBackToExit => 'Presiona atrás de nuevo para salir';

  @override
  String get noReadingHistoryYet => 'Aún no hay historial de lectura';

  @override
  String get noSourceAvailable => 'No hay fuente disponible';

  @override
  String get noChaptersAvailable => 'No hay capítulos disponibles';

  @override
  String failedToContinueReading(Object error) {
    return 'No se pudo continuar la lectura: $error';
  }

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsAppearanceSubtitle => 'Tema, modo de lista, idioma';

  @override
  String get settingsMangaSources => 'Fuentes de manga';

  @override
  String get settingsMangaSourcesSubtitle => '1033 de 931 activas';

  @override
  String get settingsReader => 'Ajustes del lector';

  @override
  String get settingsReaderSubtitle =>
      'Modo de lectura, modo de escala, cambio de páginas';

  @override
  String get settingsStorage => 'Almacenamiento y red';

  @override
  String get settingsStorageSubtitle =>
      'Uso de almacenamiento, proxy, precarga de contenido';

  @override
  String get settingsDownloads => 'Descargas';

  @override
  String get settingsDownloadsSubtitle =>
      'Carpeta de descargas, descargar solo con Wi-Fi';

  @override
  String get settingsNewChapters => 'Buscar capítulos nuevos';

  @override
  String get settingsNewChaptersSubtitle =>
      'Buscar actualizaciones, ajustes de notificaciones';

  @override
  String get settingsServices => 'Servicios';

  @override
  String get settingsServicesSubtitle =>
      'Sugerencias, sincronización, seguimiento';

  @override
  String get settingsBackup => 'Copia de seguridad y restauración';

  @override
  String get settingsBackupSubtitle =>
      'Crear o restaurar copia, copias periódicas';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsAboutSubtitle => 'Versión 9.8.1';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceColorScheme => 'Esquema de color';

  @override
  String get appearanceSectionThemeOptions => 'Opciones de tema';

  @override
  String get appearanceSectionMangaList => 'Lista de manga';

  @override
  String get appearanceSectionMainScreen => 'Pantalla principal';

  @override
  String get appearanceNone => 'Ninguno';

  @override
  String get appearanceThemeTitle => 'Tema';

  @override
  String get appearanceThemeSystem => 'Sistema';

  @override
  String get appearanceThemeLight => 'Claro';

  @override
  String get appearanceThemeDark => 'Oscuro';

  @override
  String get appearanceLanguageTitle => 'Idioma';

  @override
  String get languageFollowSystem => 'Seguir el sistema';

  @override
  String get languageEn => 'Inglés';

  @override
  String get languageEs => 'Español';

  @override
  String get languageFr => 'Francés';

  @override
  String get languageDe => 'Alemán';

  @override
  String get languagePt => 'Portugués';

  @override
  String get languageIt => 'Italiano';

  @override
  String get languageRu => 'Ruso';

  @override
  String get languageJa => 'Japonés';

  @override
  String get languageKo => 'Coreano';

  @override
  String get languageZh => 'Chino simplificado';

  @override
  String get languageAr => 'Árabe';

  @override
  String get languageHi => 'Hindi';

  @override
  String get appearanceListModeTitle => 'Modo de lista';

  @override
  String get listModeGrid => 'Cuadrícula';

  @override
  String get listModeList => 'Lista';

  @override
  String appearanceGridSize(int percent) {
    return 'Tamaño de cuadrícula: $percent%';
  }

  @override
  String get appearanceQuickFilters => 'Mostrar filtros rápidos';

  @override
  String get appearanceReadingProgress => 'Mostrar progreso de lectura';

  @override
  String get appearanceBadges => 'Insignias en las listas';

  @override
  String get appearanceDetails => 'Detalles';

  @override
  String get appearanceCollapseDescription => 'Contraer descripción larga';

  @override
  String get appearancePagesThumbnails => 'Mostrar miniaturas de páginas';

  @override
  String get appearanceDefaultTabTitle => 'Pestaña predeterminada';

  @override
  String get appearanceSearchSuggestionsTitle => 'Sugerencias de búsqueda';

  @override
  String get appearanceMainSectionsTitle =>
      'Secciones de la pantalla principal';

  @override
  String get appearanceMainSectionsSubtitle =>
      'Categorías para mostrar en la pantalla principal';

  @override
  String get appearanceFloatingContinue =>
      'Mostrar el botón flotante Continuar';

  @override
  String get appearanceNavLabels =>
      'Mostrar etiquetas en la barra de navegación';

  @override
  String get appearanceFloatingNav => 'Barra de navegación flotante';

  @override
  String get appearancePinNav => 'Fijar la interfaz de navegación';

  @override
  String get appearancePinNavSubtitle =>
      'No ocultar la barra de navegación ni la búsqueda al hacer scroll';

  @override
  String get appearanceExitConfirmation => 'Confirmación de salida';

  @override
  String get appearanceExitConfirmationSubtitle =>
      'Presiona Atrás dos veces para salir de la app';

  @override
  String get appearanceRecentShortcuts =>
      'Mostrar accesos directos de manga reciente';

  @override
  String get appearanceHideNsfwShortcuts =>
      'Ocultar NSFW de los accesos directos';

  @override
  String get appearancePrivacy => 'Privacidad';

  @override
  String get appearanceProtectApp => 'Proteger la app';

  @override
  String get appearanceProtectAppSubtitle =>
      'Requiere autenticación para abrir Yomou';

  @override
  String get appearanceScreenshotPolicyTitle =>
      'Política de capturas de pantalla';

  @override
  String get screenshotPolicyAllow => 'Permitir';

  @override
  String get screenshotPolicyBlock => 'Bloquear';

  @override
  String get appLockEnterTitle => 'Introduce el PIN';

  @override
  String get appLockEnterSubtitle =>
      'Introduce tu PIN de 4 dígitos para abrir Yomou';

  @override
  String get appLockSetTitle => 'Establece un PIN';

  @override
  String get appLockSetSubtitle =>
      'Elige un PIN de 4 dígitos para proteger la app';

  @override
  String get appLockVerifyTitle => 'Introduce el PIN actual';

  @override
  String get appLockVerifySubtitle => 'Confirma tu PIN actual';

  @override
  String get appLockWrongPin => 'PIN incorrecto, inténtalo de nuevo';

  @override
  String get appLockCancel => 'Cancelar';

  @override
  String get homeRecent => 'Recientes';

  @override
  String get suggestionHistory => 'Historial';

  @override
  String get suggestionTrending => 'Tendencias';

  @override
  String get suggestionNew => 'Nuevo';

  @override
  String get suggestionPopular => 'Popular';

  @override
  String get defaultTabLastUsed => 'Usado recientemente';

  @override
  String get defaultTabHistory => 'Historial';

  @override
  String get defaultTabFavorites => 'Favoritos';

  @override
  String get defaultTabSuggestions => 'Sugerencias';

  @override
  String get defaultTabExplore => 'Explorar';

  @override
  String get defaultTabUpdates => 'Novedades';

  @override
  String get favoritesSearchHint => 'Buscar favoritos';

  @override
  String get favoritesCouldNotLoad => 'No se pudieron cargar los favoritos';

  @override
  String get favoritesNoMatch => 'Ningún favorito coincide con tu búsqueda';

  @override
  String get favoritesEmpty => 'Aún no hay favoritos';

  @override
  String get favoritesEmptySubtitle =>
      'Toca el corazón de cualquier manga para añadirlo aquí.';

  @override
  String get bookmarksTitle => 'Marcadores';

  @override
  String get deleteBookmarkTitle => '¿Eliminar marcador?';

  @override
  String bookmarkPage(int page) {
    return 'Página $page';
  }

  @override
  String bookmarkItem(Object title, int page) {
    return '\"$title\" • página $page';
  }

  @override
  String get bookmarksEmpty => 'Aún no hay marcadores';

  @override
  String get bookmarksEmptySubtitle =>
      'Marca páginas mientras lees para guardarlas aquí';

  @override
  String get deleteBookmarkTooltip => 'Eliminar marcador';

  @override
  String get removeDownloadTitle => '¿Quitar descarga?';

  @override
  String removeDownloadContent(Object title) {
    return '\"$title\" se eliminará de tu dispositivo.';
  }

  @override
  String get downloadsEmpty => 'Aún no hay capítulos descargados';

  @override
  String get downloadsEmptySubtitle =>
      'Descarga capítulos en el lector para leer sin conexión';

  @override
  String chapterNum(Object number) {
    return 'Capítulo $number';
  }

  @override
  String downloadsPagesDate(int pages, Object date) {
    return '$pages páginas • $date';
  }

  @override
  String get removeDownloadTooltip => 'Quitar descarga';

  @override
  String get exploreLocalStorage => 'Almacenamiento local';

  @override
  String get exploreRandom => 'Aleatorio';

  @override
  String get exploreManage => 'Gestionar';

  @override
  String get exploreMore => 'Más';

  @override
  String get manageSources => 'Gestionar fuentes';

  @override
  String get incognitoMode => 'Modo incógnito';

  @override
  String get noRandomRightNow =>
      'No hay manga disponible para Aleatorio en este momento';

  @override
  String get couldNotFindRandom => 'No se pudo encontrar un manga aleatorio';

  @override
  String get historyClearTitle => 'Borrar historial';

  @override
  String get historyClearLastHours => 'Últimas 2 horas';

  @override
  String get historyClearToday => 'Hoy';

  @override
  String get historyClearNotFavorites => 'Fuera de favoritos';

  @override
  String get historyClearAll => 'Borrar todo el historial';

  @override
  String get historyClear => 'Borrar';

  @override
  String get historyUpdated => 'Historial actualizado';

  @override
  String get historyListMode => 'Modo de lista';

  @override
  String get historyCompactMode => 'Compacto';

  @override
  String get historyDetailsMode => 'Detalles';

  @override
  String get historyGridSize => 'Tamaño de cuadrícula';

  @override
  String historyGridSizeColumns(int columns) {
    return '$columns columnas';
  }

  @override
  String get historySortingOrder => 'Orden de clasificación';

  @override
  String get historySortAdded => 'Añadidas';

  @override
  String get historySortOldest => 'Más antiguas';

  @override
  String get historySortProgress => 'Progreso';

  @override
  String get historySortUnread => 'Sin leer';

  @override
  String get historySortName => 'Nombre';

  @override
  String get historySortNameReversed => 'Nombre invertido';

  @override
  String get historySortNewChapters => 'Capítulos nuevos';

  @override
  String get historySortLastRead => 'Leídas recientemente';

  @override
  String get historySortLongAgo => 'Leídas hace mucho';

  @override
  String get historySortUpdated => 'Actualizadas';

  @override
  String get historyGroup => 'Agrupar';

  @override
  String get historyListOptions => 'Opciones de lista';

  @override
  String get historyStatistics => 'Estadísticas';

  @override
  String get historyOnDevice => 'En el dispositivo';

  @override
  String get historyNewChapters => 'Capítulos nuevos';

  @override
  String get historyCompleted => 'Completadas';

  @override
  String get historyEmptyTitle => 'No se encontró historial de lectura';

  @override
  String get historyEmptySubtitle => 'El manga que leas aparecerá aquí.';

  @override
  String get historyGroupToday => 'Hoy';

  @override
  String get historyGroupYesterday => 'Ayer';

  @override
  String historyGroupDaysAgo(Object count) {
    return 'Hace $count días';
  }

  @override
  String get historyGroupRest => 'Resto';

  @override
  String historyLastReadChapter(Object chapter) {
    return 'Última lectura: Capítulo $chapter';
  }

  @override
  String historyChapterShort(Object chapter) {
    return 'Cap. $chapter';
  }

  @override
  String searchEverywhereBusy(Object tag) {
    return 'Buscando \"$tag\" en todas partes...';
  }

  @override
  String searchOnSource(Object source) {
    return 'Buscar en $source';
  }

  @override
  String get searchEverywhere => 'Buscar en todas partes';

  @override
  String get sourceNotSupported => 'Esta fuente no es compatible desde aquí.';

  @override
  String get chapterStatusReadDownloaded => 'Leído • Descargado';

  @override
  String get chapterStatusRead => 'Leído';

  @override
  String get chapterStatusDownloaded => 'Descargado';

  @override
  String downloadedChaptersCount(int count) {
    return 'Descargados $count capítulo(s)';
  }

  @override
  String get deletedSelectedDownloads => 'Descargas seleccionadas eliminadas';

  @override
  String get pagesHintStartReading => 'Empieza a leer para ver las páginas';

  @override
  String get pagesUnavailable => 'No hay páginas disponibles';

  @override
  String mangaDetailBookmarkItem(Object title, int page) {
    return '$title • Página $page';
  }

  @override
  String get noNote => 'Sin nota';

  @override
  String get selectRange => 'Seleccionar rango';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Desmarcar todo';

  @override
  String get toggleRead => 'Alternar leído';

  @override
  String get detailDownload => 'Descargar';

  @override
  String get favorited => 'En favoritos';

  @override
  String get favorite => 'Favorito';

  @override
  String chapterOfTotal(int current, int total) {
    return 'Capítulo $current de $total';
  }

  @override
  String chaptersCount(int total) {
    return '$total capítulos';
  }

  @override
  String get detailSource => 'Fuente';

  @override
  String get detailAuthor => 'Autor';

  @override
  String get detailYear => 'Año';

  @override
  String get detailState => 'Estado';

  @override
  String get detailChapters => 'Capítulos';

  @override
  String get detailProgress => 'Progreso';

  @override
  String get detailOnDevice => 'En dispositivo';

  @override
  String get mockSource => 'Fuente simulada';

  @override
  String get unknown => 'Desconocido';

  @override
  String get noDescription => 'No hay descripción disponible.';

  @override
  String get description => 'Descripción';

  @override
  String get relatedManga => 'Manga relacionado';

  @override
  String get showAll => 'Ver todo';

  @override
  String get continueAction => 'Continuar';

  @override
  String get readAction => 'Leer';

  @override
  String get chapterDateToday => 'Hoy';

  @override
  String get chapterDateYesterday => 'Ayer';

  @override
  String chapterDaysAgo(int days) {
    return 'hace $days días';
  }

  @override
  String get mangaDetailBookmarksEmpty =>
      'Puedes crear marcadores mientras lees manga.';

  @override
  String get colorCorrection => 'Corrección de color';

  @override
  String get filterBrightness => 'Brillo';

  @override
  String get filterContrast => 'Contraste';

  @override
  String get filterSepia => 'Sepia';

  @override
  String get reset => 'Restablecer';

  @override
  String get done => 'Hecho';

  @override
  String readerPageSavedTo(Object path) {
    return 'Página guardada en $path';
  }

  @override
  String get readerFailedToSavePage => 'No se pudo guardar la página';

  @override
  String get readerCurrentChapter => 'Capítulo actual';

  @override
  String get readerCancelDownload => 'Cancelar descarga';

  @override
  String get readerDownloadChapter => 'Descargar capítulo';

  @override
  String get readerPagesLoading => 'Cargando páginas...';

  @override
  String get readerFailedToLoadBookmarks =>
      'No se pudieron cargar los marcadores';

  @override
  String get readerBookmarksHint =>
      'Marca páginas mientras lees para guardarlas aquí';

  @override
  String get readerNoDownloads => 'Aún no hay capítulos descargados';

  @override
  String get readerRemoveBookmarkTitle => '¿Quitar marcador?';

  @override
  String readerBookmarkLine(Object title, int page) {
    return '$title • Página $page';
  }

  @override
  String get readerChapterNotFound => 'No se encontró el capítulo';

  @override
  String get readerSavePage => 'Guardar página';

  @override
  String get readerRemoveBookmark => 'Quitar marcador';

  @override
  String get readerAddBookmark => 'Añadir marcador';

  @override
  String get readerSectionReadingMode => 'Modo de lectura';

  @override
  String get readerSectionOptions => 'Opciones';

  @override
  String get readerTwoPagesLandscape =>
      'Usar doble página en orientación horizontal (beta)';

  @override
  String get readerExperimental => 'Experimental';

  @override
  String get readerRotateScreen => 'Bloquear rotación de pantalla';

  @override
  String get readerLandscapeOrientation => 'Orientación horizontal';

  @override
  String get readerRotateToLandscape => 'Rotar a horizontal';

  @override
  String get readerAutoScroll => 'Desplazamiento automático';

  @override
  String get readerContinuousScroll => 'Desplazamiento vertical continuo';

  @override
  String get readerShowStatus => 'Mostrar estado del lector';

  @override
  String get readerHideControlsStatus =>
      'Mostrar progreso, batería y hora al ocultar los controles';

  @override
  String get readerPreferences => 'Preferencias del lector';

  @override
  String get readerPreferencesSubtitle =>
      'Doble página, auto-desplazamiento, barra de estado y más';

  @override
  String get readerSectionTools => 'Herramientas';

  @override
  String get readerBrightnessContrastSepia => 'Brillo, contraste, sepia';

  @override
  String get readerAppPreferences => 'Preferencias de la app';

  @override
  String get readerModeStandard => 'Estándar';

  @override
  String get readerModeRTL => 'D-a-I';

  @override
  String get readerModeVertical => 'Vertical';

  @override
  String get readerModeWebtoon => 'Webtoon';

  @override
  String get readerRememberedNote =>
      'La configuración elegida se recordará para este manga.';

  @override
  String get readerFailedLoadChapterPages =>
      'No se pudieron cargar las páginas del capítulo';

  @override
  String get readerFailedDownloadChapter => 'No se pudo descargar el capítulo';

  @override
  String readerDownloadedChapter(Object title) {
    return 'Descargado $title';
  }

  @override
  String get readerRemoveDownloadTitle => '¿Quitar descarga?';

  @override
  String get readerThisChapter => 'Este capítulo';

  @override
  String readerSavedFromChapter(Object title) {
    return 'Guardado desde $title';
  }

  @override
  String readerBookmarkRemovedNice(Object title, int page) {
    return 'Marcador quitado — $title • Página $page';
  }

  @override
  String readerBookmarked(Object title, int page) {
    return 'Marcado $title • Página $page';
  }

  @override
  String readerChapterShort(Object chapter) {
    return 'Cap. $chapter';
  }

  @override
  String get readerFailedLoadPage => 'No se pudo cargar la página';

  @override
  String get readerLoadingNextChapter => 'Cargando el siguiente capítulo...';

  @override
  String get readerReachedLatestChapter => '¡Has llegado al último capítulo!';

  @override
  String get readerPreviousChapter => 'Capítulo anterior';

  @override
  String get readerNextChapter => 'Capítulo siguiente';

  @override
  String readerDownloadedChapterDate(int count, Object date) {
    return '$count páginas • descargado $date';
  }

  @override
  String get readerMoreSheetTitle => 'Más';

  @override
  String get searchSources => 'Buscar fuentes...';

  @override
  String switchedToSource(Object source) {
    return 'Cambiado a $source';
  }

  @override
  String get toTop => 'Subir arriba';

  @override
  String get pin => 'Fijar';

  @override
  String get enableSource => 'Activar fuente';

  @override
  String get disableSource => 'Desactivar fuente';

  @override
  String get disabled => 'Desactivada';

  @override
  String get cannotDisableActiveSource =>
      'Cambia a otra fuente antes de desactivar esta';

  @override
  String get cannotSelectDisabledSource =>
      'Activa esta fuente antes de explorarla';

  @override
  String get createShortcut => 'Crear acceso directo';

  @override
  String get disableNsfw => 'Desactivar NSFW';

  @override
  String get notificationSettingsDescription =>
      'Revisa tu biblioteca en segundo plano y te avisa cuando una serie que sigues recibe un capítulo nuevo.';

  @override
  String get notificationSettingsEnable => 'Notificaciones de capítulos nuevos';

  @override
  String get notificationSettingsOn => 'Revisando en segundo plano';

  @override
  String get notificationSettingsOff => 'Desactivadas';

  @override
  String get notificationPermissionDenied =>
      'Se denegó el permiso de notificaciones. Actívalo en los ajustes del sistema.';

  @override
  String get notificationPreviewSection => 'Vista previa';

  @override
  String get notificationPreviewNewChapters =>
      'Notificación de capítulos nuevos';

  @override
  String get notificationPreviewSuggested => 'Notificación de manga sugerido';

  @override
  String get notificationOptionsSection => 'Opciones';

  @override
  String get notificationWifiOnly => 'Solo con Wi-Fi';

  @override
  String get notificationWifiOnlySubtitle =>
      'No revisar usando conexiones con datos móviles';

  @override
  String get notificationFrequency => 'Frecuencia de revisión';

  @override
  String get frequencyManual => 'Manual';

  @override
  String get frequencyLess => 'Con menos frecuencia';

  @override
  String get frequencyDefault => 'Predeterminada';

  @override
  String get frequencyMore => 'Con más frecuencia';

  @override
  String get notificationScope => 'Buscar actualizaciones en';

  @override
  String notificationScopeSubtitle(int enabled, int total) {
    return '$enabled de $total activadas';
  }

  @override
  String get notificationScopeFavorites => 'Favoritos';

  @override
  String get notificationScopeHistory => 'Historial';

  @override
  String get notificationCategories => 'Categorías favoritas';

  @override
  String notificationCategoriesSubtitle(int enabled, int total) {
    return '$enabled de $total activadas';
  }

  @override
  String get notificationCategoriesNone => 'Aún no hay categorías favoritas';

  @override
  String get notificationNsfw => 'Desactivar notificaciones NSFW';

  @override
  String get notificationNsfwSubtitle =>
      'Omitir contenido para adultos al revisar y sugerir';

  @override
  String get notificationDownload => 'Descargar capítulos nuevos';

  @override
  String get autoDownloadNever => 'Nunca';

  @override
  String get autoDownloadDownloaded => 'Manga con capítulos descargados';

  @override
  String get autoDownloadRecentlyRead => 'Manga leído recientemente';

  @override
  String get notificationCheckLogSection => 'Depuración y sistema';

  @override
  String get notificationCheckNow => 'Buscar capítulos nuevos ahora';

  @override
  String get notificationCheckRunning => 'Buscando...';

  @override
  String get notificationCheckDone => 'Revisión completada';

  @override
  String get notificationCheckFailed => 'Error en la revisión';

  @override
  String get notificationLog => 'Registro de revisión de capítulos';

  @override
  String get notificationLogEmpty => 'Todavía no se han realizado revisiones';

  @override
  String get notificationBattery => 'Desactivar la optimización de batería';

  @override
  String get notificationBatterySubtitle =>
      'Android puede detener los procesos en segundo plano a menos que marques esta app como excepción';

  @override
  String notificationLogChecked(int scanned) {
    return '$scanned series revisadas';
  }

  @override
  String notificationLogFound(int series, int chapters) {
    return '$series series, $chapters capítulos nuevos';
  }

  @override
  String notificationLogSuggested(String title) {
    return '$title sugerido';
  }

  @override
  String get searchCatalog => 'Buscar en el catálogo...';

  @override
  String get noMangaFound => 'No se encontró manga';

  @override
  String get noResultsFound => 'No se encontraron resultados';

  @override
  String get tryDifferentSearch => 'Prueba con otra búsqueda.';

  @override
  String get searchHintAny => 'Introduce el título o el género del manga';

  @override
  String get searchEllipsis => 'Buscar...';

  @override
  String get searchThisSource => 'Buscar en esta fuente...';

  @override
  String get randomMangaTooltip => 'Manga aleatorio';

  @override
  String get feedNoNewUpdates => 'Aún no hay actualizaciones nuevas';

  @override
  String get suggestionsNoResults => 'No se encontraron sugerencias';

  @override
  String get suggestionsNoGenreResults =>
      'No se encontró manga de este género en esta fuente';

  @override
  String get clearSearchHistory => 'Borrar historial de búsqueda';

  @override
  String get failedToSearch => 'Error al buscar';

  @override
  String get refreshResults => 'Actualizar resultados';

  @override
  String get clearSearchQuery => 'Borrar consulta de búsqueda';

  @override
  String get filterUpdated => 'Actualizado';

  @override
  String get failedToLoadManga => 'No se pudo cargar el manga';

  @override
  String get hideFailedSources => 'Ocultar fuentes con errores';

  @override
  String get showFailedSources => 'Mostrar fuentes con errores';

  @override
  String showAllCount(int count) {
    return 'Ver todo ($count)';
  }

  @override
  String get sourceFailed => 'La fuente falló';

  @override
  String get contentNotFoundRemoved => 'Contenido no encontrado o eliminado';

  @override
  String get feedUpdatesHint =>
      'El manga que lees se mostrará aquí cuando se publiquen nuevos capítulos.';

  @override
  String get failedToLoadUpdates => 'No se pudieron cargar las actualizaciones';

  @override
  String get failedToLoadSuggestions => 'No se pudieron cargar las sugerencias';

  @override
  String get checking => 'Comprobando';

  @override
  String get refresh => 'Actualizar';

  @override
  String get refreshed => 'Actualizado';

  @override
  String get updatesTitle => 'Actualizaciones';

  @override
  String get showMore => 'Ver más';

  @override
  String get showLess => 'Ver menos';

  @override
  String get mangaEdit => 'Editar';

  @override
  String get findSimilar => 'Buscar similares';

  @override
  String get alternatives => 'Alternativas';

  @override
  String get openInBrowser => 'Abrir en el navegador web';

  @override
  String get urlUnavailable =>
      'La dirección web de este manga no está disponible.';

  @override
  String get replaceSource => 'Reemplazar fuente';

  @override
  String get shortcutCreated => 'Acceso directo de inicio creado';

  @override
  String get editMangaTitle => 'Título';

  @override
  String get editMangaCover => 'Portada';

  @override
  String get editMangaTags => 'Etiquetas';

  @override
  String get save => 'Guardar';

  @override
  String get metadataSaved => 'Metadatos del manga actualizados';

  @override
  String replaceSourceDone(Object source) {
    return 'Reenlazado a $source';
  }

  @override
  String get noSourceToReplace =>
      'No hay ninguna fuente disponible para cambiar';

  @override
  String get saveManga => 'Guardar manga';

  @override
  String get chapters => 'capítulos';

  @override
  String downloadWholeManga(Object count) {
    return 'Manga completo ($count capítulos)';
  }

  @override
  String downloadFirstChapters(Object count) {
    return 'Primeros $count capítulos';
  }

  @override
  String downloadNextUnread(Object count) {
    return 'Próximos $count capítulos sin leer';
  }

  @override
  String get downloadHint =>
      'Puedes seleccionar capítulos para descargar manteniendo pulsado un elemento en la lista de capítulos.';

  @override
  String get startDownload => 'Iniciar descarga';

  @override
  String get startDownloadQueueHint =>
      'Desactívalo para poner las descargas en cola en lugar de iniciarlas de inmediato.';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get destinationDirectory => 'Directorio de destino';

  @override
  String get preferredFormat => 'Formato de descarga preferido';

  @override
  String get download => 'Descargar';

  @override
  String get downloadsQueued => 'Descargas en cola';

  @override
  String get downloadNotReady =>
      'Los capítulos aún se están cargando. Inténtalo de nuevo en un momento.';

  @override
  String get formatAutomatic => 'Automático';

  @override
  String get formatCbz => 'CBZ';

  @override
  String get formatImages => 'Imágenes';

  @override
  String get destInternalStorage => 'Almacenamiento interno compartido';

  @override
  String get destAppFiles => 'Archivos externos de la app';

  @override
  String get destCacheFolder => 'Caché';

  @override
  String historySelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String historyRemovedCount(int count) {
    return '$count eliminados del historial';
  }

  @override
  String get historyUndo => 'Deshacer';

  @override
  String get historyEdit => 'Editar';

  @override
  String get historyMarkCompleted => 'Marcar como completado';

  @override
  String get historyComingSoon => 'Próximamente';

  @override
  String historyFavoritedCount(int count) {
    return '$count añadidos a favoritos';
  }

  @override
  String get historyAlreadyFavorite => 'Ya está en favoritos';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String historyUnfavoritedCount(int count) {
    return '$count eliminados de favoritos';
  }

  @override
  String get historyNotFavorite => 'No está en favoritos';

  @override
  String get editPickFromFiles => 'Elegir archivo de imagen';

  @override
  String get editCoversFromSources => 'Portadas de otras fuentes';

  @override
  String get editUseDefaultCover => 'Usar portada original';

  @override
  String get editCustomCover => 'Personalizada';

  @override
  String get editTitleHint => 'Título del manga';

  @override
  String get editChangesNote =>
      'Estos cambios afectarán cómo se muestra el manga en la app.';

  @override
  String get editDiscardTitle => '¿Descartar cambios?';

  @override
  String get editDiscardContent =>
      'Tienes cambios sin guardar. Se perderán si sales ahora.';

  @override
  String get editDiscard => 'Descartar';

  @override
  String get editNoAltCovers =>
      'No hay portadas alternativas disponibles para esta fuente.';

  @override
  String get editCoverSaveFailed =>
      'No se pudo guardar la imagen seleccionada.';

  @override
  String get editSelectOneToEdit =>
      'Selecciona exactamente un manga para editar';

  @override
  String coversProgress(int done, int total) {
    return '$done / $total fuentes';
  }

  @override
  String get coversCurrent => 'Portada actual';

  @override
  String get coversUseThis => 'Usar esta portada';

  @override
  String get coversNoResults => 'No se encontraron portadas alternativas';

  @override
  String get storageCacheSection => 'Caché de imágenes';

  @override
  String get storageCacheMaxTitle => 'Tamaño de caché';

  @override
  String storageCacheMaxSubtitle(Object count) {
    return '$count archivos';
  }

  @override
  String get storageCacheStaleTitle => 'Caducidad de caché';

  @override
  String storageCacheStaleSubtitle(Object count) {
    return '$count días';
  }

  @override
  String get storagePreloadTitle => 'Precargar siguiente capítulo';

  @override
  String get storagePreloadSubtitle =>
      'Descarga el siguiente capítulo en segundo plano mientras lees';

  @override
  String get storageClearTitle => 'Borrar caché de imágenes';

  @override
  String storageClearSubtitle(Object size) {
    return 'En uso actualmente: $size';
  }

  @override
  String get storageClearConfirmTitle => '¿Borrar caché de imágenes?';

  @override
  String get storageClearConfirmBody =>
      'Se eliminarán todas las páginas y portadas en caché. Se volverán a descargar cuando las veas de nuevo.';

  @override
  String get storageCancel => 'Cancelar';

  @override
  String get storageClearDone => 'Caché de imágenes borrada';

  @override
  String get storageUnknown => 'desconocido';

  @override
  String get backupRestore => 'Copia de seguridad y restauración';

  @override
  String get createDataBackup => 'Crear copia de seguridad';

  @override
  String get backupSubtitle =>
      'Puedes crear una copia de tu historial y favoritos y restaurarla';

  @override
  String get restoreFromBackup => 'Restaurar copia de seguridad';

  @override
  String get restoreSubtitle =>
      'Restaurar una copia de seguridad creada anteriormente';

  @override
  String get exportTachiyomi => 'Exportar a Tachiyomi/Mihon';

  @override
  String get exportTachiyomiSubtitle =>
      'Exportar favoritos e historial en formato Tachiyomi';

  @override
  String get importTachiyomi => 'Importar desde Tachiyomi/Mihon';

  @override
  String get importTachiyomiSubtitle =>
      'Importar favoritos desde una copia .tachibk';

  @override
  String tachiyomiExportDone(int count) {
    return '$count manga exportados a Tachiyomi/Mihon';
  }

  @override
  String tachiyomiImportDone(int count) {
    return '$count manga importados desde Tachiyomi/Mihon';
  }

  @override
  String backupSkipped(int count) {
    return '$count omitidos';
  }

  @override
  String get importResultsTitle => 'Resultado de la importación';

  @override
  String importResultsImported(int count) {
    return '$count importados';
  }

  @override
  String importResultsNotImported(int count) {
    return '$count no importados';
  }

  @override
  String get importResultsAllImported =>
      'Todos los manga se importaron correctamente';

  @override
  String get importResultsImportedSection => 'Importados';

  @override
  String get importResultsSkippedSection => 'No importados';

  @override
  String importResultsSkippedReasonSource(String source) {
    return 'No hay fuente compatible para $source';
  }

  @override
  String get importResultsSkippedReasonSourceFallback =>
      'Yomou no tiene esta fuente';

  @override
  String get importResultsSkippedReasonId =>
      'No se pudo identificar la URL del manga';

  @override
  String importResultsReadTo(num chapter) {
    return 'Leído hasta el capítulo $chapter';
  }

  @override
  String get tachiyomiExportNone =>
      'No se encontró manga compatible para exportar';

  @override
  String get tachiyomiImportInvalid => 'Archivo de copia de Tachiyomi inválido';

  @override
  String get tachiyomiImportNone =>
      'No se encontró manga compatible para importar';

  @override
  String get periodicBackups => 'Copias periódicas';

  @override
  String get enablePeriodicBackups => 'Activar copias periódicas';

  @override
  String get backupsOutputDirectory => 'Directorio de copias de seguridad';

  @override
  String get backupsOutputDirectoryNone => 'Ningún directorio seleccionado';

  @override
  String get backupCreationFrequency => 'Frecuencia de copia de seguridad';

  @override
  String get deleteOldBackups => 'Eliminar copias antiguas';

  @override
  String get maxNumberOfBackups => 'Número máximo de copias';

  @override
  String get lastSuccessfulBackup => 'Última copia exitosa';

  @override
  String lastSuccessfulBackupTime(String time) {
    return 'Última copia exitosa: $time';
  }

  @override
  String get backupNever => 'Nunca';

  @override
  String get backupJustNow => 'Ahora mismo';

  @override
  String backupMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count minutos',
      one: 'hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String backupHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String backupDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String backupWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count semanas',
      one: 'hace 1 semana',
    );
    return '$_temp0';
  }

  @override
  String backupMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count meses',
      one: 'hace 1 mes',
    );
    return '$_temp0';
  }

  @override
  String backupYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count años',
      one: 'hace 1 año',
    );
    return '$_temp0';
  }
}
