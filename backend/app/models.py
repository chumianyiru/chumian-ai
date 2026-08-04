from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field

class ClientVerify(BaseModel):
    package_name: str
    signature_md5: str

class SendCode(BaseModel):
    email: EmailStr

class Register(BaseModel):
    email: EmailStr
    code: str = Field(..., min_length=4, max_length=10)
    password: str = Field(..., min_length=6)
    nickname: str = Field(..., min_length=1, max_length=32)

class Login(BaseModel):
    email: EmailStr
    password: str
    package_name: str
    signature_md5: str

class UserOut(BaseModel):
    id: int
    email: str
    nickname: str
    points_balance: int
    daily_points: int
    is_banned: bool
    banned_until: Optional[str]
    oobe_completed: bool

class ConversationCreate(BaseModel):
    title: Optional[str] = "新对话"
    model: Optional[str] = "GLM-4-Flash"

class MessageCreate(BaseModel):
    content: str
    attachments: Optional[List[dict]] = []

class AgentCreate(BaseModel):
    name: str
    description: str
    system_prompt: str
    icon: Optional[str] = ""
    published: bool = False

class AgentOut(BaseModel):
    id: int
    user_id: int
    name: str
    description: str
    system_prompt: str
    icon: Optional[str]
    published: bool
    created_at: str

class PostCreate(BaseModel):
    title: Optional[str] = ""
    content: str
    media_url: Optional[str] = ""

class CommentCreate(BaseModel):
    content: str

class TemplateOut(BaseModel):
    id: int
    category: str
    title: str
    prompt: str
    icon: str

class ModelInfo(BaseModel):
    id: str
    name: str
    type: str
    description: str
