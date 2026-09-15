package com.example.hd_status.media

import android.os.StatFs
import java.io.File

object StorageInfo {
    fun freeBytes(dirPath: String): Long {
        val dir = File(dirPath)
        if (!dir.exists()) dir.mkdirs()
        return StatFs(dir.path).availableBytes
    }
}
