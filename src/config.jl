"""
Simulation configuration parameters in physical units.

Fields
- `hbar_Omega`: Rabi frequency in meV.
- `hbar_gamma_c`: photonic dissipation in meV.
- `hbar_gamma_x`: excitonic dissipation in meV.
- `hbar_omega_x`: exciton energy in meV.
- `m_c`: effective mass of the cavity photon in kg.
- `A`: mass ratio of cavity photon to exciton.
- `hbar`: reduced Planck constant in J·s.
- `sigma_x`, `sigma_y`: pump spot sizes in meters.
- `y0`: pump center position along y in meters.
- `hbar_sigma_e`: pump linewidth in meV.
- `hbar_omega_pump`: pump photon energy in meV.
- `g`, `g_s`: interaction and saturation strengths.
- `E_pulse`: pump pulse energy in Joules.
- `no_div`: time subdivision count for temporal evolution.
- `t_end`: simulation length in units of pulse width.
- `samples`: number of sampling points for the pump profile.
- `size_sample`: factor used to extend the sampled pulse frequency grid.
- `center_pulse`: normalized pulse center time.
- `spot_size`: pump spot-size multiplier used when building the grid.
- `N`: number of spatial grid points (power of 2 for FFT).
- `seed`: initial wavefunction amplitude.
"""
Base.@kwdef struct Parameters
    hbar_Omega::Float64 = 11.6 # meV
    hbar_gamma_c::Float64 = 5.6 # meV
    hbar_gamma_x::Float64 = 27.6 # meV
    hbar_omega_x::Float64 = 1645.4 # meV
    hbar_detuning::Float64 = -1.0 # meV
    m_c::Float64 = 1e-4 * 9.10938356e-31 # kg
    A::Float64 = 1e-4 # Mass Ratio of cavity photon to exciton
    hbar::Float64 = 6.62607004e-34/(2π) # J·s
    sigma_x::Float64 = 3.57e-6 # m
    sigma_y::Float64 = 4.7e-6 # m
    y0::Float64 = -3.8e-6 # m
    hbar_sigma_e::Float64 = 9.9 # meV
    hbar_omega_pump::Float64 = 1645.8 # meV
    g::Float64=3e-4
    g_s::Float64=5e-4
    E_pulse::Float64=1.18e-12 # Joules
    no_div::Int = 100
    t_end::Int = 80 # times the pulse_width
    samples::Int = 500
    size_sample::Int = 20 # times the samples numbers
    center_pulse::Float64 = 1/4
    spot_size::Float64 = 5  # times the pump_σ
    N::Int = 2^7 # Number of spatial grid points (must be a power of 2 for FFT)
    seed::Float64 = 1e-36 # Initial wavefunction Amplitude
end

"""
Nondimensionalized simulation parameters derived from physical constants.

Fields
- `r_0`: length scale in meters.
- `sigma_t`: time scale in seconds.
- `Omega`: Rabi frequency in dimensionless units.
- `omega_x`: exciton energy in dimensionless units.
- `Delta`: detuning in dimensionless units.
- `gamma_x`: excitonic dissipation in dimensionless units.
- `omega_0`: pump photon energy in dimensionless units.
- `sigma_e`: pump linewidth in dimensionless units.
- `pulse_width`: pulse width in dimensionless frequency units.
- `pump_sigma_x`, `pump_sigma_y`: pump spot sizes in dimensionless units.
- `pump_y0`: pump center position along y in dimensionless units.
"""
Base.@kwdef struct DerivedParameters
    r_0::Float64
    sigma_t::Float64
    Omega::Float64
    omega_x::Float64
    Delta::Float64
    gamma_x::Float64
    omega_0::Float64
    sigma_e::Float64
    pulse_width::Float64
    pump_sigma_x::Float64
    pump_sigma_y::Float64
    pump_y0::Float64
end

"""
Convert physical [`Parameters`](@ref) into nondimensionalized simulation parameters.

# Arguments
- `config::Parameters`: A [`Parameters`](@ref) object containing physical simulation constants, Gaussian pump settings and numerical parameters.

# Returns
A [`DerivedParameters`](@ref) object with nondimensionalized length, time, and energy scales.
"""
function nondimensionalize(config::Parameters)::DerivedParameters
    r_0 = config.hbar * sqrt(1/(config.m_c * config.hbar_gamma_c * 1.6022e-22)) # Length scale
    sigma_t = 2/((config.hbar_sigma_e * 1.6022e-22)/(config.hbar)) # Time scale
    Omega = config.hbar_Omega / config.hbar_gamma_c
    omega_x = config.hbar_omega_x / config.hbar_gamma_c
    Delta = config.hbar_detuning / config.hbar_gamma_c
    gamma_x = config.hbar_gamma_x / config.hbar_gamma_c
    omega_0 = config.hbar_omega_pump / config.hbar_gamma_c
    sigma_e = config.hbar_sigma_e / config.hbar_gamma_c
    pulse_width = 1/(π * sigma_e) # in dimensionless frequency
    pump_sigma_x = config.sigma_x / r_0
    pump_sigma_y = config.sigma_y / r_0
    pump_y0 = config.y0 / r_0

    return DerivedParameters(
        r_0=r_0,
        sigma_t=sigma_t,
        Omega=Omega,
        omega_x=omega_x,
        Delta=Delta,
        gamma_x=gamma_x,
        omega_0=omega_0,
        sigma_e=sigma_e,
        pulse_width=pulse_width,
        pump_sigma_x=pump_sigma_x,
        pump_sigma_y=pump_sigma_y,
        pump_y0=pump_y0,
    )
end

"""
Creates and returns a [`Parameters`](@ref) object populated with sensible default physical and numerical
settings (grid sizes, time window, pump parameters, coupling constants, dissipation rates, etc.).

Usage notes:
- Call this to start a simulation. Modify fields on the returned object to change the experiment.
"""
function default_config()::Parameters
    return Parameters()
end