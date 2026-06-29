# API Reference

The API below documents the main public functions and how they fit into the simulation pipeline. For the full implementation and type definitions, see the corresponding files in `src/`.

```@docs
Parameters
DerivedParameters
default_config
nondimensionalize
TimeData
temporal_axes
GridData
build_grid
PumpSpatialProfile
pump_spatial_profile
pump_amplitude
PumpTimeProfile
pump_time_profile
propagate_pump_spectrum
run_simulation
```

## REST API Reference

For the FastAPI HTTP interface used by external clients, see [docs/src/api-reference.md](./api-reference.md).
