enum AppLanguage { system, english }

/// Semua teks yang tampil di UI. Dua bahasa: Indonesia (ikut sistem) dan
/// English.
abstract class AppStrings {
  const AppStrings();

  String get languageCode;
  String get languageName;

  // Umum
  String get appName;
  String get next;
  String get start;
  String get skip;
  String get retry;
  String get cancel;
  String get delete;
  String get allow;
  String get clear;
  String get close;
  String ofCount(int index, int total);

  // Setup
  String get setupTitle1;
  String get setupBody1;
  String get setupTitle2;
  String get setupBody2;
  String get setupTitle3;
  String get setupBody3;
  String downloadsFolderHint(String path);

  // Login
  String get loginTitle;
  String get loginSubtitle;
  String get usernameLabel;
  String get passwordLabel;
  String get otpLabel;
  String get signIn;
  String get noAccount;
  String get preparingSession;
  String get fillCredentials;
  String loginError(String? code, String fallback);

  // Home
  String get searchHint;
  String get storage;
  String get recent;
  String get logout;
  String get language;
  String get followSystem;
  String get english;
  String get languageSubtitle;
  String get settings;
  String get appearance;
  String get dynamicColor;
  String get dynamicColorHint;
  String get amoledBlack;
  String get amoledHint;
  String downloadsActive(int count);
  String get savedToFolder;

  // Files
  String get files;
  String get allFiles;
  String get allUploads;
  String get allUploadsSubtitle;
  String get folderEmpty;
  String get typeFileName;
  String get noFiles;
  String loadFolderError(String error);
  String get newFolder;
  String get folderName;
  String get create;
  String get rename;
  String get uploadHere;
  String get deleteFolderTitle;
  String deleteFolderBody(String name);
  String get folderActions;
  String get uploadingFiles;
  String get proFeatureTitle;
  String get proFeatureBody;
  String get photos;
  String get noPhotos;

  // Storage / sync
  String get noFilesYet;
  String inFiles(int count);
  String get syncingTitle;
  String get syncFailedTitle;
  String get syncedTitle;
  String filesAgo(int count, String ago);

  // Transfers
  String get transfers;
  String get downloads;
  String get uploads;
  String get noDownloads;
  String get noDownloadsHint;
  String get noUploads;
  String get notificationsCard;
  String get notificationsDenied;
  String get preparingLink;
  String get waitingInQueue;
  String downloadingDetail(String received, String total, String speed, String via);
  String doneDetail(String size);
  String uploadDoneDetail(String size);
  String uploadingDetail(String sent, String total, String speed);
  String get canceled;
  String failedDetail(String error);
  String get openFileFailed;
  String get downloadDetails;
  String get tryPixeldrain;
  String get copyLink;
  String get waitingNetwork;
  String get storagePermission;
  String get storagePermissionHint;
  String get downloadFromLink;
  String get linkHint;
  String get paste;
  String get invalidLink;
  String get linkNotFound;
  String get uploadFile;
  String get addNew;
  String get linkAlbumNote;

  // Pengaturan lanjutan & fitur baru
  String get downloadsSection;
  String get connections;
  String connectionsHint(int count);
  String get notificationsProgress;
  String get notificationsProgressHint;
  String get saveFolder;
  String get fileAccess;
  String get fileAccessGranted;
  String get fileAccessMissing;
  String get behaviourSection;
  String get clipboardDetect;
  String get clipboardDetectHint;
  String get confirmDelete;
  String get confirmDeleteHint;
  String get dataSection;
  String get downloadHistory;
  String get clearHistory;
  String get noHistory;
  String get shareLink;
  String get share;
  String get sortBy;
  String get sortName;
  String get sortDate;
  String get sortSize;
  String get viewGrid;
  String get viewList;
  String get restarting;
  String get clipboardFound;
  String get about;
  String get version;
  String get openSettings;
  String attemptInfo(int count, String via);
  String get viaBypass;
  String get viaPixeldrain;

  // Aksi file
  String get download;
  String get downloadSubtitleBypass;
  String get downloadSubtitleDirect;
  String get copyDownloadLink;
  String get openInBrowser;
  String get copyPixeldrainLink;
  String get linkCopied;
  String get pixeldrainLinkCopied;
  String get deleteFileTitle;
  String deleteFileBody(String name);
  String downloadFailedSnack(String name, String error);
  String get alreadyDownloaded;
  String downloadingSnack(String name);
  String downloadStartedSnack(String name);
}

class StringsId extends AppStrings {
  const StringsId();

  @override
  String get languageCode => 'id';

  @override
  String get languageName => 'Bahasa Indonesia';

  @override
  String get appName => 'Dropify';

  @override
  String get next => 'Lanjut';

  @override
  String get start => 'Mulai';

  @override
  String get skip => 'Lewati';

  @override
  String get retry => 'Coba lagi';

  @override
  String get cancel => 'Batal';

  @override
  String get delete => 'Hapus';

  @override
  String get allow => 'Izinkan';

  @override
  String get clear => 'Bersihkan';

  @override
  String get close => 'Tutup';

  @override
  String ofCount(int index, int total) => '$index of $total';

  @override
  String get setupTitle1 => 'Semua file\ndi satu tempat';

  @override
  String get setupBody1 =>
      'Upload, jelajahi folder, dan rapikan semua file Pixeldrain langsung dari HP tanpa buka browser.';

  @override
  String get setupTitle2 => 'Download\ntanpa limit';

  @override
  String get setupBody2 =>
      'Setiap file yang kamu tekan dibuatkan link bypass baru, jadi unduhan tidak lagi kena batas kecepatan Pixeldrain.';

  @override
  String get setupTitle3 => 'Progres\nselalu terlihat';

  @override
  String get setupBody3 =>
      'File tersimpan di Download/Dropify dan progresnya muncul di notifikasi. Bisa lanjut walau aplikasi ditutup.';

  @override
  String downloadsFolderHint(String path) => 'Folder download: $path';

  @override
  String get loginTitle => 'Masuk ke Dropify';

  @override
  String get loginSubtitle =>
      'Pakai akun Pixeldrain kamu. File dan hasil download tetap di perangkat ini.';

  @override
  String get usernameLabel => 'Username / Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get otpLabel => 'Kode 2FA (6 digit)';

  @override
  String get signIn => 'Masuk';

  @override
  String get noAccount => 'Belum punya akun? Daftar di Pixeldrain';

  @override
  String get preparingSession => 'Menyiapkan sesi…';

  @override
  String get fillCredentials => 'Isi username/email dan password dulu.';

  @override
  String loginError(String? code, String fallback) {
    switch (code) {
      case 'user_not_found':
        return 'Username / email tidak ditemukan.';
      case 'password_incorrect':
        return 'Password salah.';
      case 'otp_required':
        return 'Akun ini memakai 2FA. Masukkan kode 6 digit.';
      case 'otp_incorrect':
        return 'Kode 2FA salah.';
      case 'rate_limited':
        return 'Terlalu banyak percobaan login. Coba lagi nanti.';
      case 'network':
        return 'Gagal terhubung ke Pixeldrain. Periksa koneksi kamu.';
      default:
        return fallback;
    }
  }

  @override
  String get searchHint => 'Cari file dan folder';

  @override
  String get storage => 'Penyimpanan';

  @override
  String get recent => 'Terbaru';

  @override
  String get logout => 'Keluar';

  @override
  String get language => 'Bahasa';

  @override
  String get followSystem => 'Ikuti sistem';

  @override
  String get english => 'English';

  @override
  String get languageSubtitle => 'Hanya English yang tersedia selain sistem.';

  @override
  String get settings => 'Pengaturan';

  @override
  String get appearance => 'Tampilan';

  @override
  String get dynamicColor => 'Warna ikut sistem';

  @override
  String get dynamicColorHint => 'Aksen mengikuti wallpaper / tema Android.';

  @override
  String get amoledBlack => 'AMOLED hitam';

  @override
  String get amoledHint => 'Latar hitam pekat, hemat daya di layar OLED.';

  @override
  String downloadsActive(int count) =>
      count == 1 ? 'Mengunduh 1 file' : 'Mengunduh $count file';

  @override
  String get savedToFolder => 'Tersimpan di Download/Dropify';

  @override
  String get files => 'Files';

  @override
  String get allFiles => 'Semua file';

  @override
  String get allUploads => 'Semua upload';

  @override
  String get allUploadsSubtitle => 'Semua file yang ada di akun Pixeldrain';

  @override
  String get folderEmpty => 'Folder kosong';

  @override
  String get typeFileName => 'Ketik nama file';

  @override
  String get noFiles => 'Tidak ada file';

  @override
  String loadFolderError(String error) => 'Folder tidak bisa dimuat: $error';

  @override
  String get newFolder => 'Folder baru';

  @override
  String get folderName => 'Nama folder';

  @override
  String get create => 'Buat';

  @override
  String get rename => 'Ganti nama';

  @override
  String get uploadHere => 'Upload ke sini';

  @override
  String get deleteFolderTitle => 'Hapus folder?';

  @override
  String deleteFolderBody(String name) =>
      '$name beserta isinya akan dihapus permanen.';

  @override
  String get folderActions => 'Aksi folder';

  @override
  String get uploadingFiles => 'Mengunggah file…';

  @override
  String get proFeatureTitle => 'Folder butuh akun Pro';

  @override
  String get proFeatureBody =>
      'Pixeldrain hanya membuka fitur folder (filesystem) untuk akun '
      'berlangganan. Semua file kamu tetap ada di "All uploads".';

  @override
  String get photos => 'Foto';

  @override
  String get noPhotos => 'Belum ada foto';

  @override
  String get noFilesYet => 'Belum ada file di Pixeldrain kamu.';

  @override
  String inFiles(int count) => 'dari $count file';

  @override
  String get syncingTitle => 'Menyinkronkan dengan Pixeldrain';

  @override
  String get syncFailedTitle => 'Sinkronisasi gagal';

  @override
  String get syncedTitle => 'Tersinkron dengan Pixeldrain';

  @override
  String filesAgo(int count, String ago) => '$count file · $ago';

  @override
  String get transfers => 'Transfer';

  @override
  String get downloads => 'Downloads';

  @override
  String get uploads => 'Uploads';

  @override
  String get noDownloads => 'Belum ada download.';

  @override
  String get noDownloadsHint =>
      'Tekan sebuah file untuk mengunduhnya. Setiap download memakai link bypass baru, jadi tidak kena limit Pixeldrain, dan hasilnya disimpan di Download/Dropify.';

  @override
  String get noUploads => 'Belum ada upload. Tekan tombol + untuk upload.';

  @override
  String get notificationsCard =>
      'Aktifkan notifikasi supaya progres download terlihat realtime.';

  @override
  String get notificationsDenied =>
      'Izin notifikasi ditolak. Progres download hanya terlihat di dalam aplikasi.';

  @override
  String get preparingLink => 'Menyiapkan link bypass…';

  @override
  String get waitingInQueue => 'Menunggu antrean';

  @override
  String downloadingDetail(String received, String total, String speed, String via) =>
      '$received / $total · $speed · $via';

  @override
  String doneDetail(String size) => 'Selesai · $size · Download/Dropify';

  @override
  String uploadDoneDetail(String size) => 'Selesai · $size';

  @override
  String uploadingDetail(String sent, String total, String speed) =>
      '$sent / $total · $speed/s';

  @override
  String get canceled => 'Dibatalkan';

  @override
  String failedDetail(String error) => 'Gagal: $error';

  @override
  String get openFileFailed => 'Tidak bisa membuka file ini.';

  @override
  String get downloadDetails => 'Detail download';

  @override
  String get tryPixeldrain => 'Pakai link Pixeldrain';

  @override
  String get copyLink => 'Salin link';

  @override
  String get waitingNetwork => 'Menunggu jaringan…';

  @override
  String get storagePermission =>
      'Butuh izin "Akses semua file" supaya bisa menyimpan ke Download/Dropify.';

  @override
  String get storagePermissionHint =>
      'Buka pengaturan izin, aktifkan akses file, lalu tekan Coba lagi.';

  @override
  String get downloadFromLink => 'Download dari link';

  @override
  String get linkHint => 'Tempel link Pixeldrain…';

  @override
  String get paste => 'Tempel';

  @override
  String get invalidLink =>
      'Link tidak dikenali. Contoh: https://pixeldrain.com/u/abcd1234';

  @override
  String get linkNotFound => 'File tidak ditemukan atau sudah dihapus.';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get addNew => 'Tambah';

  @override
  String get linkAlbumNote => 'Link album/folder akan diunduh sebagai ZIP.';

  @override
  String get downloadsSection => 'Download';

  @override
  String get connections => 'Koneksi paralel';

  @override
  String connectionsHint(int count) => '$count koneksi bersamaan';

  @override
  String get notificationsProgress => 'Notifikasi progres';

  @override
  String get notificationsProgressHint =>
      'Tampilkan progres unduhan di panel notifikasi.';

  @override
  String get saveFolder => 'Folder simpan';

  @override
  String get fileAccess => 'Akses file';

  @override
  String get fileAccessGranted => 'Diizinkan';

  @override
  String get fileAccessMissing => 'Belum diizinkan';

  @override
  String get behaviourSection => 'Perilaku';

  @override
  String get clipboardDetect => 'Deteksi link di clipboard';

  @override
  String get clipboardDetectHint =>
      'Tawarkan download saat clipboard berisi link Pixeldrain.';

  @override
  String get confirmDelete => 'Konfirmasi sebelum hapus';

  @override
  String get confirmDeleteHint =>
      'Tampilkan dialog sebelum menghapus file di Pixeldrain.';

  @override
  String get dataSection => 'Data';

  @override
  String get downloadHistory => 'Riwayat download';

  @override
  String get clearHistory => 'Hapus riwayat';

  @override
  String get noHistory => 'Belum ada riwayat download.';

  @override
  String get shareLink => 'Bagikan link';

  @override
  String get share => 'Bagikan';

  @override
  String get sortBy => 'Urutkan';

  @override
  String get sortName => 'Nama';

  @override
  String get sortDate => 'Tanggal';

  @override
  String get sortSize => 'Ukuran';

  @override
  String get viewGrid => 'Tampilan grid';

  @override
  String get viewList => 'Tampilan daftar';

  @override
  String get restarting => 'Menyegarkan tampilan…';

  @override
  String get clipboardFound => 'Link Pixeldrain terdeteksi di clipboard.';

  @override
  String get about => 'Tentang';

  @override
  String get version => 'Versi';

  @override
  String get openSettings => 'Buka pengaturan izin';

  @override
  String attemptInfo(int count, String via) =>
      'Percobaan ke-$count · $via';

  @override
  String get viaBypass => 'bypass';

  @override
  String get viaPixeldrain => 'pixeldrain';

  @override
  String get download => 'Download';

  @override
  String get downloadSubtitleBypass =>
      'Link bypass baru dibuat otomatis, tanpa limit Pixeldrain';

  @override
  String get downloadSubtitleDirect =>
      'Tanpa bypass (file ini tidak punya id publik)';

  @override
  String get copyDownloadLink => 'Salin link download';

  @override
  String get openInBrowser => 'Buka di browser';

  @override
  String get copyPixeldrainLink => 'Salin link Pixeldrain';

  @override
  String get linkCopied => 'Link disalin';

  @override
  String get pixeldrainLinkCopied => 'Link Pixeldrain disalin';

  @override
  String get deleteFileTitle => 'Hapus file?';

  @override
  String deleteFileBody(String name) =>
      '$name akan dihapus permanen dari Pixeldrain.';

  @override
  String downloadFailedSnack(String name, String error) =>
      'Gagal mengunduh $name: $error';

  @override
  String get alreadyDownloaded => 'sudah ada di Download/Dropify.';

  @override
  String downloadingSnack(String name) => '$name sedang diunduh…';

  @override
  String downloadStartedSnack(String name) =>
      'Mengunduh $name → Download/Dropify';
}

class StringsEn extends AppStrings {
  const StringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get languageName => 'English';

  @override
  String get appName => 'Dropify';

  @override
  String get next => 'Next';

  @override
  String get start => 'Get started';

  @override
  String get skip => 'Skip';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get allow => 'Allow';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String ofCount(int index, int total) => '$index of $total';

  @override
  String get setupTitle1 => 'Every file\nin one place';

  @override
  String get setupBody1 =>
      'Upload, browse folders and organise your Pixeldrain files right from your phone.';

  @override
  String get setupTitle2 => 'Downloads\nwithout limits';

  @override
  String get setupBody2 =>
      'Every file you tap gets a fresh bypass link, so downloads are no longer slowed down by Pixeldrain limits.';

  @override
  String get setupTitle3 => 'Progress\nnever hidden';

  @override
  String get setupBody3 =>
      'Files land in Download/Dropify and progress shows up in your notifications. Works even when the app is closed.';

  @override
  String downloadsFolderHint(String path) => 'Downloads folder: $path';

  @override
  String get loginTitle => 'Sign in to Dropify';

  @override
  String get loginSubtitle =>
      'Use your Pixeldrain account. Your files and downloads stay on this device.';

  @override
  String get usernameLabel => 'Username / Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get otpLabel => '2FA code (6 digits)';

  @override
  String get signIn => 'Sign in';

  @override
  String get noAccount => 'No account yet? Sign up on Pixeldrain';

  @override
  String get preparingSession => 'Preparing your session…';

  @override
  String get fillCredentials => 'Enter your username/email and password first.';

  @override
  String loginError(String? code, String fallback) {
    switch (code) {
      case 'user_not_found':
        return 'Username / email not found.';
      case 'password_incorrect':
        return 'Incorrect password.';
      case 'otp_required':
        return 'This account uses 2FA. Enter the 6-digit code.';
      case 'otp_incorrect':
        return 'Incorrect 2FA code.';
      case 'rate_limited':
        return 'Too many login attempts. Try again later.';
      case 'network':
        return 'Could not reach Pixeldrain. Check your connection.';
      default:
        return fallback;
    }
  }

  @override
  String get searchHint => 'Search files and folders';

  @override
  String get storage => 'Storage';

  @override
  String get recent => 'Recent';

  @override
  String get logout => 'Log out';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get english => 'English';

  @override
  String get languageSubtitle => 'English is the only extra language for now.';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get dynamicColor => 'Use system color';

  @override
  String get dynamicColorHint => 'Accent follows your Android wallpaper theme.';

  @override
  String get amoledBlack => 'AMOLED black';

  @override
  String get amoledHint => 'True black background, saves power on OLED screens.';

  @override
  String downloadsActive(int count) =>
      count == 1 ? 'Downloading 1 file' : 'Downloading $count files';

  @override
  String get savedToFolder => 'Saved to Download/Dropify';

  @override
  String get files => 'Files';

  @override
  String get allFiles => 'All files';

  @override
  String get allUploads => 'All uploads';

  @override
  String get allUploadsSubtitle => 'Every file in your Pixeldrain account';

  @override
  String get folderEmpty => 'This folder is empty';

  @override
  String get typeFileName => 'Type a file name';

  @override
  String get noFiles => 'No files';

  @override
  String loadFolderError(String error) => 'Folder could not be loaded: $error';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get uploadHere => 'Upload here';

  @override
  String get deleteFolderTitle => 'Delete folder?';

  @override
  String deleteFolderBody(String name) =>
      '$name and everything inside it will be permanently deleted.';

  @override
  String get folderActions => 'Folder actions';

  @override
  String get uploadingFiles => 'Uploading files…';

  @override
  String get proFeatureTitle => 'Folders need a Pro account';

  @override
  String get proFeatureBody =>
      'Pixeldrain only enables the folder (filesystem) feature for '
      'subscribed accounts. All your files are still under "All uploads".';

  @override
  String get photos => 'Photos';

  @override
  String get noPhotos => 'No photos yet';

  @override
  String get noFilesYet => 'No files in your Pixeldrain yet.';

  @override
  String inFiles(int count) => 'in $count files';

  @override
  String get syncingTitle => 'Syncing with Pixeldrain';

  @override
  String get syncFailedTitle => 'Sync failed';

  @override
  String get syncedTitle => 'Synced with Pixeldrain';

  @override
  String filesAgo(int count, String ago) => '$count files · $ago';

  @override
  String get transfers => 'Transfers';

  @override
  String get downloads => 'Downloads';

  @override
  String get uploads => 'Uploads';

  @override
  String get noDownloads => 'No downloads yet.';

  @override
  String get noDownloadsHint =>
      'Tap a file to download it. Every download uses a fresh bypass link, so Pixeldrain limits do not apply, and files are saved to Download/Dropify.';

  @override
  String get noUploads => 'No uploads yet. Tap + to upload a file.';

  @override
  String get notificationsCard =>
      'Turn on notifications to follow download progress in realtime.';

  @override
  String get notificationsDenied =>
      'Notification permission denied. Progress stays inside the app.';

  @override
  String get preparingLink => 'Creating bypass link…';

  @override
  String get waitingInQueue => 'Waiting in queue';

  @override
  String downloadingDetail(String received, String total, String speed, String via) =>
      '$received / $total · $speed · $via';

  @override
  String doneDetail(String size) => 'Done · $size · Download/Dropify';

  @override
  String uploadDoneDetail(String size) => 'Done · $size';

  @override
  String uploadingDetail(String sent, String total, String speed) =>
      '$sent / $total · $speed/s';

  @override
  String get canceled => 'Canceled';

  @override
  String failedDetail(String error) => 'Failed: $error';

  @override
  String get openFileFailed => 'Could not open this file.';

  @override
  String get downloadDetails => 'Download details';

  @override
  String get tryPixeldrain => 'Use Pixeldrain link';

  @override
  String get copyLink => 'Copy link';

  @override
  String get waitingNetwork => 'Waiting for network…';

  @override
  String get storagePermission =>
      'Needs "All files access" permission to save into Download/Dropify.';

  @override
  String get storagePermissionHint =>
      'Open permission settings, allow file access, then tap Retry.';

  @override
  String get downloadFromLink => 'Download from link';

  @override
  String get linkHint => 'Paste a Pixeldrain link…';

  @override
  String get paste => 'Paste';

  @override
  String get invalidLink =>
      'Link not recognised. Example: https://pixeldrain.com/u/abcd1234';

  @override
  String get linkNotFound => 'File not found or already deleted.';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get addNew => 'Add';

  @override
  String get linkAlbumNote => 'Album/folder links download as a ZIP.';

  @override
  String get downloadsSection => 'Downloads';

  @override
  String get connections => 'Parallel connections';

  @override
  String connectionsHint(int count) => '$count at a time';

  @override
  String get notificationsProgress => 'Progress notifications';

  @override
  String get notificationsProgressHint =>
      'Show download progress in the notification shade.';

  @override
  String get saveFolder => 'Save folder';

  @override
  String get fileAccess => 'File access';

  @override
  String get fileAccessGranted => 'Granted';

  @override
  String get fileAccessMissing => 'Not granted';

  @override
  String get behaviourSection => 'Behaviour';

  @override
  String get clipboardDetect => 'Detect links in clipboard';

  @override
  String get clipboardDetectHint =>
      'Offer to download when the clipboard holds a Pixeldrain link.';

  @override
  String get confirmDelete => 'Confirm before deleting';

  @override
  String get confirmDeleteHint =>
      'Show a dialog before removing files on Pixeldrain.';

  @override
  String get dataSection => 'Data';

  @override
  String get downloadHistory => 'Download history';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get noHistory => 'No downloads yet.';

  @override
  String get shareLink => 'Share link';

  @override
  String get share => 'Share';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortName => 'Name';

  @override
  String get sortDate => 'Date';

  @override
  String get sortSize => 'Size';

  @override
  String get viewGrid => 'Grid view';

  @override
  String get viewList => 'List view';

  @override
  String get restarting => 'Refreshing appearance…';

  @override
  String get clipboardFound => 'Pixeldrain link found in clipboard.';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get openSettings => 'Open permission settings';

  @override
  String attemptInfo(int count, String via) =>
      'Attempt $count · $via';

  @override
  String get viaBypass => 'bypass';

  @override
  String get viaPixeldrain => 'pixeldrain';

  @override
  String get download => 'Download';

  @override
  String get downloadSubtitleBypass =>
      'A new bypass link is generated automatically, no Pixeldrain limits';

  @override
  String get downloadSubtitleDirect =>
      'No bypass (this file has no public id)';

  @override
  String get copyDownloadLink => 'Copy download link';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get copyPixeldrainLink => 'Copy Pixeldrain link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get pixeldrainLinkCopied => 'Pixeldrain link copied';

  @override
  String get deleteFileTitle => 'Delete file?';

  @override
  String deleteFileBody(String name) =>
      '$name will be permanently deleted from Pixeldrain.';

  @override
  String downloadFailedSnack(String name, String error) =>
      'Could not download $name: $error';

  @override
  String get alreadyDownloaded => 'is already in Download/Dropify.';

  @override
  String downloadingSnack(String name) => 'Downloading $name…';

  @override
  String downloadStartedSnack(String name) =>
      'Downloading $name → Download/Dropify';
}
