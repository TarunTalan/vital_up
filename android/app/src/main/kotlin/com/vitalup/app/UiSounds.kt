package com.vitalup.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool

/**
 * Short UI sounds (the weight scale's tick). SoundPool plays them with no
 * delay and, unlike a media player, takes no audio focus, so music keeps
 * playing. They play only with the ringer on: silent and vibrate mode keep
 * the app quiet (the haptic tick still runs).
 */
class UiSounds(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val pool: SoundPool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()

    private var tickId = 0
    private var loaded = false

    init {
        pool.setOnLoadCompleteListener { _, id, status ->
            if (id == tickId && status == 0) loaded = true
        }
        tickId = pool.load(context, R.raw.scale_tick, 1)
    }

    /** One tick; [strong] is a little deeper and louder (whole units). */
    fun tick(strong: Boolean) {
        if (!loaded || audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        val volume = if (strong) 0.55f else 0.35f
        val rate = if (strong) 0.82f else 1f
        pool.play(tickId, volume, volume, 1, 0, rate)
    }

    fun release() {
        pool.release()
    }
}
