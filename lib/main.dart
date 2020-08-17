import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database/sqllite_database_provider.dart';
// import 'package:path/path.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Drive',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: MyHomePage(title: 'Google Drive'),
    );
  }
}

//https://stackoverflow.com/questions/58072743/how-to-access-google-drive-appdata-folder-file-with-flutter
class GoogleHttpClient extends IOClient {
  Map<String, String> _headers;

  GoogleHttpClient(this._headers) : super();

  // @override
  // Future<http.StreamedResponse> send(http.BaseRequest request) =>
  //     super.send(request..headers.addAll(_headers));

  @override
  Future<http.Response> head(Object url, {Map<String, String> headers}) =>
      super.head(url, headers: headers..addAll(_headers));
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final storage = new FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn =
      GoogleSignIn(scopes: ['https://www.googleapis.com/auth/drive.appdata']);
  GoogleSignInAccount googleSignInAccount;
  ga.FileList list;
  var signedIn = false;

  @override
  void initState() {
    super.initState();
    final fido = Dog(
      id: 0,
      name: 'Fido',
      age: 35,
    );

    SQLiteDBProvider.instance.insertDog(fido);
  }

  Future<void> _loginWithGoogle() async {
    signedIn = await storage.read(key: "signedIn") == "true" ? true : false;
    googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount googleSignInAccount) async {
      if (googleSignInAccount != null) {
        _afterGoogleLogin(googleSignInAccount);
      }
    });
    if (signedIn) {
      try {
        try {
          final account = await googleSignIn.signInSilently();
          print("Successfully signed in as ${account.displayName}.");
        } on PlatformException catch (e) {
          // User not signed in yet. Do something appropriate.
          print(e);
          print("The user is not signed in yet. Asking to sign in.");
          final GoogleSignInAccount googleSignInAccount =
              await googleSignIn.signIn();
          _afterGoogleLogin(googleSignInAccount);
        }
      } catch (e) {
        storage.write(key: "signedIn", value: "false").then((value) {
          setState(() {
            signedIn = false;
          });
        });
      }
    } else {
      final GoogleSignInAccount googleSignInAccount =
          await googleSignIn.signIn();
      if (googleSignInAccount != null) {
        _afterGoogleLogin(googleSignInAccount);
      }
    }
  }

  Future<void> _afterGoogleLogin(GoogleSignInAccount gSA) async {
    googleSignInAccount = gSA;
    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );

    final AuthResult authResult = await _auth.signInWithCredential(credential);
    final FirebaseUser user = authResult.user;

    assert(!user.isAnonymous);
    assert(await user.getIdToken() != null);

    final FirebaseUser currentUser = await _auth.currentUser();
    assert(user.uid == currentUser.uid);

    print('signInWithGoogle succeeded: $user');

    storage.write(key: "signedIn", value: "true").then((value) {
      setState(() {
        signedIn = true;
      });
    });
  }

  void _logoutFromGoogle() async {
    googleSignIn.signOut().then((value) {
      print("User Sign Out");
      storage.write(key: "signedIn", value: "false").then((value) {
        setState(() {
          signedIn = false;
        });
      });
    });
  }
//https://tanaikech.github.io/2020/03/05/simple-script-of-resumable-upload-with-google-drive-api-for-python/
  _uploadFileToGoogleDrive() async {
    var strings = await SQLiteDBProvider.instance.getDBPath();
    var file = File(strings);

    var client = GoogleHttpClient(await googleSignInAccount.authHeaders);
    // var drive = ga.DriveApi(client);
    final headers = {
      'Authorization': client._headers["Authorization"],
      // 'X-Upload-Content-Type':'application/octet-stream',
      // 'X-Upload-Content-Length': filelengthInt.toString(),
      'Content-Type': 'application/json; charset=UTF-8',
      // 'Content-Length': fileData.length.toString()
    };
    final initialQueryParameters = {'uploadType': 'resumable'};
    final Map<String, dynamic> metaData = {
      'name': path.basename(file.absolute.path),
      'parents': ['appDataFolder']
    };
    final initiateUri = Uri.https(
        'www.googleapis.com', '/upload/drive/v3/files', initialQueryParameters);
    post(initiateUri, headers: headers, body: json.encode(metaData))
        .then((value) {
      _uploadDataToserver(value.headers["location"], headers);
      print(value.statusCode);
    }).catchError((error) {
      print(error);
    });
  }

  Future<void> _uploadDataToserver(String location,Map<String, String> headers) async {
    var strings = await SQLiteDBProvider.instance.getDBPath();
    print(strings);
    var file = File(strings);
    var filelengthInt = await file.length();
    // print(filelengthInt);
    var fileByteData = await file
        .readAsBytes(); //,'X-Upload-Content-Type': fileData.toString()
    print(fileByteData.length.toString());
    // var body = file.openRead();
    // print(body);
    // var responseJson;
    var lengthminusOne = filelengthInt - 1;
    headers['Content-Range'] = "bytes 0-" + lengthminusOne.toString() + "/" + filelengthInt.toString();
    try {
      final http.Response response = await http.put(
        location,
        headers: headers,
        body: fileByteData,
      );
      print(response);
      // responseJson = response;
    } on SocketException {
      throw FetchDataException('No Internet connection');
    }
  }

  Future<void> _listGoogleDriveFiles() async {
    var client = GoogleHttpClient(await googleSignInAccount.authHeaders);
    var drive = ga.DriveApi(client);
    // var data = drive.drives.list();
    // print(data);
    drive.files.list(spaces: 'appDataFolder').then((value) {
      setState(() {
        list = value;
      });
      for (var i = 0; i < list.files.length; i++) {
        // drive.files.delete(list.files[i].id);
        print("Id: ${list.files[i].id} File Name:${list.files[i].name}");
      }
    }).catchError((error) {
      print(error);
    });
  }

  Future<void> _downloadGoogleDriveFile(String fName, String gdID) async {
    var client = GoogleHttpClient(await googleSignInAccount.authHeaders);
    var drive = ga.DriveApi(client);

    await drive.files.get(gdID).then((value) {
      print(value);
    });

    // ga.Media file = await drive.files
    //     .get(gdID, downloadOptions: ga.DownloadOptions.Metadata);
    // print(file.stream);

    // final directory = await getExternalStorageDirectory();
    // print(directory.path);
    // final saveFile = File(
    //     '${directory.path}/${new DateTime.now().millisecondsSinceEpoch}$fName');
    // List<int> dataStore = [];
    // file.stream.listen((data) {
    //   print("DataReceived: ${data.length}");
    //   dataStore.insertAll(dataStore.length, data);
    // }, onDone: () {
    //   print("Task Done");
    //   saveFile.writeAsBytes(dataStore);
    //   print("File saved at ${saveFile.path}");
    // }, onError: (error) {
    //   print("Some Error");
    // });
  }

  List<Widget> generateFilesWidget() {
    List<Widget> listItem = List<Widget>();
    if (list != null) {
      for (var i = 0; i < list.files.length; i++) {
        listItem.add(Row(
          children: <Widget>[
            Container(
              width: MediaQuery.of(context).size.width * 0.05,
              child: Text('${i + 1}'),
            ),
            Expanded(
              child: Text(list.files[i].name),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.3,
              child: FlatButton(
                child: Text(
                  'Download',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                color: Colors.indigo,
                onPressed: () {
                  _downloadGoogleDriveFile(
                      list.files[i].name, list.files[i].id);
                },
              ),
            ),
          ],
        ));
      }
    }
    return listItem;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            (signedIn
                ? FlatButton(
                    child: Text('Upload File to Google Drive'),
                    onPressed: _uploadFileToGoogleDrive,
                    color: Colors.green,
                  )
                : Container()),
            (signedIn
                ? FlatButton(
                    child: Text('List Google Drive Files'),
                    onPressed: _listGoogleDriveFiles,
                    color: Colors.green,
                  )
                : Container()),
            (signedIn
                ? Expanded(
                    flex: 10,
                    child: Column(
                      children: generateFilesWidget(),
                    ),
                  )
                : Container()),
            (signedIn
                ? FlatButton(
                    child: Text('Google Logout'),
                    onPressed: _logoutFromGoogle,
                    color: Colors.green,
                  )
                : FlatButton(
                    child: Text('Google Login'),
                    onPressed: _loginWithGoogle,
                    color: Colors.red,
                  )),
          ],
        ),
      ),
    );
  }
}

class Dog {
  final int id;
  final String name;
  final int age;

  Dog({this.id, this.name, this.age});

  // Convert a Dog into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
    };
  }
}




class CustomException implements Exception {
  final _message;
  final _prefix;

  CustomException([this._message, this._prefix]);

  String toString() {
    return "$_prefix$_message";
  }
}

class FetchDataException extends CustomException {
  FetchDataException([String message])
      : super(message, "Error During Communication: ");
}

class BadRequestException extends CustomException {
  BadRequestException([message]) : super(message, "Invalid Request: ");
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([message]) : super(message, "Unauthorised: ");
}

class InvalidInputException extends CustomException {
  InvalidInputException([String message]) : super(message, "Invalid Input: ");
}