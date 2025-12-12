import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveHelper {
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  /// Sign in and get Drive API client
  static Future<drive.DriveApi?> signInAndGetDriveApi() async {
    final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (account == null) return null;
    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  /// Upload a file directly from a given local path
  static Future<void> uploadLocalExcelFile(String filePath) async {
    final driveApi = await signInAndGetDriveApi();
    if (driveApi == null) {
      print("❌ Google Sign-In failed or cancelled");
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      print("⚠️ File not found at $filePath");
      return;
    }

    const folderName = "SmartIoT_Backups";
    String? folderId;

    // Create/find folder
    final folderList = await driveApi.files.list(
      q: "name='$folderName' and mimeType='application/vnd.google-apps.folder'",
    );
    if (folderList.files!.isEmpty) {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = "application/vnd.google-apps.folder";
      final created = await driveApi.files.create(folder);
      folderId = created.id;
    } else {
      folderId = folderList.files!.first.id;
    }

    final driveFile = drive.File()
      ..name = file.uri.pathSegments.last
      ..parents = [folderId!];

    final media = drive.Media(file.openRead(), await file.length());
    final uploaded = await driveApi.files.create(driveFile, uploadMedia: media);
    print("✅ Uploaded ${uploaded.name} to Google Drive");
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
