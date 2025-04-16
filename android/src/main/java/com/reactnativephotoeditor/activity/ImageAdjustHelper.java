package com.reactnativephotoeditor.activity;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Paint;
import android.util.Log;
import android.widget.ImageView;

/**
 * 图像调整工具类，提供亮度、对比度和饱和度的调整功能
 */
public class ImageAdjustHelper {
    private static final String TAG = "ImageAdjustHelper";

    private float brightness = 1.0f;  // 默认亮度为1.0（不变）
    private float contrast = 1.0f;    // 默认对比度为1.0（不变）
    private float saturation = 1.0f;  // 默认饱和度为1.0（不变）

    private ImageView targetImageView;
    private Bitmap originalBitmap;
    private Bitmap adjustedBitmap;

    public ImageAdjustHelper(ImageView imageView, Bitmap originalBitmap) {
        this.targetImageView = imageView;
        // 使用源图像的副本，确保原始图像不会被修改
        this.originalBitmap = originalBitmap.copy(originalBitmap.getConfig(), true);
        Log.d(TAG, "创建ImageAdjustHelper - 原始图像尺寸: " + this.originalBitmap.getWidth() + "x" + this.originalBitmap.getHeight());

        // 创建一个空白bitmap用于调整后的图像
        this.adjustedBitmap = Bitmap.createBitmap(
                originalBitmap.getWidth(),
                originalBitmap.getHeight(),
                Bitmap.Config.ARGB_8888);
    }

    /**
     * 设置亮度（0-200，100为原始亮度）
     */
    public void setBrightness(int brightness) {
        this.brightness = brightness / 100.0f;
        Log.d(TAG, "setBrightness: " + this.brightness);
        applyAdjustments();
    }

    /**
     * 设置对比度（0-200，100为原始对比度）
     */
    public void setContrast(int contrast) {
        this.contrast = contrast / 100.0f;
        Log.d(TAG, "setContrast: " + this.contrast);
        applyAdjustments();
    }

    /**
     * 设置饱和度（0-200，100为原始饱和度）
     */
    public void setSaturation(int saturation) {
        this.saturation = saturation / 100.0f;
        Log.d(TAG, "setSaturation: " + this.saturation);
        applyAdjustments();
    }

    /**
     * 重置所有调整
     */
    public void resetAdjustments() {
        this.brightness = 1.0f;
        this.contrast = 1.0f;
        this.saturation = 1.0f;
        Log.d(TAG, "resetAdjustments - 重置所有参数");
        applyAdjustments();
    }

    /**
     * 应用所有调整到图像
     */
    private void applyAdjustments() {
        try {
            // 确保原始图像存在
            if (originalBitmap == null || originalBitmap.isRecycled()) {
                Log.e(TAG, "原始图像为空或已回收");
                return;
            }

            // 清空调整后的bitmap
            Canvas canvas = new Canvas(adjustedBitmap);
            canvas.drawColor(0); // 清除旧内容

            Paint paint = new Paint();
            paint.setAntiAlias(true);
            paint.setFilterBitmap(true);

            // 创建色彩矩阵
            ColorMatrix colorMatrix = new ColorMatrix();

            // 应用亮度
            ColorMatrix brightnessMatrix = new ColorMatrix();
            brightnessMatrix.set(new float[] {
                    1, 0, 0, 0, (brightness - 1.0f) * 255,
                    0, 1, 0, 0, (brightness - 1.0f) * 255,
                    0, 0, 1, 0, (brightness - 1.0f) * 255,
                    0, 0, 0, 1, 0
            });
            colorMatrix.postConcat(brightnessMatrix);

            // 应用对比度
            float scale = contrast;
            float translate = (-.5f * scale + .5f) * 255.0f;
            ColorMatrix contrastMatrix = new ColorMatrix();
            contrastMatrix.set(new float[] {
                    scale, 0, 0, 0, translate,
                    0, scale, 0, 0, translate,
                    0, 0, scale, 0, translate,
                    0, 0, 0, 1, 0
            });
            colorMatrix.postConcat(contrastMatrix);

            // 应用饱和度
            ColorMatrix saturationMatrix = new ColorMatrix();
            saturationMatrix.setSaturation(saturation);
            colorMatrix.postConcat(saturationMatrix);

            // 应用色彩矩阵
            paint.setColorFilter(new ColorMatrixColorFilter(colorMatrix));
            canvas.drawBitmap(originalBitmap, 0, 0, paint);

            // 更新图像视图
            targetImageView.post(new Runnable() {
                @Override
                public void run() {
                    if (targetImageView != null) {
                        targetImageView.setImageBitmap(adjustedBitmap);
                        Log.d(TAG, "更新ImageView完成");
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "应用调整时出错: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * 获取调整后的Bitmap
     */
    public Bitmap getAdjustedBitmap() {
        return adjustedBitmap;
    }

    /**
     * 释放资源
     */
    public void release() {
        Log.d(TAG, "释放资源");
        if (adjustedBitmap != null && !adjustedBitmap.isRecycled()) {
            adjustedBitmap.recycle();
            adjustedBitmap = null;
        }
        if (originalBitmap != null && !originalBitmap.isRecycled()) {
            originalBitmap.recycle();
            originalBitmap = null;
        }
        targetImageView = null;
    }
}
