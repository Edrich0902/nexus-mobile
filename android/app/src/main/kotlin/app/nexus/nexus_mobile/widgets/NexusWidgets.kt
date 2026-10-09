package app.nexus.nexus_mobile.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.ColorRes
import androidx.annotation.DrawableRes
import app.nexus.nexus_mobile.MainActivity
import app.nexus.nexus_mobile.R
import es.antonborri.home_widget.HomeWidgetProvider

/** Opens `nexus://open<path>`; the app routes it exactly like a web path. */
internal fun openApp(context: Context, path: String, requestCode: Int): PendingIntent {
    val safe = if (path.startsWith("/") && !path.startsWith("//") && !path.contains("..")) path else "/home"
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("nexus://open$safe"), context, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    return PendingIntent.getActivity(
        context,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

internal fun SharedPreferences.text(key: String, fallback: String = ""): String =
    getString(key, null)?.takeIf { it.isNotBlank() } ?: fallback

/** One Nexus colour field. Data is written by the Flutter side (home_widgets.dart). */
abstract class FieldWidget : HomeWidgetProvider() {
    data class Field(val eyebrow: String, val title: String, val sub: String, val footer: String, val path: String)

    @get:DrawableRes abstract val background: Int
    @get:ColorRes abstract val ink: Int

    abstract fun field(data: SharedPreferences): Field

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val field = field(widgetData)
        val colour = context.getColor(ink)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_field).apply {
                setInt(R.id.widget_root, "setBackgroundResource", background)
                bind(R.id.widget_eyebrow, field.eyebrow, colour)
                bind(R.id.widget_title, field.title, colour)
                bind(R.id.widget_sub, field.sub, colour)
                bind(R.id.widget_footer, field.footer, colour)
                setOnClickPendingIntent(R.id.widget_root, openApp(context, field.path, id))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun RemoteViews.bind(view: Int, value: String, colour: Int) {
        setTextViewText(view, value)
        setTextColor(view, colour)
        setViewVisibility(view, if (value.isEmpty()) View.GONE else View.VISIBLE)
    }
}

class ListeningWidget : FieldWidget() {
    override val background = R.drawable.widget_bg_listening
    override val ink = R.color.widget_listening_ink

    override fun field(data: SharedPreferences) = Field(
        eyebrow = data.text("listening_state", "Listening"),
        title = data.text("listening_title", "Nothing playing"),
        sub = data.text("listening_artist"),
        footer = "",
        path = "/spotify",
    )
}

class NextRaceWidget : FieldWidget() {
    override val background = R.drawable.widget_bg_f1
    override val ink = R.color.widget_f1_ink

    override fun field(data: SharedPreferences) = Field(
        eyebrow = data.text("race_label", "Formula 1"),
        title = data.text("race_title", "Open Nexus to load the calendar"),
        sub = data.text("race_sub"),
        footer = data.text("race_when"),
        path = data.text("race_route", "/f1"),
    )
}

class TonightWidget : FieldWidget() {
    override val background = R.drawable.widget_bg_cellar
    override val ink = R.color.widget_cellar_ink

    override fun field(data: SharedPreferences) = Field(
        eyebrow = "Tonight",
        title = data.text("tonight_title", "Pick a bottle"),
        sub = data.text("tonight_sub"),
        footer = "",
        path = data.text("tonight_route", "/cellar"),
    )
}

class QuickLogWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_log).apply {
                setOnClickPendingIntent(R.id.widget_root, openApp(context, "/capture", id * 4))
                setOnClickPendingIntent(R.id.quick_wine, openApp(context, "/capture?kind=wine", id * 4 + 1))
                setOnClickPendingIntent(R.id.quick_beer, openApp(context, "/capture?kind=beer", id * 4 + 2))
                setOnClickPendingIntent(R.id.quick_book, openApp(context, "/capture?kind=book&mode=barcode", id * 4 + 3))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
