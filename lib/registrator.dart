import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

void registerIFrame(String viewID, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewID,
    (int viewId) {
      final element = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return element;
    },
  );
}

void registerChartWeb(String viewID, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewID,
    (int viewId) {
      final element = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return element;
    },
  );
}
