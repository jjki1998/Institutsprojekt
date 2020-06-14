#include("coordinates.jl")
include("musicalgorithm.jl")

using LinearAlgebra
using Tracking
using Tracking: Hz, GPSL1
using CSV

#hier werden die Satellitendaten eingelesen(PRN,Codephasen und Doppler)

prns = Array{Int64,1}(undef,0)

code_phases = Array{Float64}(undef,0)

dopplers = Array{typeof(100Hz)}(undef,0)

dopplers = [4435.213936529221Hz,
2593.4445540736638Hz,
3748.653566415891Hz,
4238.002576492806Hz,
3460.3283916116347Hz,
4726.911080562236Hz,
4238.0093359598695Hz,
426.7197530393033Hz,
3145.701255015981Hz,
4435.20779996334Hz,
4726.888656721612Hz]

for row in CSV.File("doppler_and_codephase.csv")

append!(prns,[row.prn])
append!(code_phases,[row.code_phase])

end

#ab hier beginnt das Tracking gefolgt vom MUSIC-Algorithmus

sample_frequency = 2.5e6Hz

states = map(dopplers, code_phases) do doppler, code_phase
TrackingState(GPSL1, doppler, code_phase, num_ants = NumAnts(4))
end

stream1 = open("raw_data_antenna1.dat", "r")
stream2 = open("raw_data_antenna2.dat", "r")
stream3 = open("raw_data_antenna3.dat", "r")
stream4 = open("raw_data_antenna4.dat", "r")

while !eof(stream1) && !eof(stream2) && !eof(stream3) && !eof(stream4)

    signal1 = Array{ComplexF32, 1}(undef,2500)
    signal2 = Array{ComplexF32, 1}(undef,2500)
    signal3 = Array{ComplexF32, 1}(undef,2500)
    signal4 = Array{ComplexF32, 1}(undef,2500)

    read!(stream1, signal1)
    read!(stream2, signal2)
    read!(stream3, signal3)
    read!(stream4, signal4)

    signalmatrix = [signal1 signal2 signal3 signal4]

    agc_signal = GainControlledSignal(signalmatrix)

    results = map(states, prns) do state, prn
    track(agc_signal, state, prn, sample_frequency)
    end

    signal_after_tracking = get_prompt.(results)

    for n in 1:11
        x           = signal_after_tracking[n]
        xh          = adjoint(x)
        rxx         = x * xh

        rxxeigen    = eigvecs(rxx)
        noiseeigen  = [rxxeigen[:,1] rxxeigen[:,2] rxxeigen[:,3]]
        noiseeigenh = adjoint(noiseeigen)

        azimuthelevation = [0,0]

        musicalgorithm(noiseeigenh,azimuthelevation)

        println(azimuthelevation)

    end

    break

end
