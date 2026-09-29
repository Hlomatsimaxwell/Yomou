/// A chapter queued inside a download job, with its page list resolved at
/// enqueue time so the background worker never has to hit the source API.
class DownloadJobChapter {
  const DownloadJobChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.pages,
  });

  final String id;
  final double number;
  final String title;
  final List<String> pages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'title': title,
    'pages': pages,
  };

  factory DownloadJobChapter.fromJson(Map<String, dynamic> json) {
    return DownloadJobChapter(
      id: json['id'] as String? ?? '',
      number: (json['number'] as num?)?.toDouble() ?? 0,
      title: json['title'] as String? ?? '',
      pages: (json['pages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Lifecycle of a download job.
///
/// [paused] is distinct from [cancelled] on purpose: a paused job keeps its
/// completed chapters and its remaining queue, and can be resumed by
/// re-enqueueing the same jobId.
enum DownloadJobStatus {
  /// Registered with WorkManager, waiting for its constraints to be met.
  queued,

  /// The foreground service is active and downloading pages.
  running,

  /// Stopped by the user but still resumable.
  paused,

  /// Every chapter in the batch saved successfully.
  completed,

  /// The worker threw; [DownloadJob.error] carries the message.
  failed,

  /// Abandoned. Remaining chapters are not retried.
  cancelled;

  /// Still owned by WorkManager, i.e. not in a terminal state.
  bool get isOpen =>
      this == queued || this == running || this == paused;

  /// A job the user can act on (pause/resume/cancel).
  bool get isActive => this == queued || this == running;

  static DownloadJobStatus parse(String? value) {
    return DownloadJobStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DownloadJobStatus.queued,
    );
  }
}

/// One enqueued download batch. The `jobId` doubles as the WorkManager unique
/// work name, which is what lets the UI reconcile our row against the real
/// platform job state via `getWorkInfo`.
class DownloadJob {
  const DownloadJob({
    required this.jobId,
    required this.mangaId,
    required this.chapters,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.mangaTitle,
    this.coverUrl,
    this.sourceId,
    this.headers = const {},
    this.totalPages = 0,
    this.doneChapters = 0,
    this.donePages = 0,
    this.error,
  });

  final String jobId;
  final String mangaId;
  final String? mangaTitle;
  final String? coverUrl;
  final String? sourceId;
  final Map<String, String> headers;
  final List<DownloadJobChapter> chapters;
  final int totalPages;
  final int doneChapters;
  final int donePages;
  final DownloadJobStatus status;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalChapters => chapters.length;

  /// Fraction of pages on disk, 0..1.
  double get progress => totalPages == 0 ? 0 : donePages / totalPages;

  /// True once every chapter in the batch has saved at least one page.
  bool get isFinished =>
      totalChapters > 0 && doneChapters >= totalChapters;

  /// Chapters still owed, in queue order.
  List<DownloadJobChapter> get remaining => chapters.skip(doneChapters).toList();

  /// Copy with the given fields replaced. Used when reconciliation corrects a
  /// status without a round-trip through the database.
  DownloadJob copyWith({
    DownloadJobStatus? status,
    int? doneChapters,
    int? donePages,
    String? error,
  }) {
    return DownloadJob(
      jobId: jobId,
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      coverUrl: coverUrl,
      sourceId: sourceId,
      headers: headers,
      chapters: chapters,
      totalPages: totalPages,
      doneChapters: doneChapters ?? this.doneChapters,
      donePages: donePages ?? this.donePages,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
