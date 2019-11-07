import 'src/doc_surveyor.dart';

/// Example run:
///
/// $ dart lib/main.dart <path-to-provider-repo>/packages/provider
/// 122 public members
/// Members without docs:
/// Void • <path-to-provider-repo>/packages/provider/lib/src/proxy_provider.dart • 107:1
/// NumericProxyProvider • <path-to-provider-repo>/packages/provider/lib/src/proxy_provider.dart • 177:1
/// Score: 0.98
///
main(List<String> args) async {
  final stats = await analyzeDocs(args[0]);
  print('${stats.publicMemberCount} public members');
  print('Members without docs:');
  final locations = stats.undocumentedMemberLocations;
  locations.forEach((l) => print(l.asString()));

  final score =
      ((stats.publicMemberCount - locations.length) / stats.publicMemberCount)
          .toStringAsFixed(2);
  print('Score: $score');
}
