package com.rume.rume

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/** Builds the full-bleed ad page used for feed ad slots (factory id "fullScreen"). */
class FullScreenNativeAdFactory(private val inflater: LayoutInflater) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = inflater.inflate(R.layout.native_ad_full_screen, null) as NativeAdView

        val media = adView.findViewById<MediaView>(R.id.ad_media)
        media.setImageScaleType(ImageView.ScaleType.CENTER_CROP)
        adView.mediaView = media
        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_cta)
        adView.iconView = adView.findViewById(R.id.ad_icon)
        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)

        // Headline and media are guaranteed; everything else is optional.
        (adView.headlineView as TextView).text = nativeAd.headline
        nativeAd.mediaContent?.let { media.mediaContent = it }

        bindText(adView.bodyView, nativeAd.body)
        bindText(adView.advertiserView, nativeAd.advertiser)
        (adView.callToActionView as Button).apply {
            text = nativeAd.callToAction ?: "Learn more"
        }
        (adView.iconView as ImageView).apply {
            val icon = nativeAd.icon?.drawable
            setImageDrawable(icon)
            visibility = if (icon == null) View.GONE else View.VISIBLE
        }

        adView.setNativeAd(nativeAd)
        return adView
    }

    private fun bindText(view: View?, value: String?) {
        val text = view as? TextView ?: return
        text.text = value
        text.visibility = if (value.isNullOrBlank()) View.GONE else View.VISIBLE
    }
}
