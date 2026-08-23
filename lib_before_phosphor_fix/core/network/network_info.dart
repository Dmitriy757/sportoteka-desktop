import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfoI {
  Future<bool> isConnected();

  Future<ConnectivityResult> get connectivityResult;

  Stream<ConnectivityResult> get onConnectivityChanged;
}

class NetworkInfo implements NetworkInfoI {
  final Connectivity connectivity;

  NetworkInfo(this.connectivity);

  @override
  Future<bool> isConnected() async {
    final results = await connectivity.checkConnectivity();

    return results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
  }

  @override
  Future<ConnectivityResult> get connectivityResult async {
    final results = await connectivity.checkConnectivity();

    if (results.isEmpty) {
      return ConnectivityResult.none;
    }

    return results.first;
  }

  @override
  Stream<ConnectivityResult> get onConnectivityChanged {
    return connectivity.onConnectivityChanged.map((results) {
      if (results.isEmpty) {
        return ConnectivityResult.none;
      }

      return results.first;
    });
  }
}