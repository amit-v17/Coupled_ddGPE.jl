using Coupled_ddGPE
using Test

@testset "TMD_GPE basics" begin
    params = default_config()
    @test isa(params, Parameters)

    derived = nondimensionalize(params)
    @test isa(derived, DerivedParameters)

    tdata = temporal_axes(params, derived)
    @test isa(tdata, TimeData)
    @test tdata.steps == params.no_div * params.t_end

    grid = build_grid(params, derived)
    @test isa(grid, GridData)
    @test grid.L > 0
    @test length(grid.x) == params.N
    @test length(grid.y) == params.N

    pump_spatial = pump_spatial_profile(derived, grid)
    @test isa(pump_spatial, PumpSpatialProfile)
    @test size(pump_spatial.gauss_pump) == (params.N, params.N)

    pump_time = pump_time_profile(params, derived, tdata)
    @test isa(pump_time, PumpTimeProfile)
    @test length(pump_time.pulse) == tdata.steps

    # verify run_simulation() returns a tuple with expected field
    result = run_simulation(params)
    @test haskey(result, :Transmittivity)
    @test haskey(result, :EnergyAxis)
    @test size(result.Transmittivity, 1) == params.N
    @test size(result.EnergyAxis, 1) == length(tdata.E_axis)
end