# Welcome to Coupled_ddGPE.jl

Welcome to the documentation for Coupled_ddGPE.jl — a compact Julia package for simulating the
time-dynamics of coupled, driven, dissipative Gross–Pitaevskii equations (GPE) driven by a gaussian light pump in time and space. This page gives a
concise introduction, a quickstart you can run immediately, and a focused API reference explaining
how the package is organized and how the main functions work together.

## Who this is for

- Researchers and students working with driven-dissipative condensates or nonlinear wave systems.
- Developers who want a small, readable simulation pipeline to adapt for their own models.

## Quickstart

Run these commands from the project root to activate the environment, instantiate dependencies and run a minimal example:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
using Coupled_ddGPE

# Create a default configuration and run the full pipeline
cfg = default_config()
results = run_simulation(cfg)
println(get(results, :Transmittivity))
println(get(results, :EnergyAxis))
```

## High-level concepts

The package splits the simulation into clear stages so you can either call a single convenience
function (`run_simulation`) or manually inspect and run each stage for diagnostics and experimentation:

- Configuration: a `Parameters` object holds physical and numerical settings (deafults are created by `default_config()`).
- Nondimensionalization: `nondimensionalize` computes `DerivedParameters` used internally.
- Temporal and spatial discretization: `temporal_axes` and `build_grid` create `TimeData` and `GridData` used by solvers.
- Pump profiles: `pump_time_profile` and `pump_spatial_profile` return pump envelopes used as sources.
- Propagation & spectra: `propagate_pump_spectrum` runs the core propagation and returns spectral / transmission data.

Each stage returns a lightweight composite type (e.g., `DerivedParameters`, `GridData`, `TimeData`) containing
arrays and scalar metadata you can inspect or save for later analysis.

## API Reference



### `default_config()`

Creates and returns a `Parameters` object populated with sensible default physical and numerical
settings (grid sizes, time window, pump parameters, coupling constants, dissipation rates, etc.).

Usage notes:
- Call this to start a simulation. Modify fields on the returned object to change the experiment.

### `nondimensionalize(config)`

Input: `config::Parameters` — physical parameters in SI or user units.

Output: `DerivedParameters` — scaled parameters used by numeric routines.

What it does: converts energies, lengths and times to nondimensional units appropriate for the solver,
computes characteristic scales, and derives any auxiliary constants used in the equations.

When to call: this is called by `run`, but you can call it directly if you want to inspect derived scales.

### `temporal_axes(config, derived)`

Input: `config`, `derived` — the configuration and derived parameters.

Output: `TimeData` — contains time array, time-step `dt`, number of steps `nt`, and any windowing data.

What it does: builds the temporal grid used by propagation routines, taking care of sampling and
Fourier-related details if the solver uses spectral methods.

### `build_grid(config, derived)`

Input: `config`, `derived`.

Output: `GridData` — contains spatial axes, spacing `dx`, `dy` (if 2D), grid sizes, and FFT-related helpers.

What it does: constructs spatial discretization used for field variables and for spatial operations such
as convolution or spectral derivatives.

### `pump_time_profile(config, derived, tdata)`

Input: `config`, `derived`, `tdata::TimeData`.

Output: `PumpTimeProfile` — typically an array of complex or real amplitudes sampled on the time axis.

What it does: builds the time-dependent envelope of the external pump (pulse shape, chirp, duration,
and frequency content). Use this to test different driving scenarios.

### `pump_spatial_profile(derived, grid)`

Input: `derived`, `grid::GridData`.

Output: `PumpSpatialProfile` — spatial envelope matching the simulation grid.

What it does: constructs pump amplitude distribution across the spatial grid (Gaussian beams, plane waves,
or user-specified masks).

### `propagate_pump_spectrum(config, derived, grid, pump_spatial, tdata, pump_time)`

Input: full set of prepared objects: `config`, `derived`, `grid`, `pump_spatial`, `tdata`, `pump_time`.

Output: `Results` (or similar composite) containing spectra, transmittivity, and any diagnostic time-series.

What it does: this is the core numerical routine. It advances the coupled GPEs in time (or frequency,
depending on implementation), applies the pump source terms, and computes observables such as transmitted
intensity, reflection, or spectral response. Internally it will use FFT-based spectral derivatives and
the `FFTW` dependency where appropriate.

Usage notes:
- The routine may be parameter-sensitive: choose time-step and grid resolution to satisfy stability and
	accuracy for your problem.
- For long simulations, consider saving intermediate snapshots rather than holding everything in memory.

### `run_simulation(config)`

Input: `config::Parameters`.

Output: `Results` — a convenience composite that bundles outputs from the pipeline (derived parameters,
time/grid data, pump profiles, and computed spectra/transmittivity).

What it does: calls `nondimensionalize`, `temporal_axes`, `build_grid`, `pump_time_profile`,
`pump_spatial_profile`, and `propagate_pump_spectrum` in sequence and returns the collected outputs.

When to use: use `run` for standard experiments. If you need fine-grained control or intermediate
diagnostics, call the stages manually as shown in the Quickstart section.

## Contributing & examples

If you'd like runnable examples in the docs, I can add an `examples/` folder and a simple script that
reproduces common figures or a basic transmittivity scan. Also happy to extend the API reference with
type signatures and example return-object fields if you want more precise, machine-readable docs.
