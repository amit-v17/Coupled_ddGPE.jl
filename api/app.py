from fastapi import FastAPI, BackgroundTasks, HTTPException, Security, Query, Path, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import APIKeyHeader
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from math import pi
import json
import os
import asyncio
from sqlalchemy import create_engine, Column, Integer, Float, String
from sqlalchemy.orm import declarative_base, sessionmaker 
from sqlalchemy import ForeignKey
import logging

# Configure logging
logging.basicConfig(level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%d-%m-%Y %H:%M:%S'                    
) # Set the logging level to INFO; can be changed to DEBUG for more verbosity
logging.getLogger("sqlalchemy").setLevel(logging.WARNING)
logger = logging.getLogger(__name__) # Create a logger instance for this module

# Define the SQLAlchemy base and engine for database interactions
Base = declarative_base() # Define the base class for SQLAlchemy models

# Define a SQLAlchemy model for storing simulation results
class Simulation(Base):
    __tablename__ = 'simulations'
    id = Column(Integer, primary_key=True)
    status = Column(String)
    result = Column(String)
    
class DataPoint(Base):
    __tablename__ = 'data_points'
    id = Column(Integer, primary_key=True)
    simulation_id = Column(Integer, ForeignKey("simulations.id"))
    Energy = Column(Float)
    Transmission = Column(Float)

# Create the SQLite database engine and session
engine = create_engine("sqlite:///api/.simulations.db", echo=False) # Connect to an SQL database; Using SQLite for simplicity; replace with preferred database URI later
SessionLocal = sessionmaker(bind=engine) # Create a session for database operations - open it, do operations, commit/close.
Base.metadata.create_all(engine) # Creates the table for every class inheriting from Base if it doesn't exist

# Load variables from .env file into environment variables
load_dotenv()

# Fetch the string from the environment and parse it back into a Python dictionary
try:
    VALID_API_KEYS = json.loads(os.getenv("VALID_API_KEYS", "{}")) # Defaults to empty dict if the variable is missing
except json.JSONDecodeError:
    raise RuntimeError("VALID_API_KEYS environment variable is not valid JSON")

# OpenAPI and Swagger metadata for external API consumers 
app = FastAPI(
    title="Coupled ddGPE Simulation API",
    version="1.0.0",
    summary="Run and query asynchronous coupled ddGPE simulations.",
    description=(
        "REST API for launching Julia-backed simulations and polling their status. "
        "Authentication uses an API key passed in the api-key header for protected endpoints. "
        "Validation errors use a custom 422 response shape documented in the endpoint responses."
    ),
    contact={"name": "AV"},
    openapi_tags=[
        {"name": "Health", "description": "Service readiness and availability checks."},
        {
            "name": "Simulations",
            "description": (
                "Submit asynchronous simulation jobs and query current results. "
                "No server-side pagination is applied to returned data_points."
            ),
        },
    ],
)

api_key_header = APIKeyHeader(
    name="api-key",
    auto_error=False,
    description="API key header required for protected endpoints.",
)


class ErrorDetail(BaseModel):
    field: str
    message: str
    type: str


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    details: list[ErrorDetail] | None = None


class DataPointResponse(BaseModel):
    Energy: float
    Transmission: float


class RunSimulationResponse(BaseModel):
    job_id: int
    status: str
    message: str


class SimulationStatusResponse(BaseModel):
    job_id: int
    status: str
    message: str
    data_points: list[DataPointResponse] | None = None


@app.exception_handler(RequestValidationError)
async def custom_validation_exception_handler(request: Request, exc: RequestValidationError):
    """Return a custom 422 payload shape for all validation failures."""
    details = []
    for error in exc.errors():
        location = ".".join(str(part) for part in error.get("loc", []))
        details.append(
            {
                "field": location,
                "message": error.get("msg", "Validation error"),
                "type": error.get("type", "value_error"),
            }
        )

    return JSONResponse(
        status_code=422,
        content={
            "error_code": "VALIDATION_ERROR",
            "message": "Request validation failed",
            "details": details,
        },
    )


@app.exception_handler(HTTPException)
async def custom_http_exception_handler(request: Request, exc: HTTPException):
    """Return HTTP errors in a consistent top-level schema."""
    if isinstance(exc.detail, dict):
        payload = exc.detail
    else:
        code_map = {401: "UNAUTHORIZED", 404: "NOT_FOUND"}
        payload = {
            "error_code": code_map.get(exc.status_code, "HTTP_ERROR"),
            "message": str(exc.detail),
            "details": None,
        }

    return JSONResponse(status_code=exc.status_code, content=payload)


@app.exception_handler(Exception)
async def custom_unhandled_exception_handler(request: Request, exc: Exception):
    """Return a stable payload shape for unexpected server errors."""
    logger.exception("Unhandled server error")
    return JSONResponse(
        status_code=500,
        content={
            "error_code": "INTERNAL_ERROR",
            "message": "Internal server error",
            "details": None,
        },
    )

# Define Pydantic request model for simulation parameters
class SimulationParams(BaseModel):
    """Simulation input parameters for the coupled ddGPE model."""
    hbar_Omega: float = Field(default=11.6, gt=0, le=100) # meV
    hbar_gamma_c: float = Field(default=5.6, gt=0, le=100) # meV
    hbar_gamma_x: float = Field(default=27.6, gt=0, le=100) # meV
    hbar_omega_x: float = Field(default=1645.4, gt=0) # meV
    hbar_detuning: float = Field(default=-1.0, gt=-100, le=100) # meV
    m_c: float = Field(default=1e-4 * 9.10938356e-31, gt=0) # kg
    A: float = Field(default=1e-4, gt=0) # Mass Ratio of cavity photon to exciton
    hbar: float = Field(default=6.62607004e-34/(2*pi)) # J·s
    sigma_x: float = Field(default=3.57e-6, gt=0) # m
    sigma_y: float = Field(default=4.7e-6, gt=0) # m
    y0: float = Field(default=-3.8e-6, gt=-1e-5, le=1e-5) # m
    hbar_sigma_e: float = Field(default=9.9, gt=0, le=100) # meV
    hbar_omega_pump: float = Field(default=1645.8, gt=0) # meV
    g: float=Field(default=3e-4, gt=0)
    g_s: float=Field(default=5e-4, gt=0)
    E_pulse: float=Field(default=1.18e-12, gt=0) # Joules
    no_div: int = Field(default=100, gt=1) # number of divisions for the pulse width
    t_end: int = Field(default=80, gt=1) # times the pulse_width
    samples: int = Field(default=500)
    size_sample: int = Field(default=20, gt=1) # times the samples numbers
    center_pulse: float = Field(default=1/4)
    spot_size: float = Field(default=5, gt=2)  # times the pump_σ
    N: int = Field(default=2**7, gt=2) # Number of spatial grid points (must be a power of 2 for FFT)
    seed: float = Field(default=1e-36) # Initial wavefunction Amplitude

# Define the background task to run the Julia simulation
async def run_simulation(sim_id: int, params: SimulationParams):
    """
    Function to run the Julia simulation in as an asynchronous subprocess.
    This function is intended to be run in the background.
    """
    multiline_command = f"""
    julia api/main.jl \
        {params.hbar_Omega} \
        {params.hbar_gamma_c} \
        {params.hbar_gamma_x} \
        {params.hbar_omega_x} \
        {params.hbar_detuning} \
        {params.m_c} \
        {params.A} \
        {params.hbar} \
        {params.sigma_x} \
        {params.sigma_y} \
        {params.y0} \
        {params.hbar_sigma_e} \
        {params.hbar_omega_pump} \
        {params.g} \
        {params.g_s} \
        {params.E_pulse} \
        {params.no_div} \
        {params.t_end} \
        {params.samples} \
        {params.size_sample} \
        {params.center_pulse} \
        {params.spot_size} \
        {params.N} \
        {params.seed}
    """
    process = await asyncio.create_subprocess_shell(
        multiline_command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    stdout, stderr = await process.communicate()
    
    db = SessionLocal()  # Create a new database session instance
    sim = db.query(Simulation).filter(Simulation.id == sim_id).first()
    
    if process.returncode != 0:
        sim.status = "failed"
        sim.result = "The Julia simulation failed to run."  # Store the error message in the result field
        logger.error(f"Simulation {sim_id} failed to run. Error: {stderr.decode()}")  # Log the error message
        db.commit()
        return
        
    try:
        output = json.loads(stdout.decode()) # Julia prints JSON; Python parses it
        sim.status = "completed"
        sim.result = "Successfully finished the job"  # json.dumps(output) # Store the result as a JSON string
        logger.info(f"Simulation {sim_id} completed successfully.")  # Log the successful completion
        
        # NEW: insert one DataPoint row per series entry
        for point in output["data_points"]:
            db.add(DataPoint(
                simulation_id=sim_id,
                Energy=point["Energy"],
                Transmission=point["Transmission"]
            ))
        db.commit()
        
    except json.JSONDecodeError:
        logger.error(f"Simulation {sim_id} failed to parse JSON Julia output.")  # Log the JSON parsing error
        sim.status = "failed"
        sim.result = "Failed to parse JSON output from Julia."  # Store the error message in the result field
        db.commit()
        
    db.close()  # Close the database session


## ENDPOINT DEFINITIONS

# Check status endpoint to verify that the API is running and the Julia engine is ready
@app.get(
    "/",
    tags=["Health"],
    summary="Service readiness check",
    description=(
        "Returns a simple readiness payload for clients to verify that the API process is running. "
        "No authentication is required for this endpoint."
    ),
    responses={
        200: {
            "description": "Service is available.",
            "content": {
                "application/json": {
                    "example": {"engine": "Julia", "ready": True}
                }
            },
        }
    },
)
def get_status():
    """Health endpoint used to verify API process availability."""
    logger.info("Server status check endpoint called.")  # Log the status check
    return {"engine": "Julia", "ready": True}

# Define endpoint for running the simulation from the Julia package
@app.post(
    "/run_simulation",
    tags=["Simulations"],
    summary="Create a simulation job",
    description=(
        "Starts a background simulation run and returns a job identifier. "
        "Authentication is required via the api-key header. "
        "Rate limits are not currently enforced server-side."
    ),
    response_model=RunSimulationResponse,
    responses={
        200: {
            "description": "Simulation job accepted and running.",
            "content": {
                "application/json": {
                    "example": {
                        "job_id": 42,
                        "status": "running",
                        "message": "Simulation started. Check status with /simulation_status/{job_id}",
                    }
                }
            },
        },
        401: {
            "model": ErrorResponse,
            "description": "Missing or invalid api-key header.",
            "content": {
                "application/json": {
                    "example": {
                        "error_code": "UNAUTHORIZED",
                        "message": "Invalid API Key",
                        "details": None,
                    }
                }
            },
        },
        422: {
            "model": ErrorResponse,
            "description": "Request validation failed (custom response shape).",
            "content": {
                "application/json": {
                    "example": {
                        "error_code": "VALIDATION_ERROR",
                        "message": "Request validation failed",
                        "details": [
                            {
                                "field": "body.hbar_Omega",
                                "message": "Input should be greater than 0",
                                "type": "greater_than",
                            }
                        ],
                    }
                }
            },
        },
        500: {
            "model": ErrorResponse,
            "description": "Unexpected server or dependency failure.",
            "content": {
                "application/json": {
                    "example": {
                        "error_code": "INTERNAL_ERROR",
                        "message": "Internal server error",
                        "details": None,
                    }
                }
            },
        },
    },
)
async def trigger_simulation(
    config: SimulationParams,
    background_tasks: BackgroundTasks,
    api_key: str | None = Security(api_key_header),
):
    """Start a background simulation and return a job id for polling."""
    
    # Validate the API key
    if not api_key or api_key not in VALID_API_KEYS:
        logger.warning(f"Invalid API Key attempted")  # Log the invalid API key attempt
        raise HTTPException(
            status_code=401,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "Invalid API Key",
                "details": None,
            },
        )
    
    # FastAPI automatically validates 'payload' against the ExportRequest schema here.
    # If invalid, it returns a 422 Unprocessable Entity before touching background tasks.
    
    logger.info(f"Received simulation request with parameters: {config.model_dump()}")  # Log the received parameters
    
    db = SessionLocal()  # Create a new database session instance
    new_sim = Simulation(status="running", result="Data points pending")  # Create a new simulation record with status "running"
    db.add(new_sim)  # Add the new simulation record to the session
    db.commit()  # Commit the session to save the new record in the database
    db.refresh(new_sim)  # Refresh the instance to get the generated ID
    sim_id = new_sim.id  # Get the ID of the newly created simulation record
    db.close()
    
    # Run the background task, passing the validated Pydantic object
    background_tasks.add_task(run_simulation, sim_id, config)
    logger.info(f"Simulation {sim_id} started.")  # Log the simulation start
    
    return {"job_id": sim_id, "status": new_sim.status, "message": "Simulation started. Check status with /simulation_status/{job_id}"}

@app.get(
    "/simulation_status/{sim_id}",
    tags=["Simulations"],
    summary="Get simulation status",
    description=(
        "Returns the current job status and message for a simulation id. "
        "If include_data_points is true, all data points are returned in a single response. "
        "This endpoint does not paginate data_points."
    ),
    response_model=SimulationStatusResponse,
    responses={
        200: {
            "description": "Simulation status found.",
            "content": {
                "application/json": {
                    "examples": {
                        "running": {
                            "summary": "Job still running",
                            "value": {
                                "job_id": 42,
                                "status": "running",
                                "message": "Data points pending",
                            },
                        },
                        "completed": {
                            "summary": "Job completed with data points",
                            "value": {
                                "job_id": 42,
                                "status": "completed",
                                "message": "Successfully finished the job",
                                "data_points": [
                                    {"Energy": 1.0, "Transmission": 0.2}
                                ],
                            },
                        },
                    }
                }
            },
        },
        404: {
            "model": ErrorResponse,
            "description": "Simulation id not found.",
            "content": {
                "application/json": {
                    "example": {
                        "error_code": "NOT_FOUND",
                        "message": "Simulation not found",
                        "details": None,
                    }
                }
            },
        },
        422: {
            "model": ErrorResponse,
            "description": "Path or query validation failed (custom response shape).",
        },
        500: {
            "model": ErrorResponse,
            "description": "Unexpected server or dependency failure.",
        },
    },
)
def get_simulation_status(
    sim_id: int = Path(..., ge=1, description="Simulation job identifier."),
    include_data_points: bool = Query(
        False,
        description="Set true to include all data points in the response.",
    ),
):
    """Return simulation state and optional data points for a job id."""
    logger.info(f"Status check for simulation {sim_id} requested. Include data points: {include_data_points}")  # Log the status check request
    
    db = SessionLocal()
    sim = db.query(Simulation).filter(Simulation.id == sim_id).first()
    if sim is None:
        logger.warning(f"Simulation {sim_id} not found.")  # Log the missing simulation
        raise HTTPException(
            status_code=404,
            detail={
                "error_code": "NOT_FOUND",
                "message": "Simulation not found",
                "details": None,
            },
        )
    
    response = {"job_id": sim_id, "status": sim.status, "message": sim.result}
    if include_data_points:
        points = db.query(DataPoint).filter(DataPoint.simulation_id == sim_id).all()
        response["data_points"] = [{"Energy": p.Energy, "Transmission": p.Transmission} for p in points]
        
        if sim.status == "completed" and not points:
            logger.warning(f"Simulation {sim_id} completed but no data points found.")  # Log the missing data points
            response["message"] += " However, no data points were found for this simulation."
        
        if sim.status == "completed" and points:
            logger.info(f"Returning {len(points)} data points for simulation {sim_id}")  # Log the number of data points returned
    
    db.close()  
    return response


# ScalarDoc Integration for API Documentation
from fastapi.responses import HTMLResponse
from scalar_doc import (
    ScalarColorSchema,
    ScalarConfiguration,
    ScalarDoc,
    ScalarHeader,
    ScalarTheme,
)

# Configure ScalarDoc for enhanced API documentation
docs = ScalarDoc.from_spec(spec=app.openapi_url, mode="url")
docs.set_configuration(ScalarConfiguration(
    schema_style="tree",
    show_sidebar=False,
    show_webhooks=False,
    enable_search=False,
    auth_persist=True,
    expand_authentication=True,
    hide_download_button=True,
    hide_internal=True,
    default_auth="API Key",
))

# Set a custom theme for the ScalarDoc interface
docs.set_theme(
    ScalarTheme(
        color_scheme_light=ScalarColorSchema(
            color_1="#0c2344",
            color_2="#4B6EAF",
            color_3="#FFD43B",
            background_1="#ffffff",
            background_2="#f5f5f5",
            background_3="#e0e0e0",
            color_accent="#306998",
            background_accent="#dbe9f7",
            link_color="#1c6cc7",
            code="#2f4f4f",
        ),
        color_scheme_dark=ScalarColorSchema(
            color_1="#ffffff",
            color_2="#aaaaaa",
            color_3="#FFD43B",
            background_1="#0a0a0a",
            background_2="#111111",
            background_3="#1a1a1a",
            color_accent="#FFD43B",
            background_accent="#ffd43b33",
            link_color="#FFD43B",
            code="#f0f0f0",
        ),
    )
)

# Define a route to serve the ScalarDoc interface at /scalar
@app.get("/scalar", include_in_schema=False)
def scalar_docs():
    docs_html = docs.to_html()
    return HTMLResponse(docs_html)