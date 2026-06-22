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

## Contributing & examples

If you'd like runnable examples in the docs, I can add an `examples/` folder and a simple script that
reproduces common figures or a basic transmittivity scan. Also happy to extend the API reference with
type signatures and example return-object fields if you want more precise, machine-readable docs.
