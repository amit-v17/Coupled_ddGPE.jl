using Pkg
Pkg.activate(".")
Pkg.instantiate()

using JSON3
using Coupled_ddGPE

function main()
    params = Parameters(
        hbar_Omega=parse(Float64, ARGS[1]),
        hbar_gamma_c=parse(Float64, ARGS[2]),
        hbar_gamma_x=parse(Float64, ARGS[3]),
        hbar_omega_x=parse(Float64, ARGS[4]),
        hbar_detuning=parse(Float64, ARGS[5]),
        m_c=parse(Float64, ARGS[6]),
        A=parse(Float64, ARGS[7]),
        hbar=parse(Float64, ARGS[8]),
        sigma_x=parse(Float64, ARGS[9]),
        sigma_y=parse(Float64, ARGS[10]),
        y0=parse(Float64, ARGS[11]),
        hbar_sigma_e=parse(Float64, ARGS[12]),
        hbar_omega_pump=parse(Float64, ARGS[13]),
        g=parse(Float64, ARGS[14]),
        g_s=parse(Float64, ARGS[15]),
        E_pulse=parse(Float64, ARGS[16]),
        no_div=parse(Int, ARGS[17]),
        t_end=parse(Int, ARGS[18]),
        samples=parse(Int, ARGS[19]),
        size_sample=parse(Int, ARGS[20]),
        center_pulse=parse(Float64, ARGS[21]),
        spot_size=parse(Float64, ARGS[22]),
        N=parse(Int, ARGS[23]),
        seed=parse(Float64, ARGS[24])
    )

    result = nothing

    # Run the simulation and stop the output from being printed to stdout
    redirect_stdout(devnull) do
        result = run_simulation(params)
    end

    # Convert the data array result to a dictionary for JSON serialization
    data_array = Dict(pairs(result))

    # Prepare the data points from the data array result for JSON output
    data_points = Dict(
    "data_points" => [Dict("Energy" => xi, "Transmission" => yi) for (xi, yi) in zip(data_array[:EnergyAxis], data_array[:TransmissionSpectrum])]
    )

    JSON3.write(stdout, data_points) # Output the data points as JSON to stdout

    return nothing
end

main()