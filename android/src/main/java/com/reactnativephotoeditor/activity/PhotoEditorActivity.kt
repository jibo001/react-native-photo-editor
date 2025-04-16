package com.reactnativephotoeditor.activity

import android.Manifest
import android.annotation.SuppressLint
import android.app.ProgressDialog
import android.content.DialogInterface
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.view.animation.AnticipateOvershootInterpolator
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.constraintlayout.widget.ConstraintSet
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.transition.ChangeBounds
import androidx.transition.TransitionManager
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DataSource
import com.bumptech.glide.load.engine.GlideException
import com.bumptech.glide.request.RequestListener
import com.bumptech.glide.request.target.Target
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.google.android.material.snackbar.Snackbar
import com.reactnativephotoeditor.R
import com.reactnativephotoeditor.activity.StickerFragment.StickerListener
import com.reactnativephotoeditor.activity.constant.ResponseCode
import com.reactnativephotoeditor.activity.filters.FilterListener
import com.reactnativephotoeditor.activity.filters.FilterViewAdapter
import com.reactnativephotoeditor.activity.tools.EditingToolsAdapter
import com.reactnativephotoeditor.activity.tools.EditingToolsAdapter.OnItemSelected
import com.reactnativephotoeditor.activity.tools.ToolType
import ja.burhanrashid52.photoeditor.*
import ja.burhanrashid52.photoeditor.PhotoEditor.OnSaveListener
import ja.burhanrashid52.photoeditor.shape.ShapeBuilder
import ja.burhanrashid52.photoeditor.shape.ShapeType
import java.io.File


open class PhotoEditorActivity : AppCompatActivity(), OnPhotoEditorListener, View.OnClickListener,
  PropertiesBSFragment.Properties, ShapeBSFragment.Properties, StickerListener,
  OnItemSelected, FilterListener, AdjustFragment.AdjustListener {
  private var mPhotoEditor: PhotoEditor? = null
  private var mProgressDialog: ProgressDialog? = null
  private var mPhotoEditorView: PhotoEditorView? = null
  private var mPropertiesBSFragment: PropertiesBSFragment? = null
  private var mShapeBSFragment: ShapeBSFragment? = null
  private var mShapeBuilder: ShapeBuilder? = null
  private var mStickerFragment: StickerFragment? = null
  private var mTxtCurrentTool: TextView? = null
  private var mRvTools: RecyclerView? = null
  private var mRvFilters: RecyclerView? = null
  private val mEditingToolsAdapter = EditingToolsAdapter(this)
  private val mFilterViewAdapter = FilterViewAdapter(this)
  private var mRootView: ConstraintLayout? = null
  private val mConstraintSet = ConstraintSet()
  private var mIsFilterVisible = false
  private var mAdjustFragment: AdjustFragment? = null
  private var mImageAdjustHelper: ImageAdjustHelper? = null
  private var mOriginalBitmap: Bitmap? = null

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    makeFullScreen()
    setContentView(R.layout.photo_editor_view)
    initViews()

    //intern
    val value = intent.extras
    val path = value?.getString("path")
    val stickers =
      value?.getStringArrayList("stickers")?.plus(
        assets.list("Stickers")!!
          .map { item -> "/android_asset/Stickers/$item" }) as ArrayList<String>
//    println("stickers: $stickers ${stickers.size}")
//    for (stick in stickers) {
//      print("stick: $stickers")
//    }

    mPropertiesBSFragment = PropertiesBSFragment()
    mPropertiesBSFragment!!.setPropertiesChangeListener(this)

    mStickerFragment = StickerFragment()
    mStickerFragment!!.setStickerListener(this)

//    val stream: InputStream = assets.open("image.png")
//    val d = Drawable.createFromStream(stream, null)
    mStickerFragment!!.setData(stickers)

    mShapeBSFragment = ShapeBSFragment()
    mShapeBSFragment!!.setPropertiesChangeListener(this)

    // 初始化调整Fragment
    mAdjustFragment = AdjustFragment()
    mAdjustFragment!!.setAdjustListener(this)

    val llmTools = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
    mRvTools!!.layoutManager = llmTools
    mRvTools!!.adapter = mEditingToolsAdapter

    val llmFilters = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
    mRvFilters!!.layoutManager = llmFilters
    mRvFilters!!.adapter = mFilterViewAdapter

    val pinchTextScalable = intent.getBooleanExtra(PINCH_TEXT_SCALABLE_INTENT_KEY, true)
    mPhotoEditor = PhotoEditor.Builder(this, mPhotoEditorView)
      .setPinchTextScalable(pinchTextScalable) // set flag to make text scalable when pinch
      .build() // build photo editor sdk
    mPhotoEditor?.setOnPhotoEditorListener(this)
//    val drawable = Drawable.cre

    Glide
      .with(this)
      .load(path)
      .listener(object : RequestListener<Drawable> {
        override fun onLoadFailed(
          e: GlideException?,
          model: Any?,
          target: Target<Drawable>?,
          isFirstResource: Boolean
        ): Boolean {
          val intent = Intent()
          intent.putExtra("path", path)
          setResult(ResponseCode.LOAD_IMAGE_FAILED, intent)
          return false
        }

        override fun onResourceReady(
          resource: Drawable?,
          model: Any?,
          target: Target<Drawable>?,
          dataSource: DataSource?,
          isFirstResource: Boolean
        ): Boolean {
          // 改进获取原始图像的方法
          resource?.let {
            // 使用post确保视图已完全加载
            mPhotoEditorView?.post {
              try {
                // 从drawable转换为bitmap
                val bitmap = Bitmap.createBitmap(
                  mPhotoEditorView!!.source.width,
                  mPhotoEditorView!!.source.height,
                  Bitmap.Config.ARGB_8888
                )
                val canvas = Canvas(bitmap)
                mPhotoEditorView!!.source.drawable.setBounds(
                  0, 0,
                  mPhotoEditorView!!.source.width,
                  mPhotoEditorView!!.source.height
                )
                mPhotoEditorView!!.source.drawable.draw(canvas)
                mOriginalBitmap = bitmap

                Log.d(TAG, "原始图像获取成功: ${bitmap.width}x${bitmap.height}")
              } catch (e: Exception) {
                Log.e(TAG, "获取原始图像失败: ${e.message}")
              }
            }
          }
          return false
        }
      })
//      .placeholder(drawable)
      .into(mPhotoEditorView!!.source);
  }

  private fun showLoading(message: String) {
    mProgressDialog = ProgressDialog(this)
    mProgressDialog!!.setMessage(message)
    mProgressDialog!!.setProgressStyle(ProgressDialog.STYLE_SPINNER)
    mProgressDialog!!.setCancelable(false)
    mProgressDialog!!.show()
  }

  protected fun hideLoading() {
    if (mProgressDialog != null) {
      mProgressDialog!!.dismiss()
    }
  }

  private fun requestPermission(permission: String) {
    val isGranted =
      ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    if (!isGranted) {
      ActivityCompat.requestPermissions(
        this, arrayOf(permission),
        READ_WRITE_STORAGE
      )
    }
  }

  private fun makeFullScreen() {
    requestWindowFeature(Window.FEATURE_NO_TITLE)
    window.setFlags(
      WindowManager.LayoutParams.FLAG_FULLSCREEN,
      WindowManager.LayoutParams.FLAG_FULLSCREEN
    )

    // 如果当前运行的Android系统版本是Android 5.0(API 21)及以上
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      // 清除FLAG_FULLSCREEN标志以显示状态栏
      window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
      // 设置状态栏为黑色
      window.statusBarColor = Color.BLACK

      // 如果Android版本是Android 6.0(API 23)及以上，可以设置状态栏图标颜色
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        // 设置状态栏图标为浅色（在黑色背景上显示白色图标）
        window.decorView.systemUiVisibility = 0 // 清除亮色图标标志
      }
    }
  }

  private fun initViews() {
    //REDO
    val imgRedo: ImageView = findViewById(R.id.imgRedo)
    imgRedo.setOnClickListener(this)
    //UNDO
    val imgUndo: ImageView = findViewById(R.id.imgUndo)
    imgUndo.setOnClickListener(this)
    //CLOSE
    val imgClose: ImageView = findViewById(R.id.imgClose)
    imgClose.setOnClickListener(this)
    //SAVE
    val btnSave: TextView = findViewById(R.id.btnSave)
    btnSave.setOnClickListener(this)
    btnSave.setTextColor(Color.BLACK)

    mPhotoEditorView = findViewById(R.id.photoEditorView)
    mTxtCurrentTool = findViewById(R.id.txtCurrentTool)
    mRvTools = findViewById(R.id.rvConstraintTools)
    mRvFilters = findViewById(R.id.rvFilterView)
    mRootView = findViewById(R.id.rootView)
  }

  override fun onEditTextChangeListener(rootView: View, text: String, colorCode: Int) {
    val textEditorDialogFragment = TextEditorDialogFragment.show(this, text, colorCode)
    textEditorDialogFragment.setOnTextEditorListener { inputText: String?, newColorCode: Int ->
      val styleBuilder = TextStyleBuilder()
      styleBuilder.withTextColor(newColorCode)
      mPhotoEditor!!.editText(rootView, inputText, styleBuilder)
      mTxtCurrentTool!!.setText(R.string.label_text)
    }
  }

  override fun onAddViewListener(viewType: ViewType, numberOfAddedViews: Int) {
    Log.d(
      TAG,
      "onAddViewListener() called with: viewType = [$viewType], numberOfAddedViews = [$numberOfAddedViews]"
    )
  }

  override fun onRemoveViewListener(viewType: ViewType, numberOfAddedViews: Int) {
    Log.d(
      TAG,
      "onRemoveViewListener() called with: viewType = [$viewType], numberOfAddedViews = [$numberOfAddedViews]"
    )
  }

  override fun onStartViewChangeListener(viewType: ViewType) {
    Log.d(TAG, "onStartViewChangeListener() called with: viewType = [$viewType]")
  }

  override fun onStopViewChangeListener(viewType: ViewType) {
    Log.d(TAG, "onStopViewChangeListener() called with: viewType = [$viewType]")
  }

  @SuppressLint("NonConstantResourceId")
  override fun onClick(view: View) {
    when (view.id) {
      R.id.imgUndo -> {
        mPhotoEditor!!.undo()
      }
      R.id.imgRedo -> {
        mPhotoEditor!!.redo()
      }
      R.id.btnSave -> {
        saveImage()
      }
      R.id.imgClose -> {
        onBackPressed()
      }
    }
  }

  private fun isSdkHigherThan28(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
  }

  private fun saveImage() {
    val fileName = System.currentTimeMillis().toString() + ".png"
    val hasStoragePermission = ContextCompat.checkSelfPermission(
      this,
      Manifest.permission.WRITE_EXTERNAL_STORAGE
    ) == PackageManager.PERMISSION_GRANTED
    if (hasStoragePermission || isSdkHigherThan28()) {
      showLoading("Saving...")
      val path: File = Environment.getExternalStoragePublicDirectory(
        Environment.DIRECTORY_PICTURES
      )
      val file = File(path, fileName)
      path.mkdirs()

      // 使用PhotoEditor保存编辑后的图像
      val saveTask = Runnable {
        // 如果有调整过的图像，先应用到PhotoEditorView
        if (mImageAdjustHelper != null && mImageAdjustHelper!!.adjustedBitmap != null) {
          mPhotoEditorView?.source?.setImageBitmap(mImageAdjustHelper!!.adjustedBitmap)
        }

        mPhotoEditor!!.saveAsFile(file.absolutePath, object : OnSaveListener {
          override fun onSuccess(@NonNull imagePath: String) {
            hideLoading()
            val intent = Intent()
            intent.putExtra("path", imagePath)
            setResult(ResponseCode.RESULT_OK, intent)
            finish()
          }

          override fun onFailure(@NonNull exception: Exception) {
            hideLoading()
            Log.e(TAG, "保存失败: ${exception.message}", exception)
            if (!hasStoragePermission) {
              requestPer()
            } else {
              mPhotoEditorView?.let {
                val snackBar = Snackbar.make(
                  it, R.string.save_error,
                  Snackbar.LENGTH_SHORT)
                snackBar.setBackgroundTint(Color.WHITE)
                snackBar.setActionTextColor(Color.BLACK)
                snackBar.setAction("Ok", null).show()
              }
            }
          }
        })
      }

      // 在UI线程上运行保存任务
      if (Looper.myLooper() != Looper.getMainLooper()) {
        runOnUiThread(saveTask)
      } else {
        saveTask.run()
      }
    } else {
      requestPer()
    }
  }

  private fun requestPer() {
    requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
  }

  override fun onColorChanged(colorCode: Int) {
    mPhotoEditor!!.setShape(mShapeBuilder!!.withShapeColor(colorCode))
    mTxtCurrentTool!!.setText(R.string.label_brush)
  }

  override fun onOpacityChanged(opacity: Int) {
    mPhotoEditor!!.setShape(mShapeBuilder!!.withShapeOpacity(opacity))
    mTxtCurrentTool!!.setText(R.string.label_brush)
  }

  override fun onShapeSizeChanged(shapeSize: Int) {
    mPhotoEditor!!.setShape(mShapeBuilder!!.withShapeSize(shapeSize.toFloat()))
    mTxtCurrentTool!!.setText(R.string.label_brush)
  }

  override fun onShapePicked(shapeType: ShapeType) {
    mPhotoEditor!!.setShape(mShapeBuilder!!.withShapeType(shapeType))
  }

  override fun onStickerClick(bitmap: Bitmap) {
    mPhotoEditor!!.addImage(bitmap)
    mTxtCurrentTool!!.setText(R.string.label_sticker)
  }

  private fun showSaveDialog() {
    val builder = AlertDialog.Builder(this)
    builder.setMessage(getString(R.string.msg_save_image))
    builder.setPositiveButton("Save") { _: DialogInterface?, _: Int -> saveImage() }
    builder.setNegativeButton("Cancel") { dialog: DialogInterface, _: Int -> dialog.dismiss() }
    builder.setNeutralButton("Discard") { _: DialogInterface?, _: Int -> onCancel() }
    builder.create().show()
  }

  private fun onCancel() {
    val intent = Intent()
    setResult(ResponseCode.RESULT_CANCELED, intent)
    finish()
  }

  override fun onFilterSelected(photoFilter: PhotoFilter) {
    mPhotoEditor!!.setFilterEffect(photoFilter)
  }

  override fun onToolSelected(toolType: ToolType) {
    when (toolType) {
      ToolType.SHAPE -> {
        mPhotoEditor!!.setBrushDrawingMode(true)
        mShapeBuilder = ShapeBuilder()
        mPhotoEditor!!.setShape(mShapeBuilder)
        mTxtCurrentTool!!.setText(R.string.label_shape)
        showBottomSheetDialogFragment(mShapeBSFragment)
      }
      ToolType.ERASER -> {
        mPhotoEditor!!.brushEraser()
        mTxtCurrentTool!!.setText(R.string.label_eraser)
      }
      ToolType.FILTER -> {
        mTxtCurrentTool!!.setText(R.string.label_filter)
        showFilter(true)
      }
      ToolType.TEXT -> {
        val textEditorDialogFragment = TextEditorDialogFragment.show(this)
        textEditorDialogFragment.setOnTextEditorListener { inputText: String?, colorCode: Int ->
          val styleBuilder = TextStyleBuilder()
          styleBuilder.withTextColor(colorCode)
          mPhotoEditor!!.addText(inputText, styleBuilder)
          mTxtCurrentTool!!.setText(R.string.label_text)
        }
      }
      ToolType.ADJUST -> {
        mTxtCurrentTool!!.setText(R.string.label_adjust)
        // 确保只在有原始图像时创建ImageAdjustHelper
        if (mOriginalBitmap != null) {
          if (mImageAdjustHelper == null) {
            Log.d(TAG, "创建ImageAdjustHelper")
            mImageAdjustHelper = ImageAdjustHelper(mPhotoEditorView!!.source, mOriginalBitmap!!)
          }
          showBottomSheetDialogFragment(mAdjustFragment)
        } else {
          // 如果原始图像为空，尝试重新获取
          try {
            val bitmap = Bitmap.createBitmap(
              mPhotoEditorView!!.source.width,
              mPhotoEditorView!!.source.height,
              Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bitmap)
            mPhotoEditorView!!.source.drawable.setBounds(
              0, 0,
              mPhotoEditorView!!.source.width,
              mPhotoEditorView!!.source.height
            )
            mPhotoEditorView!!.source.drawable.draw(canvas)
            mOriginalBitmap = bitmap

            Log.d(TAG, "调整工具: 重新获取原始图像成功")
            mImageAdjustHelper = ImageAdjustHelper(mPhotoEditorView!!.source, mOriginalBitmap!!)
            showBottomSheetDialogFragment(mAdjustFragment)
          } catch (e: Exception) {
            Log.e(TAG, "调整工具: 获取原始图像失败: ${e.message}")
            // 显示错误提示
            Snackbar.make(
              mPhotoEditorView!!,
              "无法获取原始图像，请重试",
              Snackbar.LENGTH_SHORT
            ).show()
          }
        }
      }
      else -> {
        mPhotoEditor!!.setBrushDrawingMode(false)
        mTxtCurrentTool!!.setText(R.string.app_name)
      }
    }
  }

  private fun showBottomSheetDialogFragment(fragment: BottomSheetDialogFragment?) {
    if (fragment == null || fragment.isAdded) {
      return
    }
    fragment.show(supportFragmentManager, fragment.tag)
  }

  fun showFilter(isVisible: Boolean) {
    mIsFilterVisible = isVisible
    mConstraintSet.clone(mRootView)
    if (isVisible) {
      mConstraintSet.clear(mRvFilters!!.id, ConstraintSet.START)
      mConstraintSet.connect(
        mRvFilters!!.id, ConstraintSet.START,
        ConstraintSet.PARENT_ID, ConstraintSet.START
      )
      mConstraintSet.connect(
        mRvFilters!!.id, ConstraintSet.END,
        ConstraintSet.PARENT_ID, ConstraintSet.END
      )
    } else {
      mConstraintSet.connect(
        mRvFilters!!.id, ConstraintSet.START,
        ConstraintSet.PARENT_ID, ConstraintSet.END
      )
      mConstraintSet.clear(mRvFilters!!.id, ConstraintSet.END)
    }
    val changeBounds = ChangeBounds()
    changeBounds.duration = 350
    changeBounds.interpolator = AnticipateOvershootInterpolator(1.0f)
    TransitionManager.beginDelayedTransition(mRootView!!, changeBounds)
    mConstraintSet.applyTo(mRootView)
  }

  override fun onBackPressed() {
    if (mIsFilterVisible) {
      showFilter(false)
      mTxtCurrentTool!!.setText(R.string.app_name)
    } else if (!mPhotoEditor!!.isCacheEmpty) {
      showSaveDialog()
    } else {
      onCancel()
    }
  }

  // 实现AdjustFragment.AdjustListener接口方法
  override fun onBrightnessChanged(brightness: Int) {
    mImageAdjustHelper?.setBrightness(brightness)
  }

  override fun onContrastChanged(contrast: Int) {
    mImageAdjustHelper?.setContrast(contrast)
  }

  override fun onSaturationChanged(saturation: Int) {
    mImageAdjustHelper?.setSaturation(saturation)
  }

  override fun onAdjustReset() {
    mImageAdjustHelper?.resetAdjustments()
  }

  // 重写onDestroy方法，释放资源
  override fun onDestroy() {
    super.onDestroy()
    mImageAdjustHelper?.release()
    mImageAdjustHelper = null
    mOriginalBitmap?.recycle()
    mOriginalBitmap = null
  }

  companion object {
    private val TAG = PhotoEditorActivity::class.java.simpleName
    const val PINCH_TEXT_SCALABLE_INTENT_KEY = "PINCH_TEXT_SCALABLE"
    const val READ_WRITE_STORAGE = 52
  }
}
