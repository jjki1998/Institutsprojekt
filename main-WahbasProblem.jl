include("musicalgorithm.jl")

using CSV,
    DSP,
    Plots,
    Tracking,
    LinearAlgebra,
    Geodesy,
    CoordinateTransformations,
    Rotations
import Tracking: Hz, GPSL1

CartFromSph = CartesianFromSpherical()

NUM_STEPS = 200

B = Array{Float64,3}(undef, 3, 3, NUM_STEPS)
R = Array{Float64,3}(undef, 3, 3, NUM_STEPS)
U = Array{Float64,3}(undef, 3, 3, NUM_STEPS)
S = Array{Float64,3}(undef, 3, 1, NUM_STEPS)
Vt = Array{Float64,3}(undef, 3, 3, NUM_STEPS)
V = Array{Float64,3}(undef, 3, 3, NUM_STEPS)
M = Array{Float64,3}(undef, 3, 3, NUM_STEPS)
nick = Array{Float64,1}(undef, NUM_STEPS)
gier = Array{Float64,1}(undef, NUM_STEPS)
roll = Array{Float64,1}(undef, NUM_STEPS)

prns = [1, 3, 6, 8, 9, 10, 17, 23, 25, 30, 31]
dopplers = [
    4435.213936529221Hz,
    2593.4445540736638Hz,
    3748.653566415891Hz,
    4238.002576492806Hz,
    3460.3283916116347Hz,
    4726.911080562236Hz,
    4238.0093359598695Hz,
    426.7197530393033Hz,
    3145.701255015981Hz,
    4435.20779996334Hz,
    4726.888656721612Hz,
]
code_phases = [
    530.2780057206401,
    908.4066166542907,
    465.09631029868615,
    62.98743021827249,
    321.79463672530255,
    718.3838896209345,
    63.03299865574809,
    451.6124001651624,
    294.6680659959675,
    530.225686967824,
    718.0363587257307,
]

usrPos = Array{Float64,1}(undef, 3)

    usrPos[1] = 50.778747
    usrPos[2] = 6.066027
    usrPos[3] = 0


usrPos_LLA = LLA(usrPos[1], usrPos[2], usrPos[3])
sat = Array{Float64,2}(undef, 11, 3)
ecef_sat_it = 1

sat_ENU = Vector{ENU}(undef, 11)
sat_ECEF = Vector{ECEF}(undef, 11)
for row in CSV.File("ecef_sat_positions.csv")
    global ecef_sat_it
    sat[ecef_sat_it, 1] = row.x
    sat[ecef_sat_it, 2] = row.y
    sat[ecef_sat_it, 3] = row.z

    sat_ECEF[ecef_sat_it] =
        ECEF(sat[ecef_sat_it, 1], sat[ecef_sat_it, 2], sat[ecef_sat_it, 3])
    global sat_ENU[ecef_sat_it] =
        ENUfromECEF(usrPos_LLA, wgs84)(sat_ECEF[ecef_sat_it])
    println(prns[ecef_sat_it],": ",sat_ENU[ecef_sat_it])
    println(prns[ecef_sat_it],": ",sat_ENU[ecef_sat_it]/norm(sat_ENU[ecef_sat_it]))
    sat_ENU[ecef_sat_it] = sat_ENU[ecef_sat_it] / norm(sat_ENU[ecef_sat_it])
    ecef_sat_it += 1
end
sat_ENU_mat = hcat(sat_ENU...) #Konkatenation (horizontal) der ENU-Positionen
sat_ENU_mat_T = sat_ENU_mat'
display(sat_ENU_mat_T)



#Tracking
states = map(dopplers, code_phases) do doppler, code_phase
    TrackingState(GPSL1, doppler, code_phase, num_ants = NumAnts(4))
end

signalmatrix = Array{ComplexF32,2}(undef, 2500, 4)

signal1 = Array{ComplexF32,1}(undef, 2500) #2500 Samples pro 1 ms
signal2 = Array{ComplexF32,1}(undef, 2500)
signal3 = Array{ComplexF32,1}(undef, 2500)
signal4 = Array{ComplexF32,1}(undef, 2500)
stream1 = open("raw_data_antenna1.dat", "r")
stream2 = open("raw_data_antenna2.dat", "r")
stream3 = open("raw_data_antenna3.dat", "r")
stream4 = open("raw_data_antenna4.dat", "r")

for steps = 1:NUM_STEPS

    println(steps*50,"ms: ")
    signals_after_tracking = Array{Array{ComplexF64}}(undef, 11)
    ns = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    for n = 1:11
        signals_after_tracking[n] = [0, 0, 0, 0]
    end

    for n = 1:50 #50 samples are put into 1 matrix for the MUSIC-algorithm
        read!(stream1, signal1)
        read!(stream2, signal2)
        read!(stream3, signal3)
        read!(stream4, signal4)

        signalmatrix = [signal1 signal2 signal3 signal4]

        agc_signal = GainControlledSignal(signalmatrix)

        results = map(states, prns) do state, prn
            track(agc_signal, state, prn, 2.5e6Hz)
        end

        global states = get_state.(results)

        signal_after_tracking = get_prompt.(results)

        for j = 1:11
            signals_after_tracking[j] =
                [signals_after_tracking[j] signal_after_tracking[j]]
        end
    end

    #MUSIC-Algorithmus
    #for every block of 50ms, MUSIC is applied for all 11 satellites
    #to determine the angle of incident of the satellite signals
    azimuth_elevation_sph = Vector{Spherical}(undef, 11)
    azimuth_elevation_cart = Vector{}(undef, 11)
    map(prns, ns, signals_after_tracking) do prn, n, signal_after_tracking
        x = signal_after_tracking
        x_h = adjoint(x)
        rxx = x * x_h

        rxx_eigen = eigvecs(rxx)
        noise_eigen = [rxx_eigen[:, 1] rxx_eigen[:, 2] rxx_eigen[:, 3]]
        noise_eigen_h = adjoint(noise_eigen)

        azimuth_elevation = [0, 0]

        musicalgorithm(noise_eigen_h, azimuth_elevation)

        println(prn, ": ", azimuth_elevation)

        azimuth_elevation_sph[n] = Spherical(
            1.0,
            azimuth_elevation[1] * π / 180,
            azimuth_elevation[2] * π / 180
        )
        global azimuth_elevation_cart[n] = CartFromSph(azimuth_elevation_sph[n])
    end

    aziele_cart_mat = hcat(azimuth_elevation_cart...)
    display(aziele_cart_mat)


    #Wahbas Problem
    B[:, :, steps] = aziele_cart_mat * sat_ENU_mat_T
    F = svd(B[:, :, steps]) #Singular value decomposition

    U[:, :, steps] = F.U
    S[:, :, steps] = F.S
    Vt[:, :, steps] = F.Vt
    V[:, :, steps] = F.V

    M[:, :, steps] = Diagonal([1, 1, det(U[:, :, steps]) * det(V[:, :, steps])])

    R[:, :, steps] = U[:, :, steps] * M[:, :, steps] * Vt[:, :, steps]

    rotations = RotXYZ(R[:, :, steps])

    gier[steps] = rotations.theta1
    nick[steps] = rotations.theta2
    roll[steps] = rotations.theta3

end

#Plots

display(plot(nick,ylims = (-4,4),ylabel = "Winkel(in Bogenmaß)",label ="",title = "Nick"))
display(plot(gier,ylims = (-4,4),ylabel = "Winkel(in Bogenmaß)",label ="",title = "Gier"))
display(plot(roll,ylims = (-4,4),ylabel = "Winkel(in Bogenmaß)",label ="",title = "Roll"))

close(stream1)
close(stream2)
close(stream3)
close(stream4)
