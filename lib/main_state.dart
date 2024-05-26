import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImagesCubit extends Cubit<List<PlatformFile>>{
  ImagesCubit() : super([]);

  void addFiles(List<PlatformFile>  files){
    emit(files);
  }
  
}