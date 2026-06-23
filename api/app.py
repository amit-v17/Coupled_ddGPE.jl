from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel, Field
from math import pi
import numpy as np
import subprocess
import json
import asyncio

app = FastAPI()

# Define request model for simulation parameters
class SimulationParams(BaseModel):
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

# Check status endpoint to verify that the API is running and the Julia engine is ready
@app.get("/status")
def get_status():
    return {"engine": "Julia", "ready": True}

# Define endpoint for running the simulation from the Julia package
@app.post("/simulate")
async def run_simulation(params: SimulationParams):
    
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

    result = await asyncio.create_subprocess_shell(
        multiline_command,
        stdout=asyncio.subprocess.PIPE
    )
    stdout = await result.communicate()
    
    if result.returncode != 0:
        raise HTTPException(status_code=500, detail="Julia simulation failed to run")
    try:
        output = json.loads(stdout) # Julia prints JSON; Python parses it
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Julia didn't return valid JSON output")

    return output
