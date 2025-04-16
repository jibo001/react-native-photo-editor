package com.reactnativephotoeditor.activity;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.SeekBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.reactnativephotoeditor.R;

public class AdjustFragment extends BottomSheetDialogFragment implements SeekBar.OnSeekBarChangeListener {
    private static final String TAG = "AdjustFragment";

    private AdjustListener mAdjustListener;
    private SeekBar sbBrightness, sbContrast, sbSaturation;
    private TextView tvBrightnessValue, tvContrastValue, tvSaturationValue;
    private Button btnReset;

    public interface AdjustListener {
        void onBrightnessChanged(int brightness);
        void onContrastChanged(int contrast);
        void onSaturationChanged(int saturation);
        void onAdjustReset();
    }

    public void setAdjustListener(AdjustListener adjustListener) {
        mAdjustListener = adjustListener;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_adjust_settings, container, false);

        // 查找控件
        sbBrightness = view.findViewById(R.id.sbBrightness);
        sbContrast = view.findViewById(R.id.sbContrast);
        sbSaturation = view.findViewById(R.id.sbSaturation);
        btnReset = view.findViewById(R.id.btnReset);

        // 查找参数值文本显示控件
        tvBrightnessValue = view.findViewById(R.id.txtBrightnessValue);
        tvContrastValue = view.findViewById(R.id.txtContrastValue);
        tvSaturationValue = view.findViewById(R.id.txtSaturationValue);

        // 设置初始值为100（表示原始图像，无调整）
        sbBrightness.setProgress(100);
        sbContrast.setProgress(100);
        sbSaturation.setProgress(100);
        updateValueText(sbBrightness);
        updateValueText(sbContrast);
        updateValueText(sbSaturation);

        Log.d(TAG, "初始化滑动条: 亮度=100, 对比度=100, 饱和度=100");

        // 设置监听器
        sbBrightness.setOnSeekBarChangeListener(this);
        sbContrast.setOnSeekBarChangeListener(this);
        sbSaturation.setOnSeekBarChangeListener(this);

        btnReset.setOnClickListener(v -> {
            Log.d(TAG, "点击重置按钮");
            sbBrightness.setProgress(100);
            sbContrast.setProgress(100);
            sbSaturation.setProgress(100);
            updateValueText(sbBrightness);
            updateValueText(sbContrast);
            updateValueText(sbSaturation);
            if (mAdjustListener != null) {
                mAdjustListener.onAdjustReset();
            }
        });

        return view;
    }

    /**
     * 更新参数值文本显示
     */
    private void updateValueText(SeekBar seekBar) {
        int progress = seekBar.getProgress();
        int id = seekBar.getId();

        if (id == R.id.sbBrightness && tvBrightnessValue != null) {
            tvBrightnessValue.setText(progress + "%");
        } else if (id == R.id.sbContrast && tvContrastValue != null) {
            tvContrastValue.setText(progress + "%");
        } else if (id == R.id.sbSaturation && tvSaturationValue != null) {
            tvSaturationValue.setText(progress + "%");
        }
    }

    @Override
    public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        updateValueText(seekBar);

        if (mAdjustListener != null) {
            int id = seekBar.getId();
            if (id == R.id.sbBrightness) {
                mAdjustListener.onBrightnessChanged(progress);
            } else if (id == R.id.sbContrast) {
                mAdjustListener.onContrastChanged(progress);
            } else if (id == R.id.sbSaturation) {
                mAdjustListener.onSaturationChanged(progress);
            }
        }
    }

    @Override
    public void onStartTrackingTouch(SeekBar seekBar) {
        // 不需要实现
    }

    @Override
    public void onStopTrackingTouch(SeekBar seekBar) {
        // 用户完成滑动后记录日志
        if (seekBar.getId() == R.id.sbBrightness) {
            Log.d(TAG, "亮度调整完成: " + seekBar.getProgress() + "%");
        } else if (seekBar.getId() == R.id.sbContrast) {
            Log.d(TAG, "对比度调整完成: " + seekBar.getProgress() + "%");
        } else if (seekBar.getId() == R.id.sbSaturation) {
            Log.d(TAG, "饱和度调整完成: " + seekBar.getProgress() + "%");
        }
    }
}
