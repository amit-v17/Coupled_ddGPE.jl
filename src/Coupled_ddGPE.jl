module Coupled_ddGPE

using FFTW

include("config.jl")
include("grid.jl")
include("pump.jl")
include("simulation.jl")

export Parameters, DerivedParameters, default_config, nondimensionalize
export TimeData, temporal_axes
export GridData, build_grid
export PumpSpatialProfile, pump_spatial_profile, pump_amplitude, PumpTimeProfile, pump_time_profile
export propagate_pump_spectrum, run_simulation

end
