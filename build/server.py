from fastapi import FastAPI, Depends, HTTPException, status, Request, Response
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr, validator
from typing import Optional, List, Dict, Any
import jwt
from jwt.exceptions import InvalidTokenError
from datetime import datetime, timedelta
import os
import time
import uuid
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
import json
from sqlalchemy import create_engine, Column, String, DateTime, Boolean, Integer, ForeignKey, Text, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship, Session
from google.oauth2 import id_token
from google.auth.transport import requests
from dotenv import load_dotenv
import sentry_sdk
from sentry_sdk.integrations.asgi import SentryAsgiMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response as StarletteResponse
import secrets
import hashlib
from contextlib import contextmanager
import tenacity
from tenacity import retry, stop_after_attempt, wait_exponential

# Load environment variables from .env file
load_dotenv()

# Configure logging
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)
log_file = log_dir / "app.log"

logger = logging.getLogger("cleem_api")
logger.setLevel(logging.INFO)
file_handler = RotatingFileHandler(log_file, maxBytes=10485760, backupCount=5)
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(file_handler)
console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(console_handler)

# App configuration
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID")
if not GOOGLE_CLIENT_ID:
    logger.error("GOOGLE_CLIENT_ID environment variable not set!")
    raise ValueError("GOOGLE_CLIENT_ID environment variable not set!")

JWT_SECRET = os.environ.get("JWT_SECRET")
if not JWT_SECRET and ENVIRONMENT == "production":
    JWT_SECRET = secrets.token_hex(32)
    logger.warning(f"JWT_SECRET not set! Generated random secret: {JWT_SECRET}")
elif not JWT_SECRET:
    JWT_SECRET = "dev_secret_key_do_not_use_in_production"
    logger.warning("Using default JWT_SECRET for development")

JWT_ALGORITHM = "HS256"
JWT_EXPIRATION = int(os.environ.get("JWT_EXPIRATION", 60 * 24 * 7))  # 7 days default

# Database configuration
if ENVIRONMENT == "production":
    DATABASE_URL = os.environ.get("DATABASE_URL")
    if not DATABASE_URL:
        logger.error("DATABASE_URL environment variable not set in production!")
        raise ValueError("DATABASE_URL environment variable not set!")
else:
    DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./cleem.db")

# Sentry configuration for error tracking
SENTRY_DSN = os.environ.get("SENTRY_DSN")
if SENTRY_DSN and ENVIRONMENT == "production":
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        environment=ENVIRONMENT,
        traces_sample_rate=0.2,
    )
    logger.info("Sentry initialized for error tracking")

# Initialize FastAPI
app = FastAPI(
    title="Cleem API",
    description="API for Cleem nutrition app",
    version="1.0.0",
    docs_url=None if ENVIRONMENT == "production" else "/docs",
    redoc_url=None if ENVIRONMENT == "production" else "/redoc",
)

# Add Sentry middleware if configured
if SENTRY_DSN and ENVIRONMENT == "production":
    app.add_middleware(SentryAsgiMiddleware)

# Configure CORS
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# Setup metrics
REQUESTS = Counter("http_requests_total", "Total HTTP Requests", ["method", "endpoint", "status"])
REQUEST_TIME = Histogram("http_request_duration_seconds", "HTTP Request Duration", ["method", "endpoint"])

# Setup Database
@contextmanager
def get_db_connection():
    """Create a new database connection."""
    try:
        engine = create_engine(
            DATABASE_URL, 
            pool_pre_ping=True,
            pool_recycle=3600,
            connect_args={"connect_timeout": 10} if "postgresql" in DATABASE_URL else {}
        )
        connection = engine.connect()
        yield connection
    finally:
        connection.close()
        engine.dispose()

@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    retry=tenacity.retry_if_exception_type(Exception),
    before_sleep=lambda retry_state: logger.warning(f"Database connection attempt {retry_state.attempt_number} failed. Retrying...")
)
def setup_database():
    """Setup database with retry logic for production environments"""
    with get_db_connection() as connection:
        logger.info("Database connection successful")
        
    engine = create_engine(
        DATABASE_URL, 
        pool_pre_ping=True,
        pool_recycle=3600,
        connect_args={"connect_timeout": 10} if "postgresql" in DATABASE_URL else {}
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return engine, SessionLocal

engine, SessionLocal = setup_database()
Base = declarative_base()

# Define database models
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
    last_login = Column(DateTime, nullable=True)

# Create database tables
Base.metadata.create_all(bind=engine)

# Pydantic models for API
class GoogleSignInRequest(BaseModel):
    id_token: str

    @validator("id_token")
    def token_must_not_be_empty(cls, v):
        if not v or len(v) < 10:  # Simple validation
            raise ValueError("Invalid token format")
        return v

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
    expires_in: int
    user: UserResponse

# Helper functions
@contextmanager
def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=JWT_EXPIRATION)
    to_encode.update({"exp": expire})
    to_encode.update({"iat": datetime.utcnow()})  # Issued at time
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt, int((expire - datetime.utcnow()).total_seconds())

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """Validate the JWT token and get the current user"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except InvalidTokenError as e:
        logger.warning(f"Invalid token: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if user is None or not user.is_active:
        logger.warning(f"User not found or inactive: {user_id}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user

# Middlewares
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware to collect metrics on API requests"""
    start_time = time.time()
    
    # Set request ID for tracing
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    response = await call_next(request)
    
    # Skip metrics for /metrics endpoint
    if request.url.path != "/metrics":
        duration = time.time() - start_time
        status_code = response.status_code
        endpoint = request.url.path
        method = request.method
        
        REQUESTS.labels(method=method, endpoint=endpoint, status=status_code).inc()
        REQUEST_TIME.labels(method=method, endpoint=endpoint).observe(duration)
        
        # Log request info
        logger.info(
            f"RequestID: {request_id} | {method} {endpoint} | Status: {status_code} | Duration: {duration:.4f}s"
        )
    
    return response

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)
    
    # Security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    
    return response

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    try:
        # Test database connection
        with get_db() as db:
            db.execute("SELECT 1")
        return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {"status": "unhealthy", "error": str(e), "timestamp": datetime.utcnow().isoformat()}

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return StarletteResponse(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

# API routes
@app.post("/auth/google", response_model=TokenResponse)
async def google_signin(request: GoogleSignInRequest, db: Session = Depends(get_db)):
    """Authenticate with Google and create or update user"""
    try:
        # Verify Google token
        idinfo = id_token.verify_oauth2_token(
            request.id_token, requests.Request(), GOOGLE_CLIENT_ID
        )
        
        # Verify issuer
        if idinfo["iss"] not in ["accounts.google.com", "https://accounts.google.com"]:
            logger.warning(f"Invalid token issuer: {idinfo['iss']}")
            raise HTTPException(status_code=400, detail="Invalid issuer")
        
        # Get user data from token
        google_id = idinfo["sub"]
        email = idinfo.get("email")
        name = idinfo.get("name")
        picture = idinfo.get("picture")
        
        # Find user in database
        user = db.query(User).filter(User.google_id == google_id).first()
        
        if not user:
            # Create new user
            user = User(
                id=str(uuid.uuid4()),
                email=email,
                name=name,
                picture=picture,
                google_id=google_id,
                created_at=datetime.utcnow(),
                last_login=datetime.utcnow()
            )
            db.add(user)
            logger.info(f"New user created: {email}")
        else:
            # Update existing user
            user.name = name
            user.picture = picture
            user.updated_at = datetime.utcnow()
            user.last_login = datetime.utcnow()
            logger.info(f"User logged in: {email}")
        
        db.commit()
        db.refresh(user)
        
        # Create JWT token
        access_token, expires_in = create_access_token({"sub": user.id})
        
        # Create response
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": expires_in,
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
        logger.error(f"Google sign-in error: {str(e)}")
        if ENVIRONMENT == "production":
            raise HTTPException(status_code=400, detail="Could not validate credentials")
        else:
            raise HTTPException(status_code=400, detail=f"Could not validate credentials: {str(e)}")

# Protected routes
@app.get("/user/profile", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Get current user profile"""
    return {
        "id": current_user.id,
        "email": current_user.email,
        "name": current_user.name,
        "picture": current_user.picture,
        "google_id": current_user.google_id,
        "created_at": current_user.created_at.isoformat(),
        "updated_at": current_user.updated_at.isoformat() if current_user.updated_at else None
    }

@app.get("/status")
async def status(current_user: User = Depends(get_current_user)):
    """Protected status endpoint"""
    return {
        "status": "authenticated",
        "user_id": current_user.id,
        "environment": ENVIRONMENT,
        "timestamp": datetime.utcnow().isoformat()
    }

# Server startup and shutdown events
@app.on_event("startup")
async def startup_event():
    """Execute when the application starts"""
    logger.info(f"Starting Cleem API in {ENVIRONMENT} mode")
    logger.info(f"Database: {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL}")

@app.on_event("shutdown")
async def shutdown_event():
    """Execute when the application shuts down"""
    logger.info("Shutting down Cleem API")

# Run server
if __name__ == "__main__":
    import uvicorn
    
    host = "0.0.0.0"
    port = int(os.environ.get("PORT", 8000))
    
    logger.info(f"Starting Uvicorn server on {host}:{port}")
    uvicorn.run(
        "server:app",
        host=host,
        port=port,
        reload=ENVIRONMENT != "production",
        workers=4 if ENVIRONMENT == "production" else 1,
        access_log=True,
    ) 