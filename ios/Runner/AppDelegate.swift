import Flutter
import GameKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GameCenterPlugin") {
      GameCenterPlugin.register(with: registrar)
    }
  }
}

/// Apple Game Center köprüsü (Phase 2.4, docs/16_phase2_4_game_center.md).
///
/// Dart tarafı: lib/services/game_center/game_center.dart (kanal `istanbul_flight/game_center`).
/// Oyuncu kimliği (gamePlayerID vb.) Dart'a hiç gönderilmez; yalnızca görünen ad ve sıralama satırları
/// ekranda gösterilmek üzere iletilir ve kalıcı saklanmaz. Game Center hiçbir zaman oynamak için zorunlu değildir.
final class GameCenterPlugin: NSObject, FlutterPlugin, GKGameCenterControllerDelegate {
  private let channel: FlutterMethodChannel
  private var handlerInstalled = false
  private var pendingAuth: [FlutterResult] = []
  private var lastError: String?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "istanbul_flight/game_center", binaryMessenger: registrar.messenger())
    let instance = GameCenterPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "authenticate": authenticate(result)
    case "status": result(statusMap())
    case "submitScore": submitScore(args, result)
    case "reportAchievements": reportAchievements(args, result)
    case "loadEntries": loadEntries(args, result)
    case "loadOccurrence": loadOccurrence(args, result)
    case "showLeaderboard": showLeaderboard(args, result)
    case "showAchievements": present(GKGameCenterViewController(state: .achievements), result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Kimlik doğrulama

  /// GameKit'in giriş akışını bir kez kurar. Oyuncu iptal ederse oyun normal devam eder; GameKit aynı
  /// oturumda giriş ekranını tekrar göstermez (oyuncu Ayarlar > Game Center'dan girebilir).
  private func authenticate(_ result: @escaping FlutterResult) {
    if GKLocalPlayer.local.isAuthenticated {
      result(statusMap())
      return
    }
    pendingAuth.append(result)
    if handlerInstalled { return }
    handlerInstalled = true
    GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        if let vc = viewController, let top = Self.topViewController() {
          top.present(vc, animated: true)
          return
        }
        self.lastError = error.map { Self.errorCode($0) }
        let status = self.statusMap()
        let waiting = self.pendingAuth
        self.pendingAuth.removeAll()
        waiting.forEach { $0(status) }
        self.channel.invokeMethod("statusChanged", arguments: status)
      }
    }
  }

  private func statusMap() -> [String: Any] {
    let p = GKLocalPlayer.local
    var map: [String: Any] = [
      "authenticated": p.isAuthenticated,
      "underage": p.isAuthenticated && p.isUnderage,
      "restricted": p.isAuthenticated && p.isMultiplayerGamingRestricted,
    ]
    if p.isAuthenticated { map["alias"] = p.displayName }
    if let e = lastError { map["error"] = e }
    return map
  }

  // MARK: Skor

  /// Klasik tabloya doğrudan; tekrarlayan (haftalık) tabloya yalnızca sunucunun o anki dönemi açıksa
  /// ve skor bu dönem başladıktan sonra yapılmışsa gönderir. Dönem başlangıcı sunucudan gelir.
  private func submitScore(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard GKLocalPlayer.local.isAuthenticated else {
      return result(FlutterError(code: "not_authenticated", message: nil, details: nil))
    }
    guard let id = args["leaderboardId"] as? String, let score = args["score"] as? Int else {
      return result(FlutterError(code: "bad_args", message: nil, details: nil))
    }
    let recurring = args["recurring"] as? Bool ?? false
    if !recurring {
      GKLeaderboard.submitScore(
        score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id]
      ) { error in
        DispatchQueue.main.async { result(error.map { Self.flutterError($0) }) }
      }
      return
    }
    let achievedAtMs = args["achievedAtMs"] as? Double
    GKLeaderboard.loadLeaderboards(IDs: [id]) { boards, error in
      if let error = error {
        return DispatchQueue.main.async { result(Self.flutterError(error)) }
      }
      guard let board = boards?.first else {
        return DispatchQueue.main.async {
          result(FlutterError(code: "unknown_leaderboard", message: id, details: nil))
        }
      }
      guard let start = board.startDate, Date() < start.addingTimeInterval(board.duration) else {
        return DispatchQueue.main.async {
          result(FlutterError(code: "inactive", message: nil, details: nil))
        }
      }
      // Günün Uçuşu (Phase 2.5): skor yalnızca kendi gününün dönemine gider. Açık dönem (Apple sunucu
      // saati) beklenen anda başlamadıysa skor başka bir güne aittir: gönderilmez.
      if let expected = args["occurrenceStartMs"] as? Double,
        abs(start.timeIntervalSince1970 - expected / 1000) > 120
      {
        return DispatchQueue.main.async {
          result(FlutterError(code: "expired", message: nil, details: nil))
        }
      }
      if let at = achievedAtMs, Date(timeIntervalSince1970: at / 1000) < start {
        // önceki haftanın skoru yeni haftaya geçirilmez
        return DispatchQueue.main.async {
          result(FlutterError(code: "expired", message: nil, details: nil))
        }
      }
      board.submitScore(score, context: 0, player: GKLocalPlayer.local) { error in
        DispatchQueue.main.async { result(error.map { Self.flutterError($0) }) }
      }
    }
  }

  // MARK: Başarımlar

  private func reportAchievements(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard GKLocalPlayer.local.isAuthenticated else {
      return result(FlutterError(code: "not_authenticated", message: nil, details: nil))
    }
    let items = args["items"] as? [[String: Any]] ?? []
    let achievements: [GKAchievement] = items.compactMap { item in
      guard let id = item["id"] as? String, let percent = item["percent"] as? Double else {
        return nil
      }
      let a = GKAchievement(identifier: id)
      a.percentComplete = min(100, max(0, percent))
      a.showsCompletionBanner = item["banner"] as? Bool ?? false
      return a
    }
    if achievements.isEmpty { return result(nil) }
    GKAchievement.report(achievements) { error in
      DispatchQueue.main.async { result(error.map { Self.flutterError($0) }) }
    }
  }

  // MARK: Sıralama satırları (ekranda gösterilir, saklanmaz)

  private func loadEntries(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard GKLocalPlayer.local.isAuthenticated else {
      return result(FlutterError(code: "not_authenticated", message: nil, details: nil))
    }
    guard let id = args["leaderboardId"] as? String else {
      return result(FlutterError(code: "bad_args", message: nil, details: nil))
    }
    let friends = (args["scope"] as? String) == "friends"
    let limit = min(100, max(1, args["limit"] as? Int ?? 25))
    let load = {
      GKLeaderboard.loadLeaderboards(IDs: [id]) { boards, error in
        if let error = error {
          return DispatchQueue.main.async { result(Self.flutterError(error)) }
        }
        guard let board = boards?.first else {
          return DispatchQueue.main.async {
            result(FlutterError(code: "unknown_leaderboard", message: id, details: nil))
          }
        }
        // Tekrarlayan tabloda zaman kapsamı her zaman allTime (GameKit belgesi)
        board.loadEntries(
          for: friends ? .friendsOnly : .global, timeScope: .allTime,
          range: NSRange(location: 1, length: limit)
        ) { local, entries, total, error in
          DispatchQueue.main.async {
            if let error = error { return result(Self.flutterError(error)) }
            var map: [String: Any] = [
              "total": total,
              "entries": (entries ?? []).map { Self.entryMap($0) },
            ]
            if let local = local { map["local"] = Self.entryMap(local) }
            if board.type == .recurring, let start = board.startDate {
              map["occurrenceEndMs"] = start.addingTimeInterval(board.duration)
                .timeIntervalSince1970 * 1000
            }
            result(map)
          }
        }
      }
    }
    guard friends else { return load() }
    GKLocalPlayer.local.loadFriendsAuthorizationStatus { status, _ in
      switch status {
      case .authorized: load()
      case .notDetermined:
        // izin penceresi yalnızca oyuncu "Arkadaşlar"ı seçince gösterilir
        GKLocalPlayer.local.loadFriends { _, error in
          if let error = error {
            return DispatchQueue.main.async { result(Self.flutterError(error)) }
          }
          load()
        }
      default:
        DispatchQueue.main.async {
          result(FlutterError(code: "friends_denied", message: nil, details: nil))
        }
      }
    }
  }

  /// Tekrarlayan tablonun açık dönemi (Apple sunucu saati): Günün Uçuşu saat denetimi (Phase 2.5).
  private func loadOccurrence(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard GKLocalPlayer.local.isAuthenticated else {
      return result(FlutterError(code: "not_authenticated", message: nil, details: nil))
    }
    guard let id = args["leaderboardId"] as? String else {
      return result(FlutterError(code: "bad_args", message: nil, details: nil))
    }
    GKLeaderboard.loadLeaderboards(IDs: [id]) { boards, error in
      DispatchQueue.main.async {
        if let error = error { return result(Self.flutterError(error)) }
        guard let board = boards?.first else {
          return result(FlutterError(code: "unknown_leaderboard", message: id, details: nil))
        }
        guard let start = board.startDate, board.duration > 0 else { return result(nil) }
        result([
          "startMs": start.timeIntervalSince1970 * 1000,
          "endMs": start.addingTimeInterval(board.duration).timeIntervalSince1970 * 1000,
        ])
      }
    }
  }

  private static func entryMap(_ e: GKLeaderboard.Entry) -> [String: Any] {
    [
      "rank": e.rank,
      "alias": e.player.displayName,
      "score": e.score,
      "formatted": e.formattedScore,
      "isLocal": e.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID,
    ]
  }

  // MARK: Apple'ın Game Center ekranları

  private func showLeaderboard(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let id = args["leaderboardId"] as? String else {
      return present(GKGameCenterViewController(state: .leaderboards), result)
    }
    let friends = (args["scope"] as? String) == "friends"
    present(
      GKGameCenterViewController(
        leaderboardID: id, playerScope: friends ? .friendsOnly : .global, timeScope: .allTime),
      result)
  }

  private func present(_ vc: GKGameCenterViewController, _ result: @escaping FlutterResult) {
    guard GKLocalPlayer.local.isAuthenticated else {
      return result(FlutterError(code: "not_authenticated", message: nil, details: nil))
    }
    guard let top = Self.topViewController() else {
      return result(FlutterError(code: "no_view", message: nil, details: nil))
    }
    vc.gameCenterDelegate = self
    top.present(vc, animated: true)
    result(nil)
  }

  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    gameCenterViewController.dismiss(animated: true)
  }

  // MARK: Yardımcılar

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// GameKit hata kodu → Dart'ın tanıdığı kısa kod (ağ hataları tekrar denenir).
  private static func errorCode(_ error: Error) -> String {
    let ns = error as NSError
    if ns.domain == NSURLErrorDomain { return "network" }
    guard ns.domain == GKErrorDomain, let code = GKError.Code(rawValue: ns.code) else {
      return "failed"
    }
    switch code {
    case .communicationsFailure, .connectionTimeout: return "network"
    case .cancelled: return "cancelled"
    case .notAuthenticated, .userDenied, .notAuthorized: return "not_authenticated"
    case .gameUnrecognized, .notSupported: return "not_configured"
    case .parentalControlsBlocked, .underage: return "restricted"
    case .friendListDenied, .friendListRestricted: return "friends_denied"
    default: return "failed"
    }
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    FlutterError(code: errorCode(error), message: (error as NSError).localizedDescription, details: nil)
  }
}
