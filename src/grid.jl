"""
Build time and frequency axes structure for the simulation. 

Fields:
- `dt`: time step in dimensionless units.
- `steps`: total number of time steps.
- `t`: time axis vector in dimensionless units.
- `init`: initial index for sampling.
- `dt_sample`: sampling time step in dimensionless units.
- `t_sample`: sampling time axis vector in dimensionless units.
- `No_points`: number of sampling points.
- `f`: frequency axis vector in dimensionless units.
- `E_axis`: energy axis vector in dimensional units (meV).
"""
struct TimeData
    dt::Float64
    steps::Int
    t::Vector{Float64}
    init::Int
    dt_sample::Float64
    t_sample::Vector{Float64}
    No_points::Int
    f::Vector{Float64}
    E_axis::Vector{Float64}
end

"""
Build time and frequency axes for the simulation taking care of sampling and Fourier-related details for the pseudo-spectral solver.

# Arguments
- `config::Parameters`: simulation configuration.
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.

# Returns
A [`TimeData`](@ref) object containing time, sample, frequency, and energy axes.
"""
function temporal_axes(config::Parameters, derived::DerivedParameters)::TimeData

    # Evolution Time Axis
    dt = floor((derived.pulse_width / config.no_div) * 1e3) / 1e3
    steps = config.no_div * config.t_end
    t = collect(range(0, length=steps, step=dt))

    # Sampling Time Axis
    init = Int(floor(steps / config.samples))
    dt_sample = init * dt
    t_sample = collect(range(0, length=config.size_sample * config.samples, step=dt_sample))
    t_sample_end = last(t_sample) + dt_sample
    No_points = length(t_sample)

    # Frequency Axis
    f = collect(range(-1/(2*dt_sample), step=1/t_sample_end, length=config.size_sample * config.samples))

    # Energy Axis in Dimensional Parameters
    E_axis = ((2π .* f) .* config.hbar_gamma_c .+ config.hbar_omega_pump)

    # lower_E = findlast(x -> x < 1618, E_axis)
    # upper_E = findfirst(x -> x > 1674, E_axis)
    # println(lower, " ", upper)

    return TimeData(
        dt,
        steps,
        t,
        init,
        dt_sample,
        t_sample,
        No_points,
        f,
        E_axis,
    )
end

"""
Build the spatial grid and momentum grid used in the simulation.

Fields:
- `L`: length of the grid in dimensionless units.
- `dx`: spatial step size in x direction in dimensionless units.
- `dy`: spatial step size in y direction in dimensionless units.
- `x`: spatial coordinates in x direction in dimensionless units.
- `y`: spatial coordinates in y direction in dimensionless units.
- `xm`: 2D meshgrid of x coordinates in dimensionless units.
- `ym`: 2D meshgrid of y coordinates in dimensionless units.
- `kx`: momentum coordinates in x direction in dimensionless units.
- `ky`: momentum coordinates in y direction in dimensionless units.
- `kxm`: 2D meshgrid of momentum coordinates in x direction in dimensionless units.
- `kym`: 2D meshgrid of momentum coordinates in y direction in dimensionless units.
"""
struct GridData
    L::Float64
    dx::Float64
    dy::Float64
    x::Vector{Float64}
    y::Vector{Float64}
    xm::Array{Float64,2}
    ym::Array{Float64,2}
    kx::Vector{Float64}
    ky::Vector{Float64}
    kxm::Array{Float64,2}
    kym::Array{Float64,2}
end

"""
Build the spatial and momentum grids for the simulation domain.

# Arguments
- `config::Parameters`: simulation configuration.
- `derived::DerivedParameters`: nondimensionalized parameters returned by `nondimensionalize`.

# Returns
A [`GridData`](@ref) object containing spatial coordinates, momentum coordinates, and grid spacing.
"""
function build_grid(config::Parameters, derived::DerivedParameters)::GridData
    L = ceil((maximum((derived.pump_sigma_x, derived.pump_sigma_y)) * config.spot_size)/100) * 100 # Appropriate Length of Grid dependent on spot size of pump

    # Grid step sizes
    dx = L / config.N
    dy = L / config.N

    # Spatial coordinates
    n = collect(-config.N/2:config.N/2-1)
    x = n .* dx
    y = n .* dy

    # Momentum coordinates
    kx = fftshift(2π .* n ./ L)
    ky = fftshift(2π .* n ./ L)
    xm = repeat(transpose(x), config.N, 1)
    ym = repeat(y, 1, config.N)
    kxm = repeat(transpose(kx), config.N, 1)
    kym = repeat(ky, 1, config.N)

    return GridData(
        L,
        dx,
        dy,
        x,
        y,
        xm,
        ym,
        kx,
        ky,
        kxm,
        kym,
    )
end

