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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
    action.fulfill()
    postSportotekaCallAction("accept", call: call)
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

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    // CallKit has activated AVAudioSession.
    // Only now allow LiveKit/WebRTC audio I/O.
    LiveKitPlugin.setEngineAvailability(
      isInputAvailable: true,
      isOutputAvailable: true
    )
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
