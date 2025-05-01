import 'dart:html' as html;
import 'dart:js' as js;

class WebImpl {
  static void openAuthWindow(String url) {
    final authWindow = html.window.open(
      url,
      'fitbit_auth',
      'width=800,height=600,menubar=no,toolbar=no,location=no',
    );
    if (authWindow == null) {
      html.window.location.href = url;
    }
  }

  static void setupAuthListener(Function callback) {
    js.context['handleFitbitAuth'] = (dynamic result) {
      if (result != null && result.toString().contains('access_token=')) {
        callback(result.toString());
      }
    };

    html.window.addEventListener('message', (event) {
      final html.MessageEvent e = event as html.MessageEvent;
      if (e.origin == html.window.location.origin) {
        try {
          final data = e.data;
          if (data is Map && data.containsKey('fitbit-auth')) {
            final authUrl = data['fitbit-auth'];
            callback(authUrl);
          }
        } catch (e) {
          print('Error processing auth callback: $e');
        }
      }
    });
  }
}