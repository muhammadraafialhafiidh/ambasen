import '../models/matakuliah.dart';
import '../models/user_session.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  UserSession? user;
  List<Matakuliah> matakuliahList = [];
  bool isLoggedIn = false;

  void setUser(UserSession session) {
    user = session;
    isLoggedIn = true;
  }

  void setMatakuliah(List<Matakuliah> list) {
    matakuliahList = list;
  }

  void clear() {
    user = null;
    matakuliahList = [];
    isLoggedIn = false;
  }
}
