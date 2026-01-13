package app3398936.vinebre

import android.content.Context
import android.widget.TextView
import android.widget.LinearLayout
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactorySimple(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = NativeAdView(context)
        val layout = LinearLayout(context)
        layout.orientation = LinearLayout.VERTICAL
        
        val headlineView = TextView(context)
        val bodyView = TextView(context)
        
        headlineView.text = nativeAd.headline
        bodyView.text = nativeAd.body
        
        layout.addView(headlineView)
        layout.addView(bodyView)
        adView.addView(layout)
        adView.setNativeAd(nativeAd)
        
        return adView
    }
}
