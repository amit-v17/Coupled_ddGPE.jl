# Coupled_ddGPE

Coupled_ddGPE is a small Julia package for simulating the time-dynamics of coupled, driven, dissipative
Gross–Pitaevskii equations (GPE). It provides a clear configuration model, helpers to build spatial and
temporal grids, pump profiles, and routines to run an end-to-end simulation that returns physically
meaningful output such as transmittivity spectra.

## Quick overview

- **Purpose:** Simulate pump-driven, coupled GPE systems and compute spectral/transmission properties.
- **Language:** Julia
- **Package name:** Coupled_ddGPE (see [Project.toml](Project.toml) for metadata and dependencies)

## Features

- Human-readable configuration with sensible defaults.
- Utilities to nondimensionalize physical parameters.
- Grid and time-axis builders for spatial/temporal discretization.
- Pump time and spatial profile generators.
- Propagation routines to compute spectra and transmittivity.
- Single-call `run_simulation` for an end-to-end experiment.

## Installation

If you want to use the package locally from this repository, activate the project and instantiate:

```julia
using Pkg
Pkg.activate(".")   # run from repository root
Pkg.instantiate()
```

To use the package from another project, `dev` it by path:

```julia
Pkg.develop(path="/path/to/Coupled_ddGPE")
```

## Quickstart example

```julia
using Coupled_ddGPE

# Create a configuration (uses sensible physical defaults)
cfg = default_config()

# Run the full simulation pipeline and get a results object
results = run(cfg)

# Example: print transmittivity (if present in results)
println(get(results, :Transmittivity, "Transmittivity not available"))
```

The `run` function executes the common sequence of steps (nondimensionalize, build grids, generate pump
profiles, propagate and collect outputs). If you prefer to call stages manually, see the API below.

## Public API (high-level)

The following functions are provided by the package. See the source files in `src/` for details and
argument descriptions.

- `default_config()` — returns a `Parameters` object populated with default physical and numerical settings.
- `nondimensionalize(config)` — converts physical parameters into nondimensional units and returns `DerivedParameters`.
- `temporal_axes(config, derived)` — builds and returns `TimeData` (time array, dt, number of points).
- `build_grid(config, derived)` — constructs `GridData` (spatial axes, spacing, sizes).
- `pump_time_profile(config, derived, tdata)` — returns the time-dependent pump envelope used in simulations.
- `pump_spatial_profile(derived, grid)` — returns the spatial pump profile (envelope across the grid).
- `propagate_pump_spectrum(config, derived, grid, pump_spatial, tdata, pump_time)` — performs propagation and computes spectra/transmittivity.
- `run(config)` — convenience wrapper that runs the full pipeline and returns a `Results` object.

Return objects are plain Julia composite types; inspect fields in the source code to see what is available.

## Files and modules

- `src/Coupled_ddGPE.jl` — package entry point; re-exports public functions and defines `run_simulation`.
- `src/config.jl` — configuration types, `default_config()` and parameter parsing.
- `src/grid.jl` — grid and axis builders used for spatial discretization.
- `src/pump.jl` — pump time and spatial profile generators.
- `src/simulation.jl` — core propagation routines and spectrum calculation.

Refer to these files when you need to extend or adapt the internals.

## Example: manual pipeline

```julia
using Coupled_ddGPE

cfg = default_config()
derived = nondimensionalize(cfg)
tdata = temporal_axes(cfg, derived)
grid = build_grid(cfg, derived)
pump_t = pump_time_profile(cfg, derived, tdata)
pump_spatial = pump_spatial_profile(derived, grid)
result = propagate_pump_spectrum(cfg, derived, grid, pump_spatial, tdata, pump_t)

println("Finished simulation")
```

## Testing

Run the package test suite with the standard Pkg test command:

```julia
using Pkg
Pkg.test()
```

## REST API Quickstart

This repository also includes a FastAPI service in [api/app.py](api/app.py) that lets you run simulations over HTTP.

Start the API server from the repository root:

```bash
uvicorn api.app:app --reload
```

OpenAPI docs:

- Swagger UI: `/docs`
- OpenAPI JSON: `/openapi.json`

Authentication:

- Protected endpoints require the `api-key` header.
- Example:

```bash
curl -X POST "http://localhost:8000/run_simulation" \
	-H "Content-Type: application/json" \
	-H "api-key: YOUR_API_KEY" \
	-d '{}'
```

Main workflow:

1. POST `/run_simulation` to create a job.
2. Read `job_id` from the response.
3. GET `/simulation_status/{job_id}` until status is `completed` or `failed`.
4. Add `?include_data_points=true` to fetch computed points.

Error behavior:

- The API uses a custom 422 validation response shape (not default FastAPI validation payloads).
- 401 means missing or invalid API key.
- 404 means unknown simulation id.

Rate limits and pagination:

- No server-side rate limiting is currently enforced.
- `data_points` are not paginated; all points are returned when requested.

For full endpoint details and examples, see [docs/api-reference.md](docs/api-reference.md).

## Contributing

Contributions are welcome. If you plan to add features or change defaults, please:

1. Open an issue describing the change you intend to make.
2. Add tests covering new behaviour (see `test/runtests.jl`).
3. Submit a pull request with a clear description of the change.

## Notes

- The package depends on `FFTW` and the standard `Test` package (see [Project.toml](Project.toml)).
- Project metadata is available in [Project.toml](Project.toml).

If you'd like, I can also add a minimal example script in `examples/` and expand the test-suite to
cover common configurations.

---

If anything in this README is unclear or you'd like a different organization (e.g., API reference
separate from the quickstart), tell me which format you prefer and I'll revise the document.
