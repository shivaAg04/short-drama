import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Must match AdConfig.factoryId on the Dart side.
  private static let adFactoryId = "fullScreen"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: Self.adFactoryId,
      nativeAdFactory: FullScreenNativeAdFactory()
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Builds the full-bleed ad page used for feed ad slots; mirrors the Android
/// layout in native_ad_full_screen.xml.
final class FullScreenNativeAdFactory: NSObject, FLTNativeAdFactory {
  private static let ink = UIColor(red: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1)
  private static let muted = UIColor(red: 161 / 255, green: 161 / 255, blue: 174 / 255, alpha: 1)
  // Alright!TV logo blue.
  private static let brand = UIColor(red: 13 / 255, green: 17 / 255, blue: 212 / 255, alpha: 1)

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = Self.ink

    let media = MediaView()
    media.contentMode = .scaleAspectFill
    media.clipsToBounds = true

    let scrim = GradientView()
    scrim.gradient.colors = [Self.ink.withAlphaComponent(0).cgColor, Self.ink.withAlphaComponent(0.94).cgColor]

    let badge = PaddedLabel()
    badge.text = "Sponsored"
    badge.font = .boldSystemFont(ofSize: 12)
    badge.textColor = .white
    badge.backgroundColor = UIColor.black.withAlphaComponent(0.45)
    badge.layer.cornerRadius = 12
    badge.layer.borderWidth = 1
    badge.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
    badge.clipsToBounds = true

    let icon = UIImageView()
    icon.contentMode = .scaleAspectFill
    icon.layer.cornerRadius = 10
    icon.clipsToBounds = true

    let headline = label(size: 18, weight: .bold, color: .white, lines: 2)
    let advertiser = label(size: 13, weight: .regular, color: Self.muted, lines: 1)
    let body = label(size: 14, weight: .regular, color: UIColor.white.withAlphaComponent(0.88), lines: 3)

    let cta = UIButton(type: .custom)
    cta.backgroundColor = Self.brand
    cta.layer.cornerRadius = 27
    cta.setTitleColor(.white, for: .normal)
    cta.titleLabel?.font = .boldSystemFont(ofSize: 16)
    // The SDK handles the click; the button must not swallow it.
    cta.isUserInteractionEnabled = false

    let hint = label(size: 12, weight: .regular, color: Self.muted, lines: 1)
    hint.text = "Swipe up to keep watching"
    hint.textAlignment = .center

    let names = UIStackView(arrangedSubviews: [headline, advertiser])
    names.axis = .vertical
    names.spacing = 2
    let header = UIStackView(arrangedSubviews: [icon, names])
    header.alignment = .center
    header.spacing = 12
    let content = UIStackView(arrangedSubviews: [header, body, cta, hint])
    content.axis = .vertical
    content.spacing = 12
    content.setCustomSpacing(18, after: body)

    for view in [media, scrim, badge, content] {
      view.translatesAutoresizingMaskIntoConstraints = false
      adView.addSubview(view)
    }
    let safe = adView.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      media.topAnchor.constraint(equalTo: adView.topAnchor),
      media.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      media.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      media.trailingAnchor.constraint(equalTo: adView.trailingAnchor),

      scrim.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      scrim.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      scrim.heightAnchor.constraint(equalToConstant: 420),

      badge.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
      badge.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),

      content.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
      content.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
      content.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -20),

      icon.widthAnchor.constraint(equalToConstant: 44),
      icon.heightAnchor.constraint(equalToConstant: 44),
      cta.heightAnchor.constraint(equalToConstant: 54),
    ])

    adView.mediaView = media
    adView.headlineView = headline
    adView.advertiserView = advertiser
    adView.bodyView = body
    adView.iconView = icon
    adView.callToActionView = cta

    // Headline and media are guaranteed; everything else is optional.
    headline.text = nativeAd.headline
    media.mediaContent = nativeAd.mediaContent
    advertiser.text = nativeAd.advertiser
    advertiser.isHidden = nativeAd.advertiser == nil
    body.text = nativeAd.body
    body.isHidden = nativeAd.body == nil
    icon.image = nativeAd.icon?.image
    icon.isHidden = nativeAd.icon == nil
    cta.setTitle(nativeAd.callToAction ?? "Learn more", for: .normal)

    adView.nativeAd = nativeAd
    return adView
  }

  private func label(size: CGFloat, weight: UIFont.Weight, color: UIColor, lines: Int) -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.numberOfLines = lines
    return label
  }
}

private final class GradientView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }
  var gradient: CAGradientLayer { layer as! CAGradientLayer }
}

private final class PaddedLabel: UILabel {
  private let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
  }
}
