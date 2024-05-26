import pyheif
from PIL import Image
import os

def convert_heic_to_jpg(heic_file_path, jpg_file_path):
    heic_file = pyheif.read(heic_file_path)
    image = Image.frombytes(
        heic_file.mode, 
        heic_file.size, 
        heic_file.data,
        "raw",
        heic_file.mode,
        heic_file.stride,
    )
    image.save(jpg_file_path, "JPEG")
    return jpg_file_path

# Example usage:
heic_file_path = "C:\\Users\\affan\\allTripMay\\202405__\\IMG_0140.HEIC"
jpg_file_path = "example.jpg"

if os.path.exists(heic_file_path):
    convert_heic_to_jpg(heic_file_path, jpg_file_path)
    print(f"HEIC image converted to JPEG: {jpg_file_path}")
else:
    print(f"HEIC file not found: {heic_file_path}")
