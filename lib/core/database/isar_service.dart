import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  late final Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    
    // We open Isar with schemas. Initially this list is empty. 
    // As we add features (e.g. step logs, sleep history), we register their schemas here.
    isar = await Isar.open(
      [],
      directory: dir.path,
    );
  }
}
