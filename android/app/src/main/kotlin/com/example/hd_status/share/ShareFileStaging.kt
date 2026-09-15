/*
 * A FileProvider URI can only be granted for a file living inside one of the
 * directories declared in file_provider_paths.xml (cacheDir/share/ here).
 * image_picker already copies picked media into this app's own cache
 * directory (a real file path, not a content:// URI) but not into that
 * specific subdirectory, so every share still needs a local copy step first
 * — for a real optimize/split job this is also naturally where the encoder
 * writes its output (Phase 5+), not just a Phase 2 passthrough detail.
 */
package com.example.hd_status.share

import android.content.Context
import java.io.File

object ShareFileStaging {
    fun stageForShare(context: Context, sourceFilePath: String, suggestedFileName: String): String {
        val shareDir = File(context.cacheDir, "share").apply { mkdirs() }
        val sourceFile = File(sourceFilePath)

        // A Processing/Splitting output is already written straight into
        // this directory. Copying it "onto itself" would open a
        // FileOutputStream on the same path we're still reading from —
        // which truncates the file first — corrupting/emptying it right
        // before it's shared. Only stage files that actually live elsewhere
        // (e.g. image_picker's own temp dir, for a raw/passthrough share).
        if (sourceFile.canonicalFile.parentFile == shareDir.canonicalFile) {
            return sourceFile.absolutePath
        }

        val destFile = File(shareDir, suggestedFileName)
        sourceFile.copyTo(destFile, overwrite = true)
        return destFile.absolutePath
    }
}
