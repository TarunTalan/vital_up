package com.tarun_siddhi.vital_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class CustomWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val imagePath = widgetData.getString("custom_widget_image", null)
        
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.custom_widget).apply {
                if (imagePath != null) {
                    val imgFile = File(imagePath)
                    if (imgFile.exists()) {
                        val bitmap = BitmapFactory.decodeFile(imgFile.absolutePath)
                        setImageViewBitmap(R.id.widget_image, bitmap)
                    }
                }
                
                // Deep link when tapped
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vitalup://widget/open?route=dashboard"),
                )
                setOnClickPendingIntent(R.id.widget_image, launchIntent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
