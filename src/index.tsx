import { NativeModules } from 'react-native';

export type Options = {
  path: string;
};

export type ErrorCode =
  | 'USER_CANCELLED'
  | 'IMAGE_LOAD_FAILED'
  | 'ACTIVITY_DOES_NOT_EXIST'
  | 'FAILED_TO_SAVE_IMAGE'
  | 'DONT_FIND_IMAGE'
  | 'ERROR_UNKNOW';

type PhotoEditorType = {
  open(option: Options): Promise<string>;
};

const { PhotoEditor } = NativeModules;

export default PhotoEditor as PhotoEditorType;
