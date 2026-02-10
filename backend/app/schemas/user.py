from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

# Request Schemas (Input) for user registration, login, and profile update
class UserCreate(BaseModel): 
    """Schema for user registration"""
    email: EmailStr
    password: str = Field(..., min_length=6, description="Password must be at least 6 characters")
    full_name: str = Field(..., min_length=2, description="Full name is required")

class UserLogin(BaseModel):
    """Schema for user login"""
    email: EmailStr
    password: str

class UserUpdate(BaseModel):
    """Schema for updating user profile"""
    full_name: Optional[str] = Field(None, min_length=2)
    email: Optional[EmailStr] = None

# Response Schemas (Output)
class UserResponse(BaseModel):
    """Schema for user data in responses (no password!)"""
    id: int
    email: str
    full_name: str
    is_active: bool
    is_verified: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True  # Allows SQLAlchemy model to Pydantic conversion

class Token(BaseModel):
    """Schema for JWT token response"""
    access_token: str
    token_type: str = "bearer"

class TokenData(BaseModel):
    """Schema for decoded token data"""
    email: Optional[str] = None
