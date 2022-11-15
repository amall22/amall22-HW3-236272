import 'package:english_words/english_words.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Set<WordPair> getSaved() {
    return _saved;
  }

}