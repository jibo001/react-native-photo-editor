package com.reactnativephotoeditor.activity

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.canhub.cropper.CropImageContract
import com.canhub.cropper.CropImageContractOptions
import com.canhub.cropper.CropImageOptions
import com.canhub.cropper.CropImageView
import com.reactnativephotoeditor.activity.constant.ResponseCode
import java.io.File
import java.io.FileOutputStream

class CropImageActivity : AppCompatActivity() {

    private var sourceImagePath: String? = null

    private val cropImage = registerForActivityResult(CropImageContract()) { result ->
        if (result.isSuccessful) {
            // Use the cropped image URI
            val croppedImageUri = result.uriContent

            // Save the cropped image and return the path
            croppedImageUri?.let { uri ->
                val croppedPath = saveCroppedImage(uri)
                val resultIntent = Intent()
                resultIntent.putExtra("path", croppedPath)
                setResult(ResponseCode.RESULT_OK, resultIntent)
            } ?: run {
                // If we don't have a URI, return error
                val resultIntent = Intent()
                setResult(ResponseCode.LOAD_IMAGE_FAILED, resultIntent)
            }

            finish()
        } else {
            // An error occurred
            val resultIntent = Intent()
            setResult(ResponseCode.LOAD_IMAGE_FAILED, resultIntent)
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置状态栏颜色为黑色
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = Color.BLACK

            // 如果是Android 6.0以上，设置状态栏图标为白色
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                window.decorView.systemUiVisibility = 0 // 清除亮色图标标志
            }
        }

        // Get source image path from intent
        sourceImagePath = intent.getStringExtra("path")

        if (sourceImagePath.isNullOrEmpty()) {
            val resultIntent = Intent()
            setResult(ResponseCode.LOAD_IMAGE_FAILED, resultIntent)
            finish()
            return
        }

        // Start cropping immediately with the provided image
        startCrop(Uri.parse(sourceImagePath))
    }

    private fun startCrop(uri: Uri) {
        // Launch the cropper with the specified URI and options
        cropImage.launch(
            CropImageContractOptions(
                uri = uri,
                cropImageOptions = CropImageOptions(
                    guidelines = CropImageView.Guidelines.ON,
                    outputCompressFormat = Bitmap.CompressFormat.JPEG,
                    outputCompressQuality = 90,
                    fixAspectRatio = false,
                    autoZoomEnabled = true,
                    // 设置裁剪界面的主题颜色
                    activityBackgroundColor = Color.BLACK,
                    toolbarColor = Color.BLACK,
                    toolbarTitleColor = Color.WHITE,
                    activityMenuIconColor = Color.WHITE,
                    activityMenuTextColor = Color.WHITE,
                )
            )
        )
    }

    private fun saveCroppedImage(uri: Uri): String {
        // Create a file to save the cropped image
        val originalFile = File(sourceImagePath?.replace("file://", "") ?: "")
        val outputFile = File(originalFile.parent, "cropped_${originalFile.name}")

        // Copy the cropped image to the output file
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        }

        return outputFile.absolutePath
    }

    override fun onBackPressed() {
        // Handle back button press
        val resultIntent = Intent()
        setResult(ResponseCode.RESULT_CANCELED, resultIntent)
        finish()
        super.onBackPressed()
    }
}
