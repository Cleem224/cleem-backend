# Cleem API Server

Production-ready FastAPI server for Cleem application with Google authentication.

## Features

- FastAPI-based RESTful API
- PostgreSQL database with SQLAlchemy ORM
- Google OAuth2 Authentication
- JWT token-based authentication
- Docker containerization
- NGINX reverse proxy with HTTPS
- Database migrations with Alembic
- Prometheus metrics and monitoring
- Error tracking with Sentry
- Health check endpoints
- Comprehensive logging
- Production-ready deployment with Docker Compose

## Prerequisites

- Docker
- Docker Compose
- OpenSSL (for certificate generation)

## Quick Start

1. Clone this repository
2. Copy `env.example` to `.env` and set your environment variables:
   ```
   cp env.example .env
   nano .env  # Edit the environment variables
   ```
3. Deploy the application:
   ```
   ./deploy.sh
   ```

## Environment Variables

Key environment variables to set in your `.env` file:

- `ENVIRONMENT`: Set to `production` for production deployment
- `GOOGLE_CLIENT_ID`: Your Google Client ID for authentication
- `JWT_SECRET`: Secret key for JWT token generation
- `DATABASE_URL`: PostgreSQL connection URL
- `ALLOWED_ORIGINS`: Comma-separated list of allowed origins for CORS
- `SENTRY_DSN`: Your Sentry DSN for error tracking

## Production Deployment Checklist

Before deploying to production, make sure to:

1. Replace self-signed SSL certificates with valid certificates
2. Set appropriate environment variables in `.env`
3. Configure proper database credentials
4. Update NGINX configuration with your domain name
5. Secure the metrics endpoint with a strong password
6. Set up a proper backup strategy for your database

## Database Migrations

The deployment script automatically runs database migrations, but you can also run them manually:

```
docker-compose run --rm api alembic upgrade head
```

To create a new migration:

```
docker-compose run --rm api alembic revision --autogenerate -m "Description of changes"
```

## API Endpoints

- `/auth/google`: Google OAuth2 authentication
- `/user/profile`: Get current user profile
- `/health`: Health check endpoint
- `/metrics`: Prometheus metrics (protected)
- `/status`: Protected status endpoint

## Monitoring

The API includes:

- Health check endpoint at `/health`
- Prometheus metrics at `/metrics` (protected with basic auth)
- Detailed logs in the `logs` directory
- Sentry error tracking (if configured)

## Architecture

The application is structured with the following services:

- `api`: FastAPI application
- `db`: PostgreSQL database
- `nginx`: NGINX reverse proxy for SSL termination and routing

## Troubleshooting

If you encounter issues:

1. Check the logs:
   ```
   docker-compose logs -f
   ```
2. Verify that your environment variables are properly set
3. Check the database connection
4. Review the NGINX configuration

## License

This project is proprietary and confidential. 