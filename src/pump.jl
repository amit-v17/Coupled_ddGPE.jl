"""
Construct the Gaussian spatial pump profile for the driven GPE.

# Arguments
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.
- `grid::GridData`: spatial and momentum grid returned by `build_grid`.

# Returns
`PumpSpatialProfile` with fields:
- `gauss_pump::Array{Float64,2}`: Gaussian pump amplitude on the spatial grid.
- `gauss_intensity::Array{Float64,2}`: Pump intensity |pump|^2 on the spatial grid.
"""
struct PumpSpatialProfile
    gauss_pump::Array{Float64,2}
    gauss_intensity::Array{Float64,2}
end

"""
Construct the spatial pump intensity profile on the simulation grid.

# Arguments
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.
- `grid::GridData`: spatial and momentum grid returned by `build_grid`.

# Returns
A `PumpSpatialProfile` containing the pump amplitude and intensity on the spatial grid.
"""
function pump_spatial_profile(derived::DerivedParameters, grid::GridData)::PumpSpatialProfile

    # Construct the Gaussian pump profile on the spatial grid
    gauss_pump = exp.(-((grid.xm.^2)./(2*derived.pump_sigma_x^2) .+ ((grid.ym .- derived.pump_y0).^2)./(2*derived.pump_sigma_y^2)))
    gauss_intensity = abs.(gauss_pump).^2

    return PumpSpatialProfile(
        gauss_pump,
        gauss_intensity,
    )
end

"""
Compute the dimensionless pump amplitude corresponding to the configured pulse energy.

# Arguments
- `config::Parameters`: simulation configuration (physical units).
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.

# Returns
Scalar pump amplitude in nondimensional simulation units (`Float64`).
"""
function pump_amplitude(config::Parameters, derived::DerivedParameters)::Float64
    E_pulse = config.E_pulse # Joules
    return sqrt(((config.hbar_gamma_c/4)*1.6022e-22)/(config.hbar)) * (config.hbar/(config.hbar_gamma_c*1.6022e-22)) * derived.r_0 *
           sqrt(E_pulse / ((sqrt(π)*derived.sigma_t) * (sqrt(π)*config.sigma_x) * (sqrt(π)*config.sigma_y) *
                  (config.hbar_omega_pump*1.6022e-22)))
end

"""
Generate the pump pulse time profile and its sampled / frequency representations.

# Arguments
- `config::Parameters`: simulation configuration (physical units).
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.
- `tdata::TimeData`: evolution time axes and sampling metadata.

# Returns
`PumpTimeProfile` with fields:
- `pulse::Vector{Float64}`: full time-domain pulse evaluated on `t`.
- `pulse_sample::Vector{Float64}`: downsampled pulse used for FFT.
- `pulse_freq::Vector{Float64}`: magnitude of the pulse spectrum (abs of IFFT-shifted sample).
- `t_sample::Vector{Float64}`: sampled time axis.
- `dt_sample::Float64`: sampled time step.
- `No_points::Int`: number of sampled points.
"""
struct PumpTimeProfile
    pulse::Vector{Float64}
    pulse_sample::Vector{Float64}
    pulse_freq::Vector{Float64}
    t_sample::Vector{Float64}
    dt_sample::Float64
    No_points::Int
end

"""
Compute the pump pulse time envelope and its sampled frequency representation.

# Arguments
- `config::Parameters`: simulation configuration.
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.
- `tdata::TimeData`: time-domain axes and sample metadata.

# Returns
A `PumpTimeProfile` containing the pulse waveform, sampled pulse, and computed spectrum.
"""
function pump_time_profile(config::Parameters, derived::DerivedParameters, tdata::TimeData)::PumpTimeProfile
    # Unpack time-domain data from TimeData
    t = tdata.t
    dt = tdata.dt
    steps = tdata.steps
    init = tdata.init
    dt_sample = tdata.dt_sample
    t_sample = tdata.t_sample
    No_points = tdata.No_points

    pulse = exp.(-1/(2 * derived.pulse_width^2) .* ((t .- ((last(t)+dt) * config.center_pulse)).^2))
    pulse_sample = zeros(Float64, No_points)
    pulse_sample[1:config.samples] = pulse[1:init:steps]
    pulse_freq = abs.(fftshift(ifft(ifftshift(pulse_sample))))

    return PumpTimeProfile(
        pulse,
        pulse_sample,
        pulse_freq,
        t_sample,
        dt_sample,
        No_points,
    )
end
