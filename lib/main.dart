import 'package:firebase_core/firebase_core.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AuthRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User? _user;
  Status _status = Status.Uninitialized;

  AuthRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _user = _auth.currentUser;
    _onAuthStateChanged(_user);
  }

  Status get status => _status;

  User? get user => _user;
  bool get isAuthenticated => status == Status.Authenticated;

  var _saved = <WordPair>{};

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _saved = await getPairs();
      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }

  Future<void> addPair(String pair, String part1, String part2) async{
    if(_status == Status.Authenticated){
      await _db.collection("users").doc(_user!.uid).collection("saved").doc(pair.toString()).set(
          {'first': part1, 'second': part2});
      _saved = await getPairs();
      notifyListeners();
    }

  }

  Future<void> removePair(String pair) async{
    if(_status == Status.Authenticated){
      await _db.collection("users").doc(_user!.uid).collection("saved").doc(pair.toString()).delete();
      _saved = await getPairs();
      notifyListeners();
    }
  }

  Future<Set<WordPair>> getPairs() async{
    Set<WordPair> res = {};

    await _db.collection("users").doc(_user!.uid).collection('saved').get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((result) {
        res.add(WordPair(result.data().entries.first.value.toString(), result.data().entries.last.value.toString()));
      });
    });
    return Future<Set<WordPair>>.value(res);
  }

  Future<void> uploadImage(File file) async{
    await _storage.ref('images').child(_user!.uid).putFile(file);
    notifyListeners();
  }
  Future<String> downloadImage() async{
    try {
      return await _storage.ref('images').child(_user!.uid).getDownloadURL();
    } on Exception catch(e){
      return "https://firebasestorage.googleapis.com/v0/b/hellome-7d8cb.appspot.com/o/images%2Fno-profile-picture.png?alt=media&token=2e30255e-a76f-4802-b4e8-2ae6bd6fba44";
    }

  }
  String? getEmail() {
    return _user!.email;
  }

  Set<WordPair> getSaved() {
    return _saved;
  }

}
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Center(
            child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return ChangeNotifierProvider(create: (_) => AuthRepository.instance(),
      child: MaterialApp(
        title: 'Startup Name Generator',
        initialRoute: '/',
        routes: {
          '/': (context) => const RandomWords(),
          '/login': (context) => LoginScreen(),
          '/favorites': (context) => const RandomWords(),
        },
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepPurple,
          ),
        ),
      )
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _Fav = <WordPair>{};
  var _cloudSaved = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  var user;
  var canBeDragged = true;
  SnappingSheetController sheetController = SnappingSheetController();

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _Fav.contains(pair) || (user.isAuthenticated && _cloudSaved.contains(pair));
    if(_Fav.contains(pair) && !_cloudSaved.contains(pair)){
      user.addPair(pair.toString(), pair.first, pair.second);
    }
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(     // NEW from here...
        alreadySaved ? Icons.star : Icons.star_border,
        color: alreadySaved ? Colors.deepPurple : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () {      // NEW lines from here...
        setState(() {
          if (alreadySaved) {
            _Fav.remove(pair);
            user.removePair(pair.toString());
            _cloudSaved = user.getSaved();
          } else {
            _Fav.add(pair);
            user.addPair(pair.toString(), pair.first, pair.second);
            _cloudSaved = user.getSaved();
          }
        });
      },
    );
  }


  Future<bool> confirm(wp) async{
    bool to_delete = false;
    var button_style = ElevatedButton.styleFrom(primary: Colors.deepPurple, onPrimary: Colors.white);
    await showDialog(context: context, builder: (_) {
      return AlertDialog(title: const Text("Delete Suggestion"),
        content: Text("Are you sure you want to delete $wp from your saved suggestions?"),
        actions: [
          TextButton(onPressed: () {
            to_delete = true;
            Navigator.of(context).pop();},
              style: button_style,
              child: const Text("Yes")),
          TextButton(onPressed: () {
            Navigator.of(context).pop();},
              style: button_style,
              child: const Text("No")),
        ],
      );
    });
    return to_delete;
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        if (i.isOdd) {
          return const Divider();
        }
        final index = i ~/ 2;
        if (index >= _suggestions.length) {
          _suggestions.addAll(generateWordPairs().take(10));
        }
        return _buildRow(_suggestions[index]);
      },
    );
  }


  void _pushFav() {
    Navigator.of(context).push(
      // Add lines from here...
      MaterialPageRoute<void>(
        builder: (context) {
          user = Provider.of<AuthRepository>(context);
          if(user.isAuthenticated) {
            _cloudSaved = user.getSaved();
          }
          else{
            _cloudSaved.clear();
          }
          var completeSet = _Fav.union(_cloudSaved);
          final myTiles = completeSet.map((WordPair wp) {
            return Dismissible(key: UniqueKey(),
              confirmDismiss: (dir) async {
                return await confirm(wp.asPascalCase);
              },
              onDismissed: (dir) {
                setState(() {
                  _Fav.remove(wp);
                  _cloudSaved.remove(wp);
                  user.removePair(wp.toString());
                });

              },
              child: ListTile(
                title: Text(wp.asPascalCase, style: _biggerFont,),
              ),
              background: Container(
                child: Row(
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),),
                    Icon(
                      Icons.delete,
                      color: Colors.white,),
                    Text(
                      'Delete Suggestion',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    )
                  ],
                ),
                color: Colors.deepPurple,
              )
              ,);
          });

          final divided = myTiles.isNotEmpty ?
          ListTile.divideTiles(
            context: context,
            tiles:myTiles,
          ).toList()
              : <Widget>[];
          return Scaffold(
          appBar: AppBar(
          title: const Text('Saved Suggestions', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
          iconTheme: const IconThemeData(
          color: Colors.white, //change your color here
          ),
          ),
          body: ListView(children: divided,),
          );
        },
      ),
    );

  }


  void _goToLogin(){
    Navigator.pushNamed(context, '/login');
  }

  Future<void> _logout() async{
    _Fav.clear();
    _cloudSaved.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully logged out')));
    await user.signOut();
  }
  Container _displayPersonalInfo(){
    return Container(
      color: Colors.white,
      height: 50,
      child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Column(children: [
              Container(
                padding: const EdgeInsets.all(9.0),
                height: 58,
                color: Color(0xFFBDBDBD),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Welcome back, " + user.getEmail(), style: TextStyle(fontSize: 16)),
                      Icon(Icons.arrow_drop_up)
                    ]),
              ),
              const Padding(padding: EdgeInsets.all(5)),
              Row(children: [
                const Padding(padding: EdgeInsets.all(5)),
                FutureBuilder(
                  future: user.downloadImage(),
                  builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                    return CircleAvatar(
                        radius: 50.0,
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.purple,
                        backgroundImage: snapshot.data != null ? NetworkImage(snapshot.data.toString()): null
                    );
                  },
                ),
                const Padding(padding: EdgeInsets.all(5)),
                Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(user.getEmail(), style: const TextStyle(fontSize: 20)),
                      const Padding(padding: EdgeInsets.all(4)),
                      Container(
                        width: 160,
                        child: ElevatedButton(
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['png', 'jpg', 'gif', 'bmp', 'jpeg', 'webp'],
                            );
                            File file;
                            if (result != null) {
                              file = File(result.files.single.path.toString());
                              user.uploadImage(file);
                            } else {
                              const snackBar = SnackBar(content: Text("No image selected"));
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                            }
                          },
                          child: const Text('change avatar'),
                          style: ElevatedButton.styleFrom(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                          ),
                        ),
                      )
                      ,
                    ])
              ]),
            ]),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    user = Provider.of<AuthRepository>(context);

    if(user.isAuthenticated){
      _cloudSaved = user.getSaved();
    }

    GestureDetector _homeScreen(){
      return GestureDetector(
          child: SnappingSheet(
            controller: sheetController,
            lockOverflowDrag: true,
            snappingPositions: [
              SnappingPosition.factor(
                positionFactor: 0.8,
                snappingCurve: Curves.easeOutExpo,
                snappingDuration: Duration(seconds: 1),
                grabbingContentOffset: GrabbingContentOffset.top,
              ),
              SnappingPosition.pixels(
                positionPixels: 200,
                snappingCurve: Curves.elasticOut,
                snappingDuration: Duration(milliseconds: 1750),
              ),
            ],
            child: Stack(
              fit: StackFit.expand,
              children: [_buildSuggestions(), !canBeDragged? Container() :
              Container(
                child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5.0,sigmaY: 5.0),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6)
                        ),
                      ),
                    )
                ),)
              ],
            ),
            sheetBelow: SnappingSheetContent(
              draggable: canBeDragged,
              child: _displayPersonalInfo(),
              //heightBehavior: SnappingSheetHeight.fit(),
            ),

          ),
          onTap: () => {
            setState(() {
              if (canBeDragged) {
                canBeDragged = false;
                sheetController.snapToPosition(
                    const SnappingPosition.factor(
                        positionFactor: 0.083,
                        snappingCurve: Curves.easeInBack,
                        snappingDuration: Duration(milliseconds: 1)));
              } else {
                canBeDragged = true;
                sheetController
                    .snapToPosition(const SnappingPosition.factor(
                  positionFactor: 0.265,
                ));
              }
            })
          });
    }
    return Scaffold (
      appBar: AppBar(
        title: const Text('Startup Name Generator', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            color: Colors.white,
            onPressed: _pushFav,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            icon: user.isAuthenticated? const Icon(Icons.exit_to_app): const Icon(Icons.login),
            color: Colors.white,
            onPressed: user.isAuthenticated? _logout: _goToLogin,
            tooltip: user.isAuthenticated? "Logout": "Login",
          ),
        ],
      ),
      body: user.isAuthenticated? _homeScreen() : _buildSuggestions(),
    );
  }
}




class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthRepository>(context);
    var _email = TextEditingController(text: "");
    var _password = TextEditingController(text: "");
    var _confirm_Password = TextEditingController(text: "");
    var _identical_Passwords = true;

    Column _buildBottomConfirm(){
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please confirm your password below:',
              style: TextStyle(fontSize: 17)),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm_Password,
            obscureText: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
              errorText: _identical_Passwords ? null : 'Passwords must match',
            ),
          ),
          Padding(padding: const EdgeInsets.all(15.0),
            child: ElevatedButton(
              onPressed: () async {
                if(_password.text == _confirm_Password.text){
                  user.signUp(_email.text, _password.text);
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
                else{
                  setState(() {
                    _identical_Passwords = false;
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                }
              },
              child: const Text('Confirm'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(350, 42),
                shape: const StadiumBorder(),
                primary: Colors.blue,
                onPrimary: Colors.white,
              ),
            ),
          )
        ],
      );
    }


    return Scaffold(
      appBar: AppBar(
          title: const Text('Login', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
          iconTheme: const IconThemeData(
            color: Colors.white, //change your color here
          )
      ),
      body: Column(
        children: <Widget>[
          const Padding(
              padding: EdgeInsets.all(5.0),
              child: (Text(
                  'Welcome to Startup Names Generator, please log in below',
                  style: TextStyle(fontSize: 18,)
              ))),
          const SizedBox(height: 15),
          TextField(
            controller: _email,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Email',
            ),
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
            ),
          ),
          const SizedBox(height: 35),
          user.status == Status.Authenticating?
          const Center(child: CircularProgressIndicator()):
          Padding(padding: const EdgeInsets.all(10.0),
            child: ElevatedButton(
              onPressed: () async {
                if (!await user.signIn(_email.text, _password.text)) {
                  const snackBar = SnackBar(content: Text('There was an error logging into the app'));
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
                else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Login'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(350, 42),
                shape: const StadiumBorder(),
                primary: Colors.deepPurple,
                onPrimary: Colors.white,
              ),
            ),

          ),
          Padding(padding: const EdgeInsets.all(10.0),
            child: ElevatedButton(
              onPressed: () async {
                if (await user.signUp(_email.text, _password.text) == null) {
                  const snackBar = SnackBar(content: Text('There was an error logging into the app'));
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
                else {
                  Navigator.pop(context);
                }
              },
              child: const Text('New user? Click to sign up'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(350, 42),
                shape: const StadiumBorder(),
                primary: Colors.blue,
                onPrimary: Colors.white,
              ),
            ),

          ),
        ],
      ),
    );
  }
}
