import Flutter
import UIKit
import CallKit
import AVFAudio
import PushKit
import flutter_callkit_incoming
import livekit_client

@main
@objc class AppDelegate:
  FlutterAppDelegate,
  FlutterImplicitEngineDelegate,
  PKPushRegistryDelegate,
  CallkitIncomingAppDelegate
{
  private var voipRegistry: PKPushRegistry?
  private var sportotekaCallBridge: FlutterMethodChannel?
  private let sportotekaPendingAcceptKey =
    "sportoteka_pending_call_accept"
  private var sportotekaCallBackgroundTask:
    UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CallKit owns iOS audio activation.
    // Do not allow WebRTC audio engine before CXProvider didActivate.
    LiveKitPlugin.setEngineAvailability(
      isInputAvailable: false,
      isOutputAvailable: false
    )

    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(
      with: engineBridge.pluginRegistry
    )

    let bridge = FlutterMethodChannel(
      name: "sportoteka/native_call_bridge",
      binaryMessenger:
        engineBridge.applicationRegistrar.messenger()
    )

    sportotekaCallBridge = bridge

    bridge.setMethodCallHandler {
      [weak self] call, result in

      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "consumePendingAccept":
        result(
          UserDefaults.standard.dictionary(
            forKey: self.sportotekaPendingAcceptKey
          )
        )

      case "clearPendingAccept":
        UserDefaults.standard.removeObject(
          forKey: self.sportotekaPendingAcceptKey
        )
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - PushKit token

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }

    let token = credentials.token
      .map { String(format: "%02x", $0) }
      .joined()

    print("SPORTOTEKA VOIP TOKEN: \(token)")

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?
      .setDevicePushTokenVoIP(token)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    guard type == .voIP else { return }

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?
      .setDevicePushTokenVoIP("")
  }

  // MARK: - PushKit incoming call

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let raw = payload.dictionaryPayload

    let callId = stringValue(raw["call_id"])

    // Пока системный CallKit звонит, следим за серверным
    // состоянием нативно. Это работает без Dart UI и нужно,
    // когда iPhone заблокирован.
    SportotekaCallStatusWatcher.shared.start(
      callId: callId,
      userId: stringValue(raw["callee_id"]),
      uuidString: stringValue(raw["uuid"])
    )
    let callerId = stringValue(raw["caller_id"])
    let calleeId = stringValue(raw["callee_id"])
    let channelId = stringValue(raw["channel_id"])
    let callerNameRaw = stringValue(raw["caller_name"])
    let callerPhoto = stringValue(raw["caller_photo"])
    let payloadUuid = stringValue(raw["uuid"])

    let callerName = callerNameRaw.isEmpty
      ? (callerId.isEmpty ? "Входящий звонок" : "Пользователь #\(callerId)")
      : callerNameRaw

    let uuid = payloadUuid.isEmpty ? UUID().uuidString : payloadUuid

    let data = flutter_callkit_incoming.Data(
      id: uuid,
      nameCaller: callerName,
      handle: "SPORTOTEKA",
      type: 0
    )

    data.extra = [
      "type": "incoming_call",
      "call_id": callId,
      "caller_id": callerId,
      "callee_id": calleeId,
      "channel_id": channelId,
      "caller_name": callerName,
      "caller_photo": callerPhoto,
      "transport": "livekit",
      "uuid": uuid
    ]

    // iOS 13+ requires every PushKit VoIP push to be reported to CallKit
    // immediately. Use the plugin completion callback so PushKit completion
    // is not returned before CXProvider has reported the incoming call.
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.showCallkitIncoming(data, fromPushKit: true) {
        completion()
      }
    } else {
      // Defensive fallback: the engine is normally registered before this
      // callback. Never leave PushKit completion hanging.
      completion()
    }
  }

  // MARK: - CallkitIncomingAppDelegate
  //
  // These native callbacks are deliberately tiny and reliable. They update
  // SPORTOTEKA's server even if the user taps Accept/Decline immediately
  // while the Dart isolate is still starting. Dart then opens LiveKit.

  func onAccept(
    _ call: flutter_callkit_incoming.Call,
    _ action: CXAnswerCallAction
  ) {
    let json = call.data.toJSON()
    let extra = dictionaryValue(json["extra"])

    let callId = stringValue(extra["call_id"])
    let userId = stringValue(extra["callee_id"])
    let callerId = stringValue(extra["caller_id"])
    let callerName = stringValue(extra["caller_name"])
    let uuid = call.uuid.uuidString

    let payload: [String: String] = [
      "call_id": callId,
      "user_id": userId,
      "caller_id": callerId,
      "caller_name": callerName,
      "uuid": uuid
    ]

    // Сохраняем Accept ДО перехода в Dart.
    // Даже если Flutter только запускается, событие не потеряется.
    UserDefaults.standard.set(
      payload,
      forKey: sportotekaPendingAcceptKey
    )

    beginSportotekaCallBackgroundTask()

    // Серверный статус переводим ringing -> accepted нативно.
    postSportotekaCallAction("accept", call: call)

    // CallKit не должен ждать Navigator или экран приложения.
    action.fulfill()

    guard let bridge = sportotekaCallBridge else {
      print(
        "SPORTOTEKA locked Accept: Flutter bridge not ready"
      )
      endSportotekaCallBackgroundTask()
      return
    }

    print(
      "SPORTOTEKA locked Accept -> Dart callId=\(callId)"
    )

    bridge.invokeMethod(
      "callAccepted",
      arguments: payload
    ) { [weak self] result in
      guard let self else { return }

      if let ok = result as? Bool, ok {
        UserDefaults.standard.removeObject(
          forKey: self.sportotekaPendingAcceptKey
        )

        print(
          "SPORTOTEKA locked Accept: LiveKit connected"
        )
      } else {
        print(
          "SPORTOTEKA locked Accept: Dart did not connect yet"
        )
      }

      self.endSportotekaCallBackgroundTask()
    }
  }

  func onDecline(
    _ call: flutter_callkit_incoming.Call,
    _ action: CXEndCallAction
  ) {
    action.fulfill()
    postSportotekaCallAction("decline", call: call)
  }

  func onEnd(
    _ call: flutter_callkit_incoming.Call,
    _ action: CXEndCallAction
  ) {
    action.fulfill()
    postSportotekaCallAction("end", call: call)
  }

  func onTimeOut(_ call: flutter_callkit_incoming.Call) {
    // The existing SPORTOTEKA call lifecycle converts stale ringing calls
    // to missed/no-answer. Do not incorrectly mark a timeout as "ended".
    print("SPORTOTEKA CALL TIMEOUT")
  }

  func didActivateAudioSession(
    _ audioSession: AVAudioSession
  ) {
    // Обычный голосовой звонок должен начинаться через receiver,
    // а не через громкий динамик.
    do {
      try audioSession.overrideOutputAudioPort(.none)

      print(
        "SPORTOTEKA iOS audio route -> receiver"
      )
    } catch {
      print(
        "SPORTOTEKA iOS receiver route error: \(error)"
      )
    }

    LiveKitPlugin.setEngineAvailability(
      isInputAvailable: true,
      isOutputAvailable: true
    )

    // После запуска WebRTC движка ещё раз фиксируем receiver.
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 0.20
    ) {
      do {
        try AVAudioSession.sharedInstance()
          .overrideOutputAudioPort(.none)
      } catch {
        print(
          "SPORTOTEKA iOS delayed receiver error: \(error)"
        )
      }
    }
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    // CallKit ended/deactivated the call.
    LiveKitPlugin.setEngineAvailability(
      isInputAvailable: false,
      isOutputAvailable: false
    )
  }

  func providerDidReset() {
    print("SPORTOTEKA CallKit provider reset")
  }

  private func beginSportotekaCallBackgroundTask() {
    guard sportotekaCallBackgroundTask == .invalid else {
      return
    }

    sportotekaCallBackgroundTask =
      UIApplication.shared.beginBackgroundTask(
        withName: "SPORTOTEKA Call Accept"
      ) { [weak self] in
        self?.endSportotekaCallBackgroundTask()
      }
  }

  private func endSportotekaCallBackgroundTask() {
    guard sportotekaCallBackgroundTask != .invalid else {
      return
    }

    UIApplication.shared.endBackgroundTask(
      sportotekaCallBackgroundTask
    )

    sportotekaCallBackgroundTask = .invalid
  }

  // MARK: - SPORTOTEKA native call actions

  private func postSportotekaCallAction(
    _ action: String,
    call: flutter_callkit_incoming.Call
  ) {
    let json = call.data.toJSON()
    let extra = dictionaryValue(json["extra"])

    let callId = stringValue(extra["call_id"])
    let userId = stringValue(extra["callee_id"])

    guard !callId.isEmpty, !userId.isEmpty else {
      print("SPORTOTEKA native call action missing IDs: \(action)")
      return
    }

    guard let url = URL(
      string: "https://sportotekaapp.ru/api/calls/\(action).php"
    ) else {
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(
      "application/x-www-form-urlencoded; charset=utf-8",
      forHTTPHeaderField: "Content-Type"
    )

    let body =
      "call_id=\(formEncode(callId))" +
      "&user_id=\(formEncode(userId))"

    request.httpBody = body.data(using: .utf8)
    request.timeoutInterval = 8

    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        print("SPORTOTEKA native \(action) error: \(error.localizedDescription)")
        return
      }

      if let http = response as? HTTPURLResponse {
        print("SPORTOTEKA native \(action) HTTP \(http.statusCode)")
      }
    }.resume()
  }

  private func dictionaryValue(_ value: Any?) -> [String: Any] {
    if let map = value as? [String: Any] {
      return map
    }

    if let dictionary = value as? NSDictionary {
      var result: [String: Any] = [:]

      for (key, value) in dictionary {
        if let key = key as? String {
          result[key] = value
        }
      }

      return result
    }

    return [:]
  }

  private func formEncode(_ value: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&+=?")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }

  private func stringValue(_ value: Any?) -> String {
    guard let value else { return "" }
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }
    return String(describing: value)
  }
}

// ============================================================
// SPORTOTEKA LOCK-SCREEN CALL STATUS WATCHER
// ============================================================
//
// PushKit wakes the native iOS application and CallKit displays
// the incoming call. Flutter/FCM can be suspended while the phone
// is locked, therefore the ringing lifecycle needs a native
// fallback.
//
// No second VoIP push is used here.
//
private final class SportotekaCallStatusWatcher {

  static let shared = SportotekaCallStatusWatcher()

  private var timer: Timer?
  private var requestInFlight = false

  private var watchedCallId = ""
  private var watchedUserId = ""
  private var watchedUuid: UUID?

  private var backgroundTask:
    UIBackgroundTaskIdentifier = .invalid

  private init() {}

  func start(
    callId: String,
    userId: String,
    uuidString: String
  ) {
    DispatchQueue.main.async {
      let cleanCallId =
        callId.trimmingCharacters(
          in: .whitespacesAndNewlines
        )

      let cleanUserId =
        userId.trimmingCharacters(
          in: .whitespacesAndNewlines
        )

      guard
        !cleanCallId.isEmpty,
        !cleanUserId.isEmpty
      else {
        print(
          "SPORTOTEKA LOCK WATCH missing IDs"
        )
        return
      }

      self.stopInternal()

      self.watchedCallId = cleanCallId
      self.watchedUserId = cleanUserId

      let cleanUuid =
        uuidString.trimmingCharacters(
          in: .whitespacesAndNewlines
        )

      if !cleanUuid.isEmpty,
         let uuid = UUID(uuidString: cleanUuid) {
        self.watchedUuid = uuid
      } else {
        self.watchedUuid =
          self.uuidForCallId(cleanCallId)
      }

      self.backgroundTask =
        UIApplication.shared.beginBackgroundTask(
          withName:
            "SPORTOTEKA incoming call watcher"
        ) { [weak self] in
          print(
            "SPORTOTEKA LOCK WATCH background expired"
          )

          self?.stop()
        }

      print(
        "SPORTOTEKA LOCK WATCH start " +
        "call=\(cleanCallId) " +
        "user=\(cleanUserId) " +
        "uuid=\(self.watchedUuid?.uuidString ?? "-")"
      )

      // Даём CallKit сначала успеть показать входящий экран.
      self.timer = Timer.scheduledTimer(
        withTimeInterval: 1.0,
        repeats: true
      ) { [weak self] _ in
        self?.poll()
      }

      DispatchQueue.main.asyncAfter(
        deadline: .now() + 0.8
      ) { [weak self] in
        self?.poll()
      }
    }
  }

  func stop() {
    DispatchQueue.main.async {
      self.stopInternal()
    }
  }

  private func stopInternal() {
    timer?.invalidate()
    timer = nil

    requestInFlight = false

    watchedCallId = ""
    watchedUserId = ""
    watchedUuid = nil

    if backgroundTask != .invalid {
      let task = backgroundTask
      backgroundTask = .invalid

      UIApplication.shared.endBackgroundTask(
        task
      )
    }
  }

  private func poll() {
    guard !requestInFlight else {
      return
    }

    let callId = watchedCallId
    let userId = watchedUserId

    guard
      !callId.isEmpty,
      !userId.isEmpty
    else {
      return
    }

    guard let url = URL(
      string:
        "https://sportotekaapp.ru/api/calls/status.php"
    ) else {
      return
    }

    requestInFlight = true

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    request.setValue(
      "application/x-www-form-urlencoded",
      forHTTPHeaderField: "Content-Type"
    )

    let body =
      "call_id=\(urlEncode(callId))" +
      "&user_id=\(urlEncode(userId))"

    request.httpBody =
      body.data(using: .utf8)

    request.timeoutInterval = 4

    URLSession.shared.dataTask(
      with: request
    ) { [weak self] data, _, error in

      DispatchQueue.main.async {
        guard let self else {
          return
        }

        self.requestInFlight = false

        guard
          self.watchedCallId == callId
        else {
          return
        }

        if let error {
          print(
            "SPORTOTEKA LOCK WATCH network " +
            "\(error.localizedDescription)"
          )
          return
        }

        guard
          let data,
          let json = try? JSONSerialization
            .jsonObject(with: data),
          let map = json as? [String: Any]
        else {
          return
        }

        let status =
          String(
            describing:
              map["call_status"] ?? ""
          )
          .trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          .lowercased()

        switch status {
        case "canceled",
             "cancelled",
             "declined",
             "missed",
             "ended":

          print(
            "SPORTOTEKA LOCK WATCH terminal " +
            "call=\(callId) status=\(status)"
          )

          self.endSystemCall(
            status: status
          )

        default:
          break
        }
      }
    }
    .resume()
  }

  private func endSystemCall(
    status: String
  ) {
    guard let uuid = watchedUuid else {
      print(
        "SPORTOTEKA LOCK WATCH end: UUID missing"
      )

      stopInternal()
      return
    }

    // Не допускаем несколько terminal actions.
    timer?.invalidate()
    timer = nil

    let uuidString = uuid.uuidString

    print(
      "SPORTOTEKA LOCK WATCH FORCE END " +
      "uuid=\(uuidString) " +
      "status=\(status)"
    )

    /*
     * Основной путь.
     *
     * Используем именно provider flutter_callkit_incoming,
     * которым был зарегистрирован настоящий входящий вызов.
     *
     * reason = 2 -> CXCallEndedReason.remoteEnded
     *
     * Это важно для lock screen: iOS получает явное сообщение,
     * что вызов завершён удалённой стороной.
     */
    if let plugin =
        SwiftFlutterCallkitIncomingPlugin.sharedInstance {

      plugin.saveEndCall(
        uuidString,
        2
      )

      print(
        "SPORTOTEKA LOCK WATCH " +
        "provider remoteEnded reported"
      )

      /*
       * saveEndCall закрывает системный CallKit.
       * Через небольшой интервал дополнительно очищаем
       * CallManager плагина, чтобы там не осталось
       * зависшего active call.
       */
      DispatchQueue.main.asyncAfter(
        deadline: .now() + 0.18
      ) { [weak self] in

        SwiftFlutterCallkitIncomingPlugin
          .sharedInstance?
          .endAllCalls()

        print(
          "SPORTOTEKA LOCK WATCH " +
          "plugin endAllCalls sent"
        )

        self?.stopInternal()
      }

      return
    }

    /*
     * Fallback на случай, если shared plugin
     * неожиданно ещё не доступен.
     */
    print(
      "SPORTOTEKA LOCK WATCH " +
      "plugin unavailable -> CXCallController fallback"
    )

    let controller = CXCallController()

    let action =
      CXEndCallAction(
        call: uuid
      )

    let transaction =
      CXTransaction(
        action: action
      )

    controller.request(
      transaction
    ) { [weak self] error in

      DispatchQueue.main.async {
        if let error {
          print(
            "SPORTOTEKA LOCK WATCH fallback error " +
            "\(error.localizedDescription)"
          )
        } else {
          print(
            "SPORTOTEKA LOCK WATCH fallback ended " +
            "uuid=\(uuidString)"
          )
        }

        self?.stopInternal()
      }
    }
  }

  private func uuidForCallId(
    _ value: String
  ) -> UUID? {
    guard
      let callId = UInt64(value)
    else {
      return nil
    }

    var hex =
      String(
        callId,
        radix: 16,
        uppercase: false
      )

    if hex.count > 12 {
      hex =
        String(hex.suffix(12))
    }

    hex =
      String(
        repeating: "0",
        count: max(
          0,
          12 - hex.count
        )
      ) + hex

    return UUID(
      uuidString:
        "00000000-0000-4000-8000-\(hex)"
    )
  }

  private func urlEncode(
    _ value: String
  ) -> String {
    value.addingPercentEncoding(
      withAllowedCharacters:
        .urlQueryAllowed
    ) ?? value
  }
}

