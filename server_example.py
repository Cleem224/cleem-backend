from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import jwt
from jwt.exceptions import InvalidTokenError
from datetime import datetime, timedelta
import os
from google.oauth2 import id_token
from google.auth.transport import requests
import uuid
from sqlalchemy import create_engine, Column, String, DateTime, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Настройки приложения
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com")
JWT_SECRET = os.environ.get("JWT_SECRET", "supersecret")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION = 60 * 24 * 7  # 7 дней

# Инициализация FastAPI
app = FastAPI(title="Cleem API", version="1.0.0")

# Настройка CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене укажите только разрешенные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Настройка базы данных
SQLALCHEMY_DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./cleem.db")
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Схема OAuth2
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Модели данных
class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String, nullable=True)
    picture = Column(String, nullable=True)
    google_id = Column(String, unique=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    
# Создание таблиц
Base.metadata.create_all(bind=engine)

# Pydantic модели
class GoogleSignInRequest(BaseModel):
    id_token: str

class UserResponse(BaseModel):
    id: str
    email: str
    name: Optional[str] = None
    picture: Optional[str] = None
    google_id: str
    created_at: str
    updated_at: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

# Вспомогательные функции
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=JWT_EXPIRATION)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def get_current_user(token: str = Depends(oauth2_scheme), db = Depends(get_db)):
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user

# Маршруты API
@app.post("/auth/google", response_model=TokenResponse)
async def google_signin(request: GoogleSignInRequest, db = Depends(get_db)):
    try:
        # Проверяем токен Google
        idinfo = id_token.verify_oauth2_token(
            request.id_token, requests.Request(), GOOGLE_CLIENT_ID
        )
        
        # Проверяем, что токен валидный
        if idinfo["iss"] not in ["accounts.google.com", "https://accounts.google.com"]:
            raise HTTPException(status_code=400, detail="Invalid issuer")
        
        # Получаем данные пользователя из токена
        google_id = idinfo["sub"]
        email = idinfo.get("email")
        name = idinfo.get("name")
        picture = idinfo.get("picture")
        
        # Ищем пользователя в базе данных
        user = db.query(User).filter(User.google_id == google_id).first()
        
        if not user:
            # Если пользователя нет, создаем нового
            user = User(
                id=str(uuid.uuid4()),
                email=email,
                name=name,
                picture=picture,
                google_id=google_id,
                created_at=datetime.utcnow()
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            # Если пользователь уже существует, обновляем данные
            user.name = name
            user.picture = picture
            user.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(user)
        
        # Создаем JWT токен
        access_token = create_access_token({"sub": user.id})
        
        # Создаем ответ
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "email": user.email,
                "name": user.name,
                "picture": user.picture,
                "google_id": user.google_id,
                "created_at": user.created_at.isoformat(),
                "updated_at": user.updated_at.isoformat() if user.updated_at else None
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not validate credentials: {str(e)}")

# Защищенные маршруты
@app.get("/user/profile", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "name": current_user.name,
        "picture": current_user.picture,
        "google_id": current_user.google_id,
        "created_at": current_user.created_at.isoformat(),
        "updated_at": current_user.updated_at.isoformat() if current_user.updated_at else None
    }

# Запуск сервера
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 