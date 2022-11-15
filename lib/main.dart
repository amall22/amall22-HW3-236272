import 'package:english_words/english_words.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'statemanage.dart';

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
          return const MyApp();
        }
        return const Center(child: CircularProgressIndicator());
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
            '/login': (context) => const LoginScreen(),
            '/favorite': (context) => const RandomWords(),
          },
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
            ),
          ),
        ));
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _localSaved = <WordPair>{};
  var _cloudSaved = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  var user;

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _localSaved.contains(pair) || (user.isAuthenticated && _cloudSaved.contains(pair));
    if(_localSaved.contains(pair) && !_cloudSaved.contains(pair)){
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
            _localSaved.remove(pair);
            user.removePair(pair.toString());
            _cloudSaved = user.getSaved();

          } else {
            _localSaved.add(pair);
            user.addPair(pair.toString(), pair.first, pair.second);
            _cloudSaved = user.getSaved();
          }
        });
      },
    );
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

  Future<bool> confirm(wp) async{
    bool toDelete = false;
    var buttonStyle = ElevatedButton.styleFrom(primary: Colors.deepPurple, onPrimary: Colors.white);
    await showDialog(context: context, builder: (_) {
      return AlertDialog(title: const Text("Delete Suggestion"),
        content: Text("Are you sure you want to delete $wp from your saved suggestions?"),
        actions: [
          TextButton(onPressed: () { toDelete = true; Navigator.of(context).pop();}, style: buttonStyle,child: const Text("Yes")),
          TextButton(onPressed: () { Navigator.of(context).pop();}, style: buttonStyle,child: const Text("No")),
        ],
      );
    });

    return toDelete;
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          user = Provider.of<AuthRepository>(context);
          if(user.isAuthenticated) {
            _cloudSaved = user.getSaved();
          }
          else{
            _cloudSaved.clear();
          }
          var completeSet = _localSaved.union(_cloudSaved);
          final myTiles = completeSet.map((WordPair wp) {
            return Dismissible(key: UniqueKey(),
              confirmDismiss: (dir) async {
                return await confirm(wp.asPascalCase);
              },
              onDismissed: (dir) {
                setState(() {
                  _localSaved.remove(wp);
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
  Future<void> _logout() async {
    _localSaved.clear();
    _cloudSaved.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully logged out')));
    await user.signOut();
  }

  @override
  Widget build(BuildContext context) {
    user = Provider.of<AuthRepository>(context);

    if(user.isAuthenticated){
      _cloudSaved = user.getSaved();
    }

    return Scaffold (
      appBar: AppBar(
        title: const Text('Startup Name Generator', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            color: Colors.white,
            onPressed: _pushSaved,
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
      body: _buildSuggestions(),
    );
  }

}

class LoginScreen extends StatefulWidget{
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen>{

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthRepository>(context);
    var _email = TextEditingController(text: "");
    var _password = TextEditingController(text: "");

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
        ],
      ),
    );
  }
}