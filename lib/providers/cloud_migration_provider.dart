import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloud_migration_service.dart';

final cloudMigrationServiceProvider = Provider<CloudMigrationService>((ref) => CloudMigrationService());
