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
  String settingsMangaSourcesSubtitle(Object enabled, Object total) {
    return '$enabled de $total activas';
  }

  @override
  String get sourcesSortingOrder => 'Orden de clasificación';

  @override
  String get sourcesSortOrderManual => 'Manual';

  @override
  String get sourcesSortOrderName => 'Nombre';

  @override
  String get sourcesManage => 'Gestionar fuentes';

  @override
  String get sourcesShowInGrid => 'Mostrar en vista de rejilla';

  @override
  String get sourcesEnableAll => 'Activar todas las fuentes de manga';

  @override
  String get sourcesChooseMirror => 'Elegir espejo automáticamente';

  @override
  String get sourcesHandleLinks => 'Gestionar enlaces';

  @override
  String get sourcesIncognitoNsfw => 'Modo incógnito para manga NSFW';

  @override
  String get sourcesIncognitoEnable => 'Activar';

  @override
  String get sourcesIncognitoAsk => 'Preguntar siempre';

  @override
  String get sourcesIncognitoDisable => 'Desactivar';

  @override
  String get sourcesCatalog => 'Catálogo de fuentes';

  @override
  String get sourcesCatalogSubtitle =>
      'Catálogo de todas las fuentes disponibles';

  @override
  String get settingsReader => 'Ajustes del lector';

  @override
  String get settingsReaderSubtitle => 'Modo de lectura, escalado, parpadeo';

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
  String get dlsDirsTitle => 'Local manga directories';

  @override
  String dlsDirsCount(int count) {
    return '$count items';
  }

  @override
  String get dlsFolderTitle => 'Downloads folder';

  @override
  String get dlsFolderChapters => 'Chapter downloads';

  @override
  String get dlsFolderPublic => 'Public downloads';

  @override
  String get dlsFolderDocuments => 'App documents';

  @override
  String dlsFolderCustom(String name) {
    return 'Custom: $name';
  }

  @override
  String get dlsNotSet => 'Not set';

  @override
  String get dlsFormatTitle => 'Preferred download format';

  @override
  String get dlsFormatAuto => 'Automatic';

  @override
  String get dlsFormatCbz => 'Single CBZ file';

  @override
  String get dlsFormatCbzs => 'Multiple CBZ files';

  @override
  String get dlsNetworkTitle => 'Downloading over cellular network';

  @override
  String get dlsNetworkAllow => 'Allow always';

  @override
  String get dlsNetworkAsk => 'Ask every time';

  @override
  String get dlsNetworkDeny => 'Don\'t allow';

  @override
  String get dlsInfoBody =>
      'Downloaded chapters and saved pages stay on this device so you can read them offline. Everything stored here is removed when you uninstall Yomou.';

  @override
  String get dlsSectionSaving => 'Saving pages';

  @override
  String get dlsSaveDirTitle => 'Default page save directory';

  @override
  String get dlsAskDirTitle => 'Ask for the destination dir every time';

  @override
  String get dlsAskDirSubtitle =>
      'Choose where each download is saved before it starts';

  @override
  String get dlsChaptersName => 'Chapter downloads';

  @override
  String get dlsPublicName => 'Public downloads';

  @override
  String get dlsDocumentsName => 'App documents';

  @override
  String dlsCustomName(int n) {
    return 'Custom folder $n';
  }

  @override
  String get dlsAddSheetTitle => 'Add download directory';

  @override
  String get dlsAddCustom => 'Pick custom folder';

  @override
  String get dlsAddCustomSubtitle => 'Choose an existing folder on this device';

  @override
  String get dlsAdd => 'Add';

  @override
  String get dlsDefaultMarker => 'Default directory';

  @override
  String get dlsDefaultSet => 'Default directory updated';

  @override
  String dlsDirAdded(String name) {
    return '$name added';
  }

  @override
  String get dlsWarning =>
      'Uninstalling Yomou deletes all downloaded chapters and saved pages. Back up anything you want to keep.';

  @override
  String dlsAvailable(String size) {
    return '$size available';
  }

  @override
  String get dlsNoStats => 'Not available for this location';

  @override
  String get dlsNoWritePermission => 'Yomou can\'t write to this folder';

  @override
  String get dlsCellularConfirmTitle =>
      'Allow downloads over cellular network?';

  @override
  String get dlsCellularConfirmBody =>
      'You\'re on mobile data. Downloading chapters can use a lot of data.';

  @override
  String get dlsCellularAllowOnce => 'Allow once';

  @override
  String get dlsCellularAllowAlways => 'Allow always';

  @override
  String get dlsCellularDontAllow => 'Don\'t allow';

  @override
  String get dlsCellularBlocked =>
      'Download skipped — mobile data downloads are off';

  @override
  String dlgChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String dlgSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get dlgRemoveAll => 'Remove all downloads';

  @override
  String get dlgRemoveAllTitle => 'Remove all downloads?';

  @override
  String get dlgRemoveAllBody =>
      'This deletes every downloaded chapter from this device. It can\'t be undone.';

  @override
  String get dlgRemoveSelectedTitle => 'Remove selected downloads?';

  @override
  String dlgRemoveSelectedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This deletes $count downloaded chapters from this device.',
      one: 'This deletes 1 downloaded chapter from this device.',
    );
    return '$_temp0 It can\'t be undone.';
  }

  @override
  String get dlgSettingsItem => 'Downloads settings';

  @override
  String get dlgSettingsItemSubtitle =>
      'Where chapters and saved pages are stored';

  @override
  String get dlgRead => 'read';

  @override
  String get dlgDownloadChannelName => 'Downloads';

  @override
  String get dlgDownloadChannelDescription =>
      'Progress and results for chapters being saved to this device';

  @override
  String get dlgDownloadPreparing => 'Preparing download…';

  @override
  String dlgDownloadPreparingChapters(int count) {
    return 'Preparing $count chapters…';
  }

  @override
  String get dlgDownloadQueued => 'Waiting to start';

  @override
  String get dlgDownloadPaused => 'Paused';

  @override
  String dlgDownloadPages(Object done, Object total) {
    return '$done of $total pages';
  }

  @override
  String dlgDownloadChapterOf(Object done, Object total) {
    return 'Chapter $done of $total';
  }

  @override
  String get dlgDownloadComplete => 'Download complete';

  @override
  String dlgDownloadCompleteBody(int done) {
    return '$done chapters saved to this device';
  }

  @override
  String get dlgDownloadFailed => 'Download failed';

  @override
  String get dlgDownloadCancelled => 'Download cancelled';

  @override
  String dlgDownloadPartialBody(int done, int total) {
    return '$done of $total chapters saved';
  }

  @override
  String get dlgDownloadResume => 'Resume';

  @override
  String get dlgDownloadPause => 'Pause';

  @override
  String get dlgDownloadCancel => 'Cancel download';

  @override
  String get dlgDownloadCancelTitle => 'Cancel this download?';

  @override
  String dlgDownloadCancelBody(int saved, int total) {
    return '$saved of $total chapters are already saved and will stay on this device. The rest will not be downloaded.';
  }

  @override
  String get dlgDownloadRemoveJob => 'Remove from list';

  @override
  String get dlgInProgress => 'In progress';

  @override
  String get dlgQueued => 'Queued';

  @override
  String get dlgFailed => 'Failed';

  @override
  String dlgQueuedDownload(int count) {
    return 'Queued $count chapters for download';
  }

  @override
  String get dlgAlreadyDownloaded => 'Already downloaded';

  @override
  String get dlgDownloadNothingQueued => 'Nothing to download';

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
  String get settingsServicesUnavailable =>
      'Todavía no hay nada que configurar';

  @override
  String get settingsBackup => 'Copia de seguridad y restauración';

  @override
  String get settingsBackupSubtitle =>
      'Crear o restaurar copia, copias periódicas';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsAboutVersion => 'Versión';

  @override
  String get settingsAboutBuild => 'Compilación';

  @override
  String get settingsAboutPackage => 'Paquete';

  @override
  String get settingsAboutPlatform => 'Plataforma';

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
  String get appearanceFrostedGlass => 'Vidrio esmerilado';

  @override
  String get appearanceFrostedGlassSubtitle =>
      'Desenfoque esmerilado en la barra de navegación, controles del lector y botones flotantes';

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
  String get featuredManga => 'Destacados';

  @override
  String get readNow => 'Leer ahora';

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
  String get favoritesGridSize => 'Tamaño de cuadrícula';

  @override
  String favoritesGridSizeColumns(int columns) {
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
  String get readingStatistics => 'Estadísticas de lectura';

  @override
  String get statsTimeDay => 'Día';

  @override
  String get statsTimeWeek => 'Semana';

  @override
  String get statsTimeMonth => 'Mes';

  @override
  String get statsTimeThreeMonths => 'Tres meses';

  @override
  String get statsTimeAllTime => 'Todo';

  @override
  String get statsFavorites => 'Favoritos';

  @override
  String get statsOtherManga => 'Otros mangas';

  @override
  String statsMinutes(num minutes) {
    return '$minutes minutos';
  }

  @override
  String get statsMinute => '1 minuto';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsEmptyTitle => 'Aún sin lecturas';

  @override
  String get statsEmptySubtitle =>
      'El tiempo que dediques a leer aparecerá aquí al empezar un capítulo.';

  @override
  String get statsClearTitle => '¿Borrar estadísticas?';

  @override
  String get statsClearMessage =>
      'Esto elimina el tiempo de lectura registrado y el historial de capítulos de las gráficas. Tu biblioteca no se toca.';

  @override
  String get statsClear => 'Borrar estadísticas';

  @override
  String get statsCleared => 'Estadísticas borradas';

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
  String get detailTranslation => 'Traducción';

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
  String get readerChaptersTitle => 'Capítulos';

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
  String get filterTitle => 'Filtro';

  @override
  String get filterClose => 'Cerrar filtros';

  @override
  String get filterReset => 'Restablecer filtros';

  @override
  String get filterSort => 'Ordenar';

  @override
  String get filterLanguage => 'Idioma';

  @override
  String get filterGenres => 'Géneros';

  @override
  String get filterExcludeGenres => 'Excluir géneros';

  @override
  String get filterMangaState => 'Estado del manga';

  @override
  String get filterYear => 'Año de publicación';

  @override
  String get filterSaved => 'Filtro guardado';

  @override
  String get filterSavePresetTitle => 'Guardar filtro';

  @override
  String get filterSavePresetHint => 'Nombre del filtro';

  @override
  String filterSavedPreset(String name) {
    return 'Guardado \"$name\"';
  }

  @override
  String get filterCancel => 'Cancelar';

  @override
  String get filterSavedFilters => 'Filtros guardados';

  @override
  String filterPresetApplied(String name) {
    return 'Aplicado \"$name\"';
  }

  @override
  String get filterRename => 'Renombrar';

  @override
  String get filterDelete => 'Eliminar';

  @override
  String get filterDeleteConfirmTitle => '¿Eliminar filtro?';

  @override
  String filterDeleteConfirmBody(String name) {
    return 'Se eliminará \"$name\".';
  }

  @override
  String get filterPresetDeleted => 'Filtro eliminado';

  @override
  String get filterSave => 'Guardar';

  @override
  String get filterDone => 'Hecho';

  @override
  String get filterApply => 'Aplicar';

  @override
  String get sourcePreview => 'Vista previa';

  @override
  String get openFullDetails => 'Abrir detalles completos';

  @override
  String get previewSourceMissing => 'Fuente no disponible';

  @override
  String get previewSourceMissingSubtitle =>
      'Este título venía de una fuente que ya no está instalada, así que no se pueden cargar sus detalles.';

  @override
  String get filterAllLanguages => 'Todos';

  @override
  String get filterStateFinished => 'Terminado';

  @override
  String get filterStateDropped => 'Abandonado';

  @override
  String get filterStateUpcoming => 'Próximamente';

  @override
  String get filterNoTags => 'Esta fuente no tiene lista de géneros.';

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
  String get altEnabledSources => 'Fuentes habilitadas';

  @override
  String altSourcesCount(num x, num y) {
    return '$x/$y fuentes';
  }

  @override
  String get altMigrateTitle => 'Migración de manga';

  @override
  String altMigrateBody(
    String fromTitle,
    String fromSource,
    String toTitle,
    String toSource,
  ) {
    return '$fromTitle de $fromSource será reemplazado por $toTitle de $toSource en tu historial y favoritos (si existen).';
  }

  @override
  String get altMigrate => 'Migrar';

  @override
  String get altMigrateFailed => 'La migración falló. Inténtalo de nuevo.';

  @override
  String get altSortTitle => 'Orden de clasificación';

  @override
  String get altSortBest => 'Mejor coincidencia';

  @override
  String get altSortMostChapters => 'Más capítulos';

  @override
  String get altSortClosest => 'Recuento de capítulos más cercano';

  @override
  String get altSortPriority => 'Prioridad de fuente';

  @override
  String get altSources => 'Fuentes de manga';

  @override
  String get altAllSources => 'Todas las fuentes';

  @override
  String get altSameLanguage => 'Mismo idioma que el actual';

  @override
  String get altSameType => 'Mismo tipo de contenido que el actual';

  @override
  String get altReplace => 'Reemplazar';

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
  String get backupFixLibrary => 'Quitar entradas ilegibles';

  @override
  String get backupFixLibrarySubtitle =>
      'Elimina de la biblioteca elementos cuyos id nunca cargarán capítulos (p. ej. importaciones erróneas)';

  @override
  String get backupFixLibraryNone => 'La biblioteca está limpia';

  @override
  String backupFixLibraryConfirm(num count) {
    return '¿Quitar $count entradas ilegibles?';
  }

  @override
  String get backupFixLibraryRemove => 'Quitar';

  @override
  String backupFixLibraryDone(num count) {
    return 'Se quitaron $count entradas';
  }

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

  @override
  String get refreshEveryHour => 'Cada hora';

  @override
  String get refreshEvery3Hours => 'Cada 3 horas';

  @override
  String get refreshEvery6Hours => 'Cada 6 horas';

  @override
  String get refreshEvery12Hours => 'Cada 12 horas';

  @override
  String get refreshDaily => 'Cada día';

  @override
  String get refreshEvery2Days => 'Cada 2 días';

  @override
  String get refreshEvery4Days => 'Cada 4 días';

  @override
  String get refreshWeekly => 'Cada semana';

  @override
  String get suggestionsRefresh => 'Actualizar sugerencias';

  @override
  String get suggestionsRefreshTitle => 'Frecuencia de sugerencias';

  @override
  String discoverPick(String source) {
    return 'Discover this pick from $source';
  }

  @override
  String get sourceFilter => 'Filtro';

  @override
  String get sourceListOptions => 'Opciones de lista';

  @override
  String get sourceListMode => 'Modo de lista';

  @override
  String get sourceGridSize => 'Tamaño de cuadrícula';

  @override
  String sourceGridSizeColumns(int columns) {
    return '$columns columnas';
  }

  @override
  String get sourceDomain => 'Dominio';

  @override
  String sourceDefault(String value) {
    return 'Predeterminado: $value';
  }

  @override
  String get sourceUserAgent => 'Encabezado UserAgent';

  @override
  String get sourceSignIn => 'Iniciar sesión';

  @override
  String get sourceNotSignedIn => 'No has iniciado sesión';

  @override
  String get sourceClearCookies => 'Borrar cookies';

  @override
  String get sourceClearCookiesSubtitle =>
      'Borrar cookies solo para el dominio especificado. En la mayoría de los casos esto invalidará la autorización.';

  @override
  String get sourceCookiesCleared => 'Se eliminaron todas las cookies';

  @override
  String get sourceAuthorized => 'Autorizado';

  @override
  String get sourceCaptchaSolver =>
      'Desactivar la resolución automática de CAPTCHA';

  @override
  String get sourceCaptchaSolverSubtitle =>
      'No intentes resolver CAPTCHA silenciosamente en segundo plano. Se te pedirá que lo resuelvas manualmente.';

  @override
  String get sourceCaptchaNotif => 'Desactivar notificaciones de CAPTCHA';

  @override
  String get sourceCaptchaNotifSubtitle =>
      'No recibirás notificaciones sobre la resolución de CAPTCHA en esta fuente, pero esto puede romper operaciones en segundo plano (comprobación de capítulos nuevos, obtener recomendaciones, etc.).';

  @override
  String get sourceDownloadSlowdown => 'Ralentizar descargas';

  @override
  String get sourceDownloadSlowdownSubtitle =>
      'Ayuda a evitar el bloqueo de tu dirección IP.';

  @override
  String get sourceTest => 'Probar fuente';

  @override
  String get sourceTestSubtitle =>
      'Comprueba la conexión y muestra la respuesta';

  @override
  String get sourceTestTitles => 'Títulos';

  @override
  String get sourceTestError => 'Error';

  @override
  String get sourceTestUnknown => 'Fuente no encontrada';

  @override
  String get sourceOpenInBrowser => 'Abrir en el navegador web';

  @override
  String get signInLoggedInAs => 'Sesión iniciada como';

  @override
  String get captchaRequiredTitle =>
      'Esta fuente requiere resolver un captcha para continuar.';

  @override
  String get captchaSolve => 'Resolver';

  @override
  String get captchaSolveTitle => 'Resolver captcha';

  @override
  String get captchaSolveHint =>
      'Completa la verificacion en el navegador y continua.';

  @override
  String get captchaContinue => 'Continuar';

  @override
  String get captchaStatusTitle => 'Lo que muestra el navegador';

  @override
  String get captchaStatusPage => 'Pagina';

  @override
  String get captchaStatusChallenge => 'Desafio';

  @override
  String get captchaStatusContent => 'Contenido';

  @override
  String get captchaStatusCookies => 'Cookies';

  @override
  String get captchaChallengeNone => 'ninguno visible';

  @override
  String get captchaChallengeOnScreen => 'EN PANTALLA';

  @override
  String get captchaChallengeUnknown => 'la pagina aun no ha cargado';

  @override
  String get captchaContentEmpty => 'vacio';

  @override
  String get captchaContentLoaded => 'cargado';

  @override
  String get webviewMissingTitle => 'Sin navegador integrado';

  @override
  String get webviewMissingBody =>
      'Esta pantalla necesita un navegador integrado, que esta plataforma no tiene. Una fuente protegida por un captcha no se puede abrir aquí.';

  @override
  String get rsetDefaultsNote =>
      'Estos son los valores por defecto de un título nuevo. Un manga que ya hayas configurado conserva su propia opción.';

  @override
  String get rsetDefaultMode => 'Modo por defecto';

  @override
  String get rsetDefaultModeSub =>
      'Así se abre un capítulo si no has configurado uno para este título';

  @override
  String get rsetModeStandard => 'Estándar';

  @override
  String get rsetModeRtl => 'De derecha a izquierda';

  @override
  String get rsetModeVertical => 'Vertical';

  @override
  String get rsetModeWebtoon => 'Webtoon';

  @override
  String get rsetScaleMode => 'Modo de escalado';

  @override
  String get rsetScaleModeSub => 'Cómo ocupa la página la pantalla';

  @override
  String get rsetScaleFitCenter => 'Ajustar al centro';

  @override
  String get rsetScaleFitHeight => 'Ajustar a la altura';

  @override
  String get rsetScaleFitWidth => 'Ajustar al ancho';

  @override
  String get rsetScaleKeepAtStart => 'Mantener en el inicio';

  @override
  String get rsetSectionReading => 'Reading';

  @override
  String get rsetSectionStrip => 'Vertical & webtoon';

  @override
  String get rsetWebtoonZoomOut => 'Alejar por defecto';

  @override
  String get rsetWebtoonZoomOutSub =>
      'Estrecha la tira para que los paneles largos se lean mejor';

  @override
  String get rsetWebtoonGaps => 'Separación entre páginas';

  @override
  String get rsetWebtoonGapsSub =>
      'Separa los paneles para que se vea dónde acaba uno y empieza otro';

  @override
  String get rsetStripUnavailable =>
      'Solo se usa en los modos vertical y webtoon';

  @override
  String get rsetTwoPagesUnavailable =>
      'Solo se usa en los modos estándar y de derecha a izquierda';

  @override
  String get rsetVolumeButtons => 'Activar botones de volumen';

  @override
  String get rsetVolumeButtonsSub =>
      'Cambia de página con las teclas de volumen mientras hay un capítulo abierto';

  @override
  String get rsetVolumeButtonsUnavailable =>
      'No disponible en este dispositivo — iOS no ofrece a las apps forma de leer los botones de volumen';

  @override
  String get rsetInvertNavigation => 'Invertir control de navegación';

  @override
  String get rsetInvertNavigationSub => 'Desliza y avanza al revés';

  @override
  String get rsetReduceMemory => 'Reducir consumo de memoria (beta)';

  @override
  String get rsetReduceMemorySub =>
      'Reduce la caché de páginas y precarga menos páginas';

  @override
  String get rsetSectionEInk => 'E-Ink';

  @override
  String get rsetSectionControls => 'Controles';

  @override
  String get rsetFlashOnChange => 'Parpadeo al cambiar de página';

  @override
  String get rsetFlashOnChangeSub =>
      'Limpia la pantalla entre páginas para eliminar la imagen fantasma';

  @override
  String get rsetFlashDuration => 'Duración del parpadeo';

  @override
  String get rsetFlashDurationSub =>
      'Cuánto tiempo se mantiene limpia la pantalla';

  @override
  String get rsetFlashEvery => 'Parpadear cada';

  @override
  String get rsetFlashEverySub =>
      'Limpia la pantalla una vez cada varias páginas en vez de cada página';

  @override
  String rsetFlashEveryUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get rsetFlashWith => 'Parpadear con';

  @override
  String get rsetFlashWithSub => 'A qué color se limpia la pantalla';

  @override
  String get rsetFlashWhite => 'Blanco';

  @override
  String get rsetFlashBlack => 'Negro';

  @override
  String get rsetSectionDisplay => 'Pantalla';

  @override
  String get rsetFullscreen => 'Modo pantalla completa';

  @override
  String get rsetFullscreenSub => 'Oculta las barras del sistema mientras lees';

  @override
  String get rsetOrientation => 'Orientación de la pantalla';

  @override
  String get rsetOrientationSub =>
      'Por defecto el lector se queda como lo abriste';

  @override
  String get rsetOrientDefault => 'Por defecto';

  @override
  String get rsetOrientAutomatic => 'Automática';

  @override
  String get rsetOrientPortrait => 'Vertical';

  @override
  String get rsetOrientLandscape => 'Horizontal';

  @override
  String get rsetKeepScreenOn => 'Mantener pantalla encendida';

  @override
  String get rsetKeepScreenOnSub =>
      'Evita que la pantalla se apague mientras hay un capítulo abierto';

  @override
  String get rsetShowInfoBar => 'Mostrar barra de información en el lector';

  @override
  String get rsetShowInfoBarSub => 'Progreso, batería y hora sobre la página';

  @override
  String get rsetTransparentInfoBar =>
      'Barra de información del lector transparente';

  @override
  String get rsetTransparentInfoBarSub =>
      'Al desactivarla se pone una franja oscura detrás del texto';

  @override
  String get rsetShowChapterPopup => 'Mostrar aviso de cambio de capítulo';

  @override
  String get rsetShowChapterPopupSub =>
      'Muestra el nombre del capítulo al cambiar de página';

  @override
  String get rsetSectionPages => 'Páginas';

  @override
  String get rsetBackground => 'Fondo';

  @override
  String get rsetBackgroundSub => 'El color detrás de la página';

  @override
  String get rsetBgDefault => 'Por defecto';

  @override
  String get rsetBgLight => 'Claro';

  @override
  String get rsetBgDark => 'Oscuro';

  @override
  String get rsetBgWhite => 'Blanco';

  @override
  String get rsetBgBlack => 'Negro';

  @override
  String get rsetNumberedPages => 'Páginas numeradas';

  @override
  String get rsetNumberedPagesSub =>
      'Imprime el contador de página sobre la propia página';

  @override
  String get rsetPreload => 'Precargar páginas';

  @override
  String get rsetPreloadSub =>
      'Descarga páginas por adelantado de la que estás leyendo';

  @override
  String get rsetPreloadAlways => 'Siempre';

  @override
  String get rsetPreloadWifiOnly => 'Solo con Wi-Fi';

  @override
  String get rsetPreloadNever => 'Nunca';

  @override
  String get rsetTwoPages => 'Dos páginas en horizontal';

  @override
  String get rsetTwoPagesSub => 'Muestra un doble en vez de una sola página';

  @override
  String get rsetReset => 'Restablecer ajustes del lector';

  @override
  String get rsetResetSub =>
      'Devuelve todos los ajustes de esta pantalla a su valor original';

  @override
  String get rsetResetTitle => '¿Restablecer los ajustes del lector?';

  @override
  String get rsetResetBody =>
      'Todos los ajustes del lector vuelven a su valor por defecto. No se tocan los que hayas hecho en títulos individuales.';

  @override
  String get settingsReaderActions => 'Acciones del lector';

  @override
  String get ractMenuSubtitle => 'Qué hace un toque en cada parte de la página';

  @override
  String get ractMenuOverflow => 'Más';

  @override
  String get ractReset => 'Restablecer';

  @override
  String get ractDisableAll => 'Desactivar todas';

  @override
  String get ractResetDone => 'Acciones del lector restablecidas';

  @override
  String get ractDisabledAll => 'Todas las acciones del lector desactivadas';

  @override
  String get ractTapAction => 'Acción al tocar';

  @override
  String get ractLongTapAction => 'Acción al mantener pulsado';

  @override
  String get ractActionNone => 'Ninguna';

  @override
  String get ractActionNextPage => 'Página siguiente';

  @override
  String get ractActionPrevPage => 'Página anterior';

  @override
  String get ractActionNextChapter => 'Capítulo siguiente';

  @override
  String get ractActionPrevChapter => 'Capítulo anterior';

  @override
  String get ractActionToggleUi => 'Mostrar/ocultar interfaz';

  @override
  String get ractActionShowMenu => 'Mostrar menú';
}
