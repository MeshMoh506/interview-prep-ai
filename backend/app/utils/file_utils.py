import os
import shutil
from pathlib import Path
from datetime import datetime
from fastapi import UploadFile, HTTPException, status
from app.config import settings

def validate_file(file: UploadFile) -> None:
    """
    Validate uploaded file (extension and size)
    Raises HTTPException if validation fails
    """
    # Check file extension
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in settings.ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed types: {', '.join(settings.ALLOWED_EXTENSIONS)}"
        )
    
    # Check file size
    file.file.seek(0, 2)  # Seek to end
    file_size = file.file.tell()
    file.file.seek(0)  # Reset to beginning
    
    if file_size > settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size: {settings.MAX_FILE_SIZE / (1024*1024):.1f}MB"
        )
    
    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file uploaded"
        )

def get_unique_filename(user_id: int, original_filename: str) -> tuple[str, Path]:
    """
    Generate unique filename and full path for uploaded file
    Returns: (unique_filename, full_path)
    """
    # Create user directory
    user_dir = settings.UPLOAD_DIR / str(user_id)
    user_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate unique filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    name = Path(original_filename).stem
    ext = Path(original_filename).suffix.lower()
    unique_filename = f"{name}_{timestamp}{ext}"
    
    full_path = user_dir / unique_filename
    
    return unique_filename, full_path

def save_upload_file(upload_file: UploadFile, destination: Path) -> int:
    """
    Save uploaded file to destination
    Returns: file size in bytes
    """
    try:
        with destination.open("wb") as buffer:
            shutil.copyfileobj(upload_file.file, buffer)
        return destination.stat().st_size
    except Exception as e:
        # Clean up partial file if save failed
        if destination.exists():
            destination.unlink()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save file: {str(e)}"
        )

def delete_file(file_path: str) -> None:
    """
    Delete file from filesystem
    """
    try:
        path = Path(file_path)
        if path.exists():
            path.unlink()
    except Exception as e:
        print(f"Warning: Failed to delete file {file_path}: {e}")
        # Don't raise exception, just log warning
