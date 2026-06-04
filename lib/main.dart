import 'package:flutter/material.dart';

import 'app.dart';
import 'services/current_user_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CurrentUserStore.restoreFromLocalStorage();
  runApp(const VerificarteApp());
}
