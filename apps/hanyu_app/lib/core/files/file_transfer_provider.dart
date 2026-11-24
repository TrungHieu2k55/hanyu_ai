import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_file_transfer.dart';

final localFileTransferProvider = Provider<LocalFileTransfer>(
  (ref) => DeviceLocalFileTransfer(),
);
