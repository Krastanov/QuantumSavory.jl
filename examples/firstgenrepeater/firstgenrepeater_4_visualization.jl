include("firstgenrepeater_setup.jl")

##
# Demo visualizations of the performance of the network
##
sizes = [2,3,4,3,2]        # Number of qubits in each register
T2 = 100.0                  # T2 dephasing time of all qubits
F = 0.97                    # Fidelity of the raw Bell pairs
entangler_wait_time = 0.1  # How long to wait if all qubits are busy before retring entangling
entangler_busy_time = 1.0  # How long it takes to establish a newly entangled pair
swapper_wait_time = 0.1    # How long to wait if all qubits are unavailable for swapping
swapper_busy_time = 0.15   # How long it takes to swap two qubits
purifier_wait_time = 0.15  # How long to wait if there are no pairs to be purified
purifier_busy_time = 0.2   # How long the purification circuit takes to execute

sim, mgraph = simulation_setup(sizes, T2)

for (;src, dst) in edges(mgraph)
    @process entangler(sim, mgraph, src, dst, F, entangler_wait_time, entangler_busy_time)
end
for node in vertices(mgraph)
    @process swapper(sim, mgraph, node, swapper_wait_time, swapper_busy_time)
end
for nodea in vertices(mgraph)
    for nodeb in vertices(mgraph)
        if nodeb>nodea
            @process purifier(sim, mgraph, nodea, nodeb, purifier_wait_time, purifier_busy_time)
        end
    end
end

fig = Figure(resolution=(1000,400))
registers = [get_prop(mgraph, node, :register) for node in vertices(mgraph)]
registersobs = Observable(registers)
subfig_rg, ax_rg, p_rg = registersgraph_axis(fig[1,1],registersobs;graph=mgraph)

ts = Observable(Float64[0])
fidXX = Observable(Float64[0])
fidZZ = Observable(Float64[0])
ax_fid = Axis(fig[1,2][1,1], xlabel="time", ylabel="Entanglement Stabilizer\nExpectation")
lXX = stairs!(ax_fid,ts,fidXX,label="XX")
lZZ = stairs!(ax_fid,ts,fidZZ,label="ZZ")
xlims!(0, nothing)
ylims!(-.05, 1.05)
Legend(fig[1,2][2,1],[lXX,lZZ],["XX","ZZ"],
            orientation = :horizontal, tellwidth = false, tellheight = true)

display(fig)

step_ts = range(0, 100, step=0.1)
record(fig, "firstgenrepeater-07.observable.mp4", step_ts, framerate=10) do t
    run(sim, t)

    fXX = real(observable(registers[[1,5]], [2,2], XX, 0.0; time=t))
    fZZ = real(observable(registers[[1,5]], [2,2], ZZ, 0.0; time=t))
    push!(fidXX[],fXX)
    push!(fidZZ[],fZZ)
    push!(ts[],t)

    ax_rg.title = "t=$(t)"
    notify(registersobs)
    notify(ts)
    xlims!(ax_fid, 0, t+0.5)
end
