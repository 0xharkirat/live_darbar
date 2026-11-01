package com.hsi.harki.live_darbar

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/**
 * Hands the three paintings to the Android Auto host.
 *
 * The paintings are copied into the app's private files directory by the Dart
 * `ArtworkStore`. A `file:` URI to that directory is unreadable to another
 * app, so the browse rows in a car had no picture. This provider is the
 * read-only door to those three files and to nothing else.
 *
 * The rules that keep it safe:
 *
 * - The URI path must be exactly `/0.jpg`, `/1.jpg` or `/2.jpg`. The path is
 *   looked up in that list and never joined onto a directory, so a path such
 *   as `/../x`, `/%2e%2e/x` or `/0.jpg/..` finds no file.
 * - The file must still resolve inside the artwork directory.
 * - It opens files for reading only. Every write method refuses.
 *
 * The directory name and the file names are the contract with
 * `lib/src/core/artwork_store.dart`. Change one side and change the other.
 */
class ArtworkProvider : ContentProvider() {

    companion object {
        /** `files/artwork`, where `getApplicationSupportDirectory()` puts it. */
        private const val ARTWORK_DIRECTORY = "artwork"

        /** The only names this provider will serve. */
        private val SERVED = setOf("0.jpg", "1.jpg", "2.jpg")

        private const val MIME_TYPE = "image/jpeg"
    }

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String? = if (nameOf(uri) != null) MIME_TYPE else null

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") {
            throw SecurityException("The artwork is read-only")
        }
        val file = fileFor(uri) ?: throw FileNotFoundException("No artwork at $uri")
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    /** Name and size, for a client that asks what it was given. */
    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? {
        val name = nameOf(uri) ?: return null
        val file = fileFor(uri) ?: return null
        val columns: Array<String> =
            projection?.toList()?.toTypedArray()
                ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columns)
        cursor.addRow(
            Array<Any?>(columns.size) { index ->
                when (columns[index]) {
                    OpenableColumns.DISPLAY_NAME -> name
                    OpenableColumns.SIZE -> file.length()
                    else -> null
                }
            },
        )
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("The artwork is read-only")

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("The artwork is read-only")

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException("The artwork is read-only")

    /** The served file name the [uri] asks for, or null for anything else. */
    private fun nameOf(uri: Uri): String? {
        val segments = uri.pathSegments
        if (segments.size != 1) return null
        val name = segments[0]
        return if (name in SERVED) name else null
    }

    /** The file behind [uri], or null when it is not one of the three or is not there yet. */
    private fun fileFor(uri: Uri): File? {
        val name = nameOf(uri) ?: return null
        val context = context ?: return null
        return try {
            val directory = File(context.filesDir, ARTWORK_DIRECTORY).canonicalFile
            val file = File(directory, name).canonicalFile
            if (file.parentFile == directory && file.isFile) file else null
        } catch (e: java.io.IOException) {
            null
        }
    }
}
