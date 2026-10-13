import Flutter
import WidgetKit

/// The app's half of the `heart/widgets` channel (#161): Dart publishes the
/// user's training per day, this keeps it in the app group for the widget
/// extension and redraws the widget when it changed.
enum HomeWidgetsChannel {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "heart/widgets", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setTraining":
                // null, or anything unreadable, is nobody's training: the
                // widget draws empty rather than someone else's
                if TrainingSnapshot.write(TrainingSnapshot(map: call.arguments)) {
                    WidgetCenter.shared.reloadTimelines(ofKind: TrainingSnapshot.kind)
                }
                result(nil)
            case "setGoals":
                // the Goals widget (#368): null, or anything unreadable, is
                // nobody's goals
                if GoalsSnapshot.write(GoalsSnapshot(map: call.arguments)) {
                    WidgetCenter.shared.reloadTimelines(ofKind: GoalsSnapshot.kind)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
