package com.reactnativephotoeditor.activity;

import android.content.Context;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import androidx.core.content.ContextCompat;

public class DrawableHelper {

    /**
     * 创建带有圆角和边框的颜色背景
     * @param context 上下文
     * @param color 要设置的颜色
     * @param borderWidthDp 边框宽度，单位dp
     * @param borderColor 边框颜色
     * @param cornerRadiusDp 圆角半径，单位dp
     * @return 带有圆角和边框的Drawable
     */
    public static Drawable createRoundedColorDrawable(Context context, int color, float borderWidthDp, int borderColor, float cornerRadiusDp) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setShape(GradientDrawable.RECTANGLE);
        drawable.setColor(color);

        // 将dp转为px
        float density = context.getResources().getDisplayMetrics().density;
        int borderWidthPx = (int) (borderWidthDp * density + 0.5f);
        int cornerRadiusPx = (int) (cornerRadiusDp * density + 0.5f);

        drawable.setStroke(borderWidthPx, borderColor);
        drawable.setCornerRadius(cornerRadiusPx);

        return drawable;
    }
}
