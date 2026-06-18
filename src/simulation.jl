"""
Propagate pump fields through the driven-dissipative GPE and compute input/output spectra.

# Arguments
- `config::Parameters`: simulation configuration and numeric constants.
- `derived`: nondimensionalized parameters (usually a `NamedTuple` or `Dict`).
- `grid`: spatial grid metadata (object with fields like `xm`, `ym`, `kxm`, `kym`).
- `spat`: spatially varying fields (losses, detunings, ...).
- `pump_spatial`: pump profile (`PumpSpatialProfile`) containing `gauss_pump` and `gauss_intensity`.
- `tdata`: temporal axes and sampling metadata (must provide `dt`, `steps`, `init`, `No_points`).
- `pump_time`: time-domain pulse data returned from `pump_time_profile` (`PumpTimeProfile`).
- `config.g`: interaction strength.
- `config.g_s`: saturation interaction strength.

# Returns
- `Transmittivity::Matrix{Float64}` — the transmittivity values for a given pulse.
"""
function propagate_pump_spectrum(config::Parameters, 
    derived::DerivedParameters, 
    grid::GridData, 
    pump_spatial::PumpSpatialProfile, 
    tdata::TimeData, 
    pump_time::PumpTimeProfile) :: Matrix{Float64}

    # Initialize wavefunctions, pump amplitude
    wf_e = complex.(config.seed .* exp.(-((grid.xm.^2 .+ grid.ym.^2)/(derived.pump_sigma_x^2))))
    wf_p = complex.(config.seed .* exp.(-((grid.xm.^2 .+ grid.ym.^2)/(derived.pump_sigma_x^2))))

    psi_p = zeros(ComplexF64, config.N, tdata.No_points)
    psi_p[:, 1] = wf_p[:, div(config.N, 2) + 1] # Store initial wavefunction at the center of the grid
    amp = pump_amplitude(config, derived)

    # Precompute kinetic and potential evolution factors for the exciton and photon fields without the non-linear terms (assuming a split-step method)
    KE_e = config.A * 0.5 .* (grid.kxm.^2 .+ grid.kym.^2)
    exp_KE_e = exp.(-1im * KE_e * tdata.dt)
    KE_p = 0.5 .* (grid.kxm.^2 .+ grid.kym.^2)
    exp_KE_p = exp.(-1im * KE_p * tdata.dt)
    PE_p = -0.5 .* (1im) .+ (derived.omega_x .- derived.omega_0) .+ derived.Delta
    exp_PE_p = exp.(-1im * PE_p * tdata.dt)

    g = config.g
    g_s = config.g_s

    sample_count = 1
    for i in 1:tdata.steps-1

        # Compute the potential evolution factors of the exciton based on the current wavefunction amplitudes
        PE_e = -0.5 .* derived.gamma_x .* (1im) .+ (derived.omega_x .- derived.omega_0) .+ (g .* abs.(wf_e).^2) .- (g_s .* conj.(wf_p) .* wf_e)
        exp_PE_e = exp.(-1im * PE_e * tdata.dt)

        wf_e = ifft(exp_KE_e .* fft(wf_e))
        wf_p = ifft(exp_KE_p .* fft(wf_p))
        wf_e .= exp_PE_e .* wf_e
        wf_p .= exp_PE_p .* wf_p

        delta = (derived.Omega .- 2*g_s .* abs.(wf_e).^2) .* (derived.Omega .- g_s .* abs.(wf_e).^2)
        delta = sqrt.(Complex.(delta))

        m11 = cos.(tdata.dt .* delta)
        m12 = (1im .* (2*g_s .* abs.(wf_e).^2 .- derived.Omega) .* sin.(tdata.dt .* delta)) ./ delta
        m21 = (1im .* (g_s .* abs.(wf_e).^2 .- derived.Omega) .* sin.(tdata.dt .* delta)) ./ delta

        tmp_e = m11 .* wf_e .+ m12 .* wf_p
        tmp_p = m11 .* wf_p .+ m21 .* wf_e
        wf_e .= tmp_e
        wf_p .= tmp_p .+ tdata.dt .* pump_time.pulse[i] .* pump_spatial.gauss_pump .* amp

        if mod(i, tdata.init) == 0
            sample_count += 1
            psi_p[:, sample_count] = wf_p[:, div(config.N, 2) + 1] # Store the wavefunction at the center of the grid
        end
    end

    #------ Calculation of Transmission spectrum

    # Calculation of Input Spectrum of the Pump along the x-direction at the center of the grid
    spectrum_pump = Array{Float64,2}(undef, config.N, tdata.No_points)
    for i=1:config.N
        spectrum_pump[i,:] = (abs.(pump_time.pulse_freq.* pump_spatial.gauss_pump[i, div(config.N, 2) + 1].*amp)).^2
    end
    A_in_2 = copy(spectrum_pump)

    # Calculation of Spectrum of Photons captured along the x-direction 
    spectrum_p = Array{Float64,2}(undef, config.N, tdata.No_points)
    for j in 1:config.N
        spectrum_p[j, :] = abs.(fftshift(ifft(ifftshift(psi_p[j, :])))).^2
    end
    A_out_2 = copy(spectrum_p)

    Transmittivity = A_out_2 ./ A_in_2

    return Transmittivity
end

"""
Run the full driven dissipative GPE simulation.

# Arguments
- `config::Parameters`: optional custom configuration. Defaults to `default_config()`.

# Returns
A named tuple containing `lsq_error_spectrum` and `lsq_error_spatial`.
"""
function run_simulation(config::Parameters = default_config())
    println("=" ^ 60)
    println("Starting TMD-GPE Simulation")
    println("=" ^ 60)

    println("\nComputing dimensionless parameters")
    derived = nondimensionalize(config)
    println("✓ Derived parameters computed")
    
    println("Creating the time and frequency axes")
    tdata = temporal_axes(config, derived)
    println("✓ Temporal axes created ($(tdata.steps) time steps)")
    
    println("Computing pump time profile")
    pump_time = pump_time_profile(config, derived, tdata)
    println("✓ Pump time profile computed")
    
    println("Building spatial grid")
    grid = build_grid(config, derived)
    println("✓ Spatial grid built ($(config.N) points)")
    
    println("Computing pump spatial profile")
    pump_spatial = pump_spatial_profile(derived, grid)
    println("✓ Pump spatial profile computed")

    println("Computing transmittivity spectrum")
    Transmittivity = propagate_pump_spectrum(config, derived, grid, pump_spatial, tdata, pump_time)
    println("✓ Transmittivity spectrum computed")

    println("\n" * "=" ^ 60)
    println("Simulation completed successfully!")
    println("=" ^ 60)

    return (Transmittivity=Transmittivity, EnergyAxis=tdata.E_axis)
end