/// Configuration du backend EC2
class ApiConfig {
  static const String host     = '44.194.121.188';
  static const int    port     = 3000;
  static const String baseUrl  = 'http://$host:$port';
  static const String wsUrl    = 'ws://$host:$port/ws';
}
