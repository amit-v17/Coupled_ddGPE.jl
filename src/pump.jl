"""
Construct the Gaussian spatial pump profile object for the driven-dissipative GPE.

Fields:
- `gauss_pump`: 2D array of the Gaussian pump amplitude on the spatial grid.
- `gauss_intensity`: 2D array of the Gaussian pump intensity on the spatial grid.
"""
struct PumpSpatialProfile
    gauss_pump::Array{Float64,2}
    gauss_intensity::Array{Float64,2}
end

"""
Construct the spatial pump intensity profile on the simulation grid. Constructs pump amplitude distribution across the spatial grid for a Gaussian pump beam, based on the configured pump waist and center position. The resulting profile is used to drive the system in the simulation.

# Arguments
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.
- `grid::GridData`: spatial and momentum grid returned by `build_grid`.

# Returns
A [`PumpSpatialProfile`](@ref) containing the pump amplitude and intensity on the spatial grid.
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
Generate the pump pulse time profile object and its sampled / frequency representations.

Fields:
- `pulse`: full time-domain pump pulse envelope.
- `pulse_sample`: sampled time-domain pump pulse envelope.
- `pulse_freq`: frequency-domain representation of the sampled pump pulse.
- `t_sample`: sampled time axis vector in dimensionless units.
- `dt_sample`: sampling time step in dimensionless units.
- `No_points`: number of sampling points.
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
Compute the pump pulse time envelope and its sampled frequency representation. Builds the time-dependent envelope of the external pump (pulse shape, chirp, duration,
and frequency content). Use this to test different driving scenarios.

# Arguments
- `config::Parameters`: simulation configuration.
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.
- `tdata::TimeData`: time-domain axes and sample metadata.

# Returns
A [`PumpTimeProfile`](@ref) containing the pulse waveform, sampled pulse, and computed spectrum.
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
