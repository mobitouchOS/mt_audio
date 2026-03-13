package com.mobitouchos.mt_audio

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.webkit.MimeTypeMap
import java.io.File

/**
 * Read-only [ContentProvider] that serves cached artwork files to Android Auto.
 *
 * Android Auto runs in a separate process and cannot access `file://` URIs in the
 * app's private cache. This provider exposes the cached artwork via `content://`
 * URIs that Android Auto can resolve.
 *
 * URI format: `content://{applicationId}.mt_audio.artwork/{asset_key}`
 * Maps to:    `{cacheDir}/mt_audio_assets/{asset_key}`
 */
class MtAudioArtworkProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        if (mode != "r") return null

        val assetKey = uri.path?.removePrefix("/") ?: return null
        val context = context ?: return null
        val file = File(context.cacheDir, "mt_audio_assets/$assetKey")

        // Prevent path traversal by ensuring the resolved path stays within the cache.
        val cacheBase = File(context.cacheDir, "mt_audio_assets").canonicalPath
        if (!file.canonicalPath.startsWith(cacheBase)) return null

        if (!file.exists()) return null

        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String? {
        val path = uri.path ?: return null
        val ext = MimeTypeMap.getFileExtensionFromUrl(path)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }

    // This is a read-only provider — write operations are not supported.

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
