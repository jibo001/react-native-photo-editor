package com.reactnativephotoeditor.activity;

import android.app.Dialog;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RadioGroup;
import android.widget.SeekBar;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.bottomsheet.BottomSheetDialog;
import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.reactnativephotoeditor.R;

import ja.burhanrashid52.photoeditor.shape.ShapeType;

public class ShapeBSFragment extends BottomSheetDialogFragment implements SeekBar.OnSeekBarChangeListener {

    public ShapeBSFragment() {
        // Required empty public constructor
    }

    private Properties mProperties;

    public interface Properties {
        void onColorChanged(int colorCode);

        void onOpacityChanged(int opacity);

        void onShapeSizeChanged(int shapeSize);

        void onShapePicked(ShapeType shapeType);
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setStyle(BottomSheetDialogFragment.STYLE_NORMAL, R.style.CustomBottomSheetDialogTheme);
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        Dialog dialog = super.onCreateDialog(savedInstanceState);
        if (dialog instanceof BottomSheetDialog) {
            ((BottomSheetDialog) dialog).getBehavior().setSkipCollapsed(true);
        }
        return dialog;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_bottom_shapes_dialog, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        RecyclerView rvColor = view.findViewById(R.id.shapeColors);
        SeekBar sbOpacity = view.findViewById(R.id.shapeOpacity);
        SeekBar sbBrushSize = view.findViewById(R.id.shapeSize);
        RadioGroup shapeGroup = view.findViewById(R.id.shapeRadioGroup);

        // shape picker
        shapeGroup.setOnCheckedChangeListener((group, checkedId) -> {
            if (checkedId == R.id.lineRadioButton) {
                mProperties.onShapePicked(ShapeType.LINE);
            } else if (checkedId == R.id.ovalRadioButton) {
                mProperties.onShapePicked(ShapeType.OVAL);
            } else if (checkedId == R.id.rectRadioButton) {
                mProperties.onShapePicked(ShapeType.RECTANGLE);
            } else {
                mProperties.onShapePicked(ShapeType.BRUSH);
            }
        });

        sbOpacity.setOnSeekBarChangeListener(this);
        sbBrushSize.setOnSeekBarChangeListener(this);

        LinearLayoutManager layoutManager = new LinearLayoutManager(getActivity(), LinearLayoutManager.HORIZONTAL, false);
        rvColor.setLayoutManager(layoutManager);
        rvColor.setHasFixedSize(true);
        ColorPickerAdapter colorPickerAdapter = new ColorPickerAdapter(getActivity());
        colorPickerAdapter.setOnColorPickerClickListener(colorCode -> {
            if (mProperties != null) {
                dismiss();
                mProperties.onColorChanged(colorCode);
            }
        });
        rvColor.setAdapter(colorPickerAdapter);
    }

    public void setPropertiesChangeListener(Properties properties) {
        mProperties = properties;
    }

    @Override
    public void onProgressChanged(SeekBar seekBar, int i, boolean b) {
      int id = seekBar.getId();
      if (id == R.id.shapeOpacity) {
        if (mProperties != null) {
          mProperties.onOpacityChanged(i);
        }
      } else if (id == R.id.shapeSize) {
        if (mProperties != null) {
          mProperties.onShapeSizeChanged(i);
        }
      }
    }

    @Override
    public void onStartTrackingTouch(SeekBar seekBar) {
    }

    @Override
    public void onStopTrackingTouch(SeekBar seekBar) {
    }
}
