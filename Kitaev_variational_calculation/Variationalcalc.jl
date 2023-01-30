using LinearAlgebra
using SparseArrays
using Arpack 
using PyPlot
pygui(true) 

#=
This section uses the old ordering of the sites, where the periodic boundary conditions are implemented using the basis (n1,n2)
function get_H0(N,K=1)
    """
    Calculates a 2N^2 x 2N^2 matrix H0 which is the Hamiltonian for a flux free Kitaev model in terms of complex matter fermions. 
    - K is the Kitaev parameter (take to be +1 or -1)
    returns:
    - a 2N^2 x 2N^2 Hamiltonian matrix which is real and symmetric 
    """
    A = spzeros(N,N)
    B = spzeros(N,N)

    for j = 1:N-1
        A[j,j] = K
        A[j+1,j] = K
        B[j,j] = K
    end 
    A[N,N] = K
    A[1,N] = K

    

    M = spzeros(N^2,N^2)
    for j = 1:(N-1)
        M[(1+(j-1)*N):(j*N),(1+(j-1)*N):(j*N)] = A
        M[(1+(j-1)*N):(j*N),(1+j*N):((j+1)*N)] = B
    end

    M[N*(N-1)+1:N^2,N*(N-1)+1:N^2] = A
    M[N*(N-1)+1:N^2,1:N] = B

    H = spzeros(2*N^2,2*N^2)

    H[1:N^2,1:N^2] = M + transpose(M)
    H[(N^2+1):2*N^2,1:N^2] = M - transpose(M)
    H[1:N^2,(N^2+1):2*N^2] = transpose(M) - M 
    H[(N^2+1):2*N^2,(N^2+1):2*N^2] = -M - transpose(M) 

    return H
end

function get_HF(N,K=1,flux_site=[Int(round(N/2)),Int(round(N/2))],flux_flavour="z")
    """
    Creates a 2N^2 x 2N^2 Hamiltonian matrix for a flux sector with a single flux pair. 
    The flux pair is located at the lattice site flux_site which is given as a coordinate [n1,n2] = n1*a1 + n2*a2 where a1,a2 are plvs. 
    The lattice sites are numbered such that an A site at [n1,n2] is given the index 1 + n1 + N*n2 
    The B lattice sites are numbered such that the B site connected to A via a z bond is given the same number. 
    flux_flavour specifies the type of bond which connects the fluxes in the pair. It is given as a string, either "x","y" or "z".

    The matrix H is calculated using the following steps:
    - Calculate the matrix M which descibes H in terms of Majorana fermions:
        0.5[C_A C_B][ 0 M ; -M 0][C_A C_B]^T
        
        - M is initially calculated in the same way as for H0 
        - A flipped bond variable (equivalent to adding flux pair) is added
        - flux_site specifies the A sublattice site, which specifies the row of M on which the variable is flipped, via C_A_index = 1 + n1 + n2*N
        - flux_flavour specifies the neighbouring B sublattice site, which specifies the column of M on which the variable is flipped 
    
    - Use M to calculate H in the basis of complex matter fermions:
        C_A = f + f'
        C_B = i(f'-f)

    returns:
    - A 2N^2 x 2N^2 sparse matrix Hamiltonian in the complex matter fermion basis 

    """

    flux_site = [flux_site[1],flux_site[2]]

    
    A = spzeros(N,N)
    B = spzeros(N,N)

    for j = 1:N-1
        A[j,j] = K
        A[j+1,j] = K
        B[j,j] = K
    end 
    A[N,N] = K
    A[1,N] = K
    B[N,N] = K

    M = spzeros(N^2,N^2)
    for j = 1:(N-1)
        M[(1+(j-1)*N):(j*N),(1+(j-1)*N):(j*N)] = A
        M[(1+(j-1)*N):(j*N),(1+j*N):((j+1)*N)] = B
    end

    M[N*(N-1)+1:N^2,N*(N-1)+1:N^2] = A
    M[N*(N-1)+1:N^2,1:N] = B

    C_A_index = 1 + flux_site[1] + N*flux_site[2]

    if flux_flavour == "z"
        C_B_index = C_A_index
    elseif flux_flavour == "y"
        if flux_site[2] == N - 1
            C_B_index = 1 + flux_site[1]
        else
            C_B_index = C_A_index + N 
        end 
    else
        if flux_site[1] == 0 
            C_B_index = C_A_index + N -1
        else 
            C_B_index = C_A_index -1 
        end 
    end 

    M[C_A_index,C_B_index] = -K 

    H = zeros(2*N^2,2*N^2)

    H[1:N^2,1:N^2] = M + transpose(M)
    H[(N^2+1):2*N^2,1:N^2] = M - transpose(M)
    H[1:N^2,(N^2+1):2*N^2] = transpose(M) - M 
    H[(N^2+1):2*N^2,(N^2+1):2*N^2] = -M - transpose(M) 

    return H 

end 

function flip_bond_variable(H,bond_site,bond_flavour)
    N = Int(sqrt(size(H)[1]/2))

    M = get_M_from_H(H)

    C_A_index = 1 + bond_site[1] + N*bond_site[2]

    if bond_flavour == "z"
        C_B_index = C_A_index
    elseif bond_flavour == "y"
        if bond_site[2] == N - 1
            C_B_index = 1 + bond_site[1]
        else
            C_B_index = C_A_index + N 
        end 
    else
        if bond_site[1] == 0 
            C_B_index = C_A_index + N -1
        else 
            C_B_index = C_A_index -1 
        end 
    end 

    M[C_A_index,C_B_index] = - M[C_A_index,C_B_index]

    H = zeros(2*N^2,2*N^2)

    H[1:N^2,1:N^2] = M + transpose(M)
    H[(N^2+1):2*N^2,1:N^2] = M - transpose(M)
    H[1:N^2,(N^2+1):2*N^2] = transpose(M) - M 
    H[(N^2+1):2*N^2,(N^2+1):2*N^2] = -M - transpose(M) 

    return H 
end 

function convert_lattice_vector_to_index(lattice_vector,N)
    index = 1 + lattice_vector[1] + N*lattice_vector[2]
    return index
end 

function find_flipped_bond_coordinates(H)
    """
    Assumes the Hamiltonian contains only a single flipped bond. 
    Finds the coordinate of the flipped bond site in the form [n1,n2] = n1*a1 + n2*a2
    """

    N = Int(sqrt(size(H)[1]/2))
    h = H[1:N^2,1:N^2]
    Delta = H[1:N^2,(1+N^2):2*N^2]

    M = 0.5*(h-Delta)

    K = sign(sum(M))

    bond_indicies_set = findall(x->x==-K,M)
    
    for bond_indicies in bond_indicies_set
        C_A_index = bond_indicies[1]
        if C_A_index % N == 0 
            C_A_n1 = Int(N-1)
            C_A_n2 = Int(C_A_index/N -1)
        else
            C_A_n2 = Int(floor(C_A_index/N))
            C_A_n1 = Int(C_A_index - C_A_n2*N -1)
        end 

        C_B_index = bond_indicies[2]
        if C_B_index % N == 0 
            C_B_n1 = Int(N-1)
            C_B_n2 = Int(C_B_index/N -1) 
        else
            C_B_n2 = Int(floor(C_B_index/N))
            C_B_n1 = Int(C_B_index - C_B_n2*N -1) 
        end 

        if C_A_index == C_B_index
            bond_flavour = "z"
        elseif C_B_n1 == C_A_n1 
            bond_flavour = "y"
        elseif C_B_n2 == C_A_n2
            bond_flavour = "x"
        end
        
        println("flipped bond at R = $C_A_n1 a1 + $C_A_n2 a2 with flavour $bond_flavour")
    end 
end 
=#

function get_H0(N,K=1)
    """
    Calculates a 2N^2 x 2N^2 matrix H0 which is the Hamiltonian for a flux free Kitaev model in terms of complex matter fermions. 
    - K is the Kitaev parameter (take to be +1 or -1)
    returns:
    - a 2N^2 x 2N^2 Hamiltonian matrix which is real and symmetric 
    """
    A = spzeros(N,N)
    B = spzeros(N,N)

    for j = 1:N-1
        A[j,j] = K
        A[j+1,j] = K
        B[j+1,j] = K
    end 
    A[N,N] = K
    A[1,N] = K
    B[1,N] = K

    M = spzeros(N^2,N^2)
    for j = 1:(N-1)
        M[(1+(j-1)*N):(j*N),(1+(j-1)*N):(j*N)] = A
        M[(1+(j-1)*N):(j*N),(1+j*N):((j+1)*N)] = B
    end

    M[N*(N-1)+1:N^2,N*(N-1)+1:N^2] = A
    M[N*(N-1)+1:N^2,1:N] = B

    H = spzeros(2*N^2,2*N^2)

    H[1:N^2,1:N^2] = M + transpose(M)
    H[(N^2+1):2*N^2,1:N^2] = M - transpose(M)
    H[1:N^2,(N^2+1):2*N^2] = transpose(M) - M 
    H[(N^2+1):2*N^2,(N^2+1):2*N^2] = -M - transpose(M) 

    return H
end

function diagonalise_sp(H)
    """
    Diagonalises a given Hamiltonian H. H is assumed to be real, symmetric and in sparse matrix format. 
    returns:
    - a full spectrum of eigenvalues. It is assumed that for each energy E, -E is also an eigenvalue.
    - A unitary (orthogonal as T is real) matrix T which diagonalises H
    """
    N_sq = Int(size(H)[1]/2)
    half_spectrum , eigvecs = eigs(H, nev = N_sq, which =:LR, tol = 10^(-7), maxiter = 1000)

    if det(H) <= 10^(-6) 
        println("Warning: H is singular so there are degenerate eigenvalues")
        println("This may lead to numerical errors")
        display(det(H))
    end 

    energies = zeros(2*N_sq,1)
    energies[1:N_sq] = half_spectrum
    energies[N_sq+1:end] = - half_spectrum

    X = eigvecs[1:N_sq,1:N_sq]'
    Y = eigvecs[(N_sq+1):2*N_sq,1:N_sq]'

    T = [X Y ; Y X]

    plot(energies)

    return energies , T 
end 

function diagonalise(H)
    N_sq = Int(size(H)[1]/2)

    H = Matrix(H)

    energies = eigvals(H)
    reverse!(energies)
    eigvec = eigvecs(H)

    gamma = [zeros(N_sq,N_sq) Matrix(I,N_sq,N_sq) ; Matrix(I,N_sq,N_sq) zeros(N_sq,N_sq)]
    eigvec = gamma*eigvec

    X = eigvec[1:N_sq,1:N_sq]'
    Y = eigvec[(N_sq+1):2*N_sq,1:N_sq]'

    T = [X Y ; Y X]

    return energies , T 
end 

function get_HF(N,K=1,flux_site=[Int(round(N/2)),Int(round(N/2))],flux_flavour="z")
    """
    Creates a 2N^2 x 2N^2 Hamiltonian matrix for a flux sector with a single flux pair. 
    The flux pair is located at the lattice site flux_site which is given as a coordinate [n1,n2] = n1*a1 + n2*a2 where a1,a2 are plvs. 
    The lattice sites are numbered such that an A site at [n1,n2] is given the index 1 + n1 + N*n2 
    The B lattice sites are numbered such that the B site connected to A via a z bond is given the same number. 
    flux_flavour specifies the type of bond which connects the fluxes in the pair. It is given as a string, either "x","y" or "z".

    The matrix H is calculated using the following steps:
    - Calculate the matrix M which descibes H in terms of Majorana fermions:
        0.5[C_A C_B][ 0 M ; -M 0][C_A C_B]^T
        
        - M is initially calculated in the same way as for H0 
        - A flipped bond variable (equivalent to adding flux pair) is added
        - flux_site specifies the A sublattice site, which specifies the row of M on which the variable is flipped, via C_A_index = 1 + n1 + n2*N
        - flux_flavour specifies the neighbouring B sublattice site, which specifies the column of M on which the variable is flipped 
    
    - Use M to calculate H in the basis of complex matter fermions:
        C_A = f + f'
        C_B = i(f'-f)

    returns:
    - A 2N^2 x 2N^2 sparse matrix Hamiltonian in the complex matter fermion basis 

    """

    H0 = get_H0(N,K)

    HF = flip_bond_variable(H0,flux_site,flux_flavour)

    return HF

end 

function get_X_and_Y(T)
    """
    Given a unitary matrix T in the form T = [X* Y* ; Y X] this function extracts the X and Y matrices 
    """
    N_sq = Int(size(T)[1]/2)
    X = T[(N_sq+1):2*N_sq,(N_sq+1):2*N_sq]
    Y = T[(N_sq+1):2*N_sq,1:N_sq]

    return X , Y 
end 

function get_F_matrix(TF1,TF2)
    """
    calculates the matrix F (see Knolle's thesis) used to relate quasi-particle vacua in two different flux sectors 
    """
    T = TF2*TF1'
    X , Y = get_X_and_Y(T)

    F = conj(inv(X)*Y)

    return F 
end 

function get_normalisation_constant(TF1,TF2)
    T = TF2*TF1'
    X , Y = get_X_and_Y(T)

    c = (det(X'*X))^(1/4)

    return c
end 

function calculate_z_Heisenberg_hopping_matrix_element(N,K)
    #=
    HF1 = get_HF(N,K,initial_flux_site)
    EF1, TF1 = diagonalise(HF1)
    HF2 = get_HF(N,K,initial_flux_site+[1,0])
    EF2, TF2 = diagonalise(HF2)

    F = get_F_matrix(TF1,TF2)
    C = get_normalisation_constant(TF1,TF2)

    X1 , Y1 = get_X_and_Y(TF1)

    C_A_index = 1 + initial_flux_site[1]+N*initial_flux_site[2] + 1 # Final +1 is due to the final site being +a1 with respect to the initial site 
    C_B_index = 1 + initial_flux_site[1] + N*initial_flux_site[2]

    a = (X1+Y1)[:,C_A_index]
    b = (Y1-X1)[:,C_B_index]

    println("Hopping due to y spin interaction:")
    display((a'*b - b'*F*a))
    println("Normalisation constant C:")
    display(C)

    hopping_amp = (a'*b - b'*F*a + C)
    =#

    mark_with_x = false
    initial_flux_site = [Int(round(N/2)),Int(round(N/2))]
    final_flux_site = initial_flux_site + [1,0]
    
    initial_HF = get_HF(N,K,initial_flux_site,"z")
    final_HF = get_HF(N,K,final_flux_site,"z")

    _ , initial_TF = diagonalise(initial_HF)
    _ , final_TF = diagonalise(final_HF)

    C = get_normalisation_constant(initial_TF,final_TF)

    initial_X , initial_Y = get_X_and_Y(initial_TF)

    a_init = transpose(initial_X + initial_Y)
    b_init = transpose(initial_X - initial_Y)


    # T is a matrix which transforms the creation and annihilation operators for the initial flux sector into those of the final flux sector [f_final f_final']^T = T[f_initial f_initial']^T
    T = final_TF*initial_TF'

    if abs(sum(T*T')-2*N^2) > 0.2
        println("Warning: T is not unitary")
        mark_with_x = true 
    end

    X , Y = get_X_and_Y(T)
    M = inv(X)*Y 

    i1 = convert_lattice_vector_to_index(final_flux_site,N)
    j0 = convert_lattice_vector_to_index(initial_flux_site,N)

    hopping_amp = C*(-a_init[i1,:]'*M*b_init[j0,:] + a_init[i1,:]'*b_init[j0,:] + 1) 

    return hopping_amp , mark_with_x


    return hopping_amp
end 

function plot_Heisenberg_hopping_vs_system_size(K,N_max)
    hopping_amp_vec = zeros(1,N_max)
    for N = 4:N_max
        hopping_amp_vec[N] , mark_with_x = calculate_z_Heisenberg_hopping_matrix_element(N,K)
        if mark_with_x == false
            scatter(1/N,hopping_amp_vec[N],color = "blue")
        else
            scatter(1/N,hopping_amp_vec[N],color = "blue",marker = "x")
        end
        display(N)
    end
    xlabel("Inverse of linear system size 1/N")
    ylabel("Heisenberg hopping amplitude")
    if K == 1
        ylabel("AFM Kitaev term")
    elseif K == -1
        ylabel("FM Kitaev term")
    end 
end

function get_M_from_H(H)
    N = Int(sqrt(size(H)[1]/2))
    h = H[1:N^2,1:N^2]
    Delta = H[1:N^2,(1+N^2):2*N^2]

    M = 0.5*(h-Delta)

    return M
end 

function find_flipped_bond_coordinates(H)
    """
    Assumes the Hamiltonian contains only a single flipped bond. 
    Finds the coordinate of the flipped bond site in the form [n1,n2] = n1*a1 + n2*a2
    """

    N = Int(sqrt(size(H)[1]/2))
    h = H[1:N^2,1:N^2]
    Delta = H[1:N^2,(1+N^2):2*N^2]

    M = 0.5*(h-Delta)

    K = sign(sum(M))

    bond_indicies_set = findall(x->x==-K,M)
    
    for bond_indicies in bond_indicies_set
        C_A_index = bond_indicies[1]
        if C_A_index % N == 0 
            C_A_n2 = Int(C_A_index/N -1)
            C_A_n1 = Int(N-1) + C_A_n2
        else
            C_A_n2 = Int(floor(C_A_index/N))
            C_A_n1 = Int(C_A_index - C_A_n2*N -1 + C_A_n2)
        end 

        C_B_index = bond_indicies[2]
        if C_B_index % N == 0 
            C_B_n2 = Int(C_B_index/N -1) 
            C_B_n1 = Int(N-1) + C_B_n2
        else
            C_B_n2 = Int(floor(C_B_index/N))
            C_B_n1 = Int(C_B_index - C_B_n2*N -1 + C_B_n2) 
        end 

        if C_A_index == C_B_index
            bond_flavour = "z"
        elseif C_B_n1 == C_A_n1 
            bond_flavour = "y"
        elseif C_B_n2 == C_A_n2
            bond_flavour = "x"
        end
        
        println("flipped bond at R = $C_A_n1 a1 + $C_A_n2 a2 with flavour $bond_flavour")
    end 
end 

function calculate_yz_Gamma_hopping_amplitude(N,K)

    mark_with_x = false
    initial_flux_site = [Int(round(N/2)),Int(round(N/2))]
    final_flux_site = initial_flux_site + [1,0]
    
    initial_HF = get_HF(N,K,initial_flux_site,"z")
    final_HF = get_HF(N,K,final_flux_site,"y")

    #=
    if det(initial_HF) < 10^(-12)
        println("Warning: det initial_HF is small indicating possible degenerate zero modes")
        mark_with_x = true 
    end
    if det(final_HF) < 10^(-12)
        println("Warning: det final_HF is small indicating degenerate zero modes")
        mark_with_x = true 
    end 
    =#

    _ , initial_TF = diagonalise(initial_HF)
    _ , final_TF = diagonalise(final_HF)

    C = get_normalisation_constant(initial_TF,final_TF)

    initial_X , initial_Y = get_X_and_Y(initial_TF)

    a_init = transpose(initial_X + initial_Y)
    b_init = transpose(initial_X - initial_Y)


    # T is a matrix which transforms the creation and annihilation operators for the initial flux sector into those of the final flux sector [f_final f_final']^T = T[f_initial f_initial']^T
    T = final_TF*initial_TF'

    if abs(sum(T*T')-2*N^2) > 0.2
        println("Warning: T is not unitary")
        mark_with_x = true 
    end

    X , Y = get_X_and_Y(T)
    M = inv(X)*Y 

    i1 = convert_lattice_vector_to_index(final_flux_site,N)
    j0 = convert_lattice_vector_to_index(initial_flux_site,N)

    hopping_amp = C*(-a_init[i1,:]'*M*b_init[j0,:] + a_init[i1,:]'*b_init[j0,:] - 1) 

    return hopping_amp , mark_with_x
end 

function convert_lattice_vector_to_index(lattice_vector,N)
    index = 1 + lattice_vector[1] - lattice_vector[2] + N*lattice_vector[2]
    return index
end 

function plot_Gamma_hopping_vs_system_size(K,N_max)
    hopping_amp_vec = zeros(1,N_max)
    for N = 4:N_max
        hopping_amp_vec[N] , mark_with_x = calculate_yz_Gamma_hopping_amplitude(N,K)
        if mark_with_x == false
            scatter(1/N,hopping_amp_vec[N],color = "blue")
        else
            scatter(1/N,hopping_amp_vec[N],color = "blue",marker = "x")
        end
        display(N)
    end
    xlabel("Inverse of linear system size 1/N")
    ylabel("Gamma hopping amplitude")
    if K == 1
        ylabel("AFM Kitaev term")
    elseif K == -1
        ylabel("FM Kitaev term")
    end 
end

function flip_bond_variable(H,bond_site,bond_flavour)
    N = Int(sqrt(size(H)[1]/2))

    M = get_M_from_H(H)

    C_A_index = 1 + bond_site[1] - bond_site[2] + N*bond_site[2]

    if bond_flavour == "z"
        C_B_index = C_A_index
    elseif bond_flavour == "y"
        if bond_site[2] == N - 1
            if bond_site[1] == bond_site[2]
                C_B_index = N
            else
                C_B_index = bond_site[1]-bond_site[2]
            end 
        elseif bond_site[1] == bond_site[2]
            C_B_index = C_A_index + 2*N - 1
        else
            C_B_index = C_A_index + N - 1 
        end 
    else
        if bond_site[1] == bond_site[2] 
            C_B_index = C_A_index + N -1
        else 
            C_B_index = C_A_index -1 
        end 
    end 

    M[C_A_index,C_B_index] = - M[C_A_index,C_B_index]

    H = zeros(2*N^2,2*N^2)

    H[1:N^2,1:N^2] = M + transpose(M)
    H[(N^2+1):2*N^2,1:N^2] = M - transpose(M)
    H[1:N^2,(N^2+1):2*N^2] = transpose(M) - M 
    H[(N^2+1):2*N^2,(N^2+1):2*N^2] = -M - transpose(M) 

    return H 
end 

function calculate_interlayer_hopping_amplitude(N,K,flux_site)

    mark_with_x = false
    H0 = get_H0(N,K)

    
    H_xy = flip_bond_variable(H0,flux_site,"x")
    H_xy = flip_bond_variable(H_xy,flux_site,"y")

    find_flipped_bond_coordinates(H_xy)

    E0 , T0 = diagonalise(H0)
    E_xy , T_xy = diagonalise(H_xy)
    T = T0*T_xy'

    if abs(sum(T*T')-2*N^2) > 0.2
        println("Warning: T is not unitary")
        mark_with_x = true 
    end

    if abs(sum(T0*T0')-2*N^2) > 0.2
        println("Warning: T is not unitary")
        mark_with_x = true 
    end

    if abs(sum(T_xy*T_xy')-2*N^2) > 0.2
        println("Warning: T is not unitary")
        mark_with_x = true 
    end

    X_xy , Y_xy = get_X_and_Y(T_xy)
    X , Y = get_X_and_Y(T)

    M = inv(X)*Y

    if det(X) < 10^(-10)
        println("Warning: det(X) is very small, inv(X) is likely to be very large")
        mark_with_x = true 
    end 

    
    a_init = transpose(X_xy + Y_xy)
    b_init = transpose(X_xy - Y_xy)

    #display(X)
    #display(det(X))
    #display(det(X'))
    #display(det(X)*det(X'))
    C = (det(X)*det(X'))^(1/4)


    i = convert_lattice_vector_to_index(flux_site,N)
    j = i 

    display(C)
    display(-a_init[i,:]'*M*b_init[j,:])

    hopping_amp = (C^2)*(1+(-a_init[i,:]'*M*b_init[j,:] + a_init[i,:]'*b_init[j,:])^2)

    return hopping_amp , mark_with_x
end 

function plot_interlayer_hopping_vs_system_size(K,N_max)
    hopping_amp_vec = zeros(1,N_max)
    for N = 4:N_max
        hopping_amp_vec[N] , mark_with_x = calculate_interlayer_hopping_amplitude(N,K,[2,2])
        if mark_with_x == false
            scatter(1/N,hopping_amp_vec[N],color = "blue")
        else
            scatter(1/N,hopping_amp_vec[N],color = "blue",marker = "x")
        end
        display(N)
    end
    xlabel("Inverse of linear system size 1/N")
    ylabel("Gamma hopping amplitude")
    if K == 1
        ylabel("AFM Kitaev term")
    elseif K == -1
        ylabel("FM Kitaev term")
    end 
end


#=
This final section of code is an attempt to use the  3 fold rotation symmetry of the ground state to reduce the Hamiltonian to block diagonal form before diagonalising. 
The code is successful at block diagonalising and finding the diagonalising transformation but the transformation is not unitary and is only applicable to the ground state so for now it is left incomplete. 
=#

function form_M_matrix(N)
    diag_block = zeros(N,N)
    for j = 1:(N-1)
        diag_block[j,j]=1
        diag_block[j+1,j]=1
    end
    diag_block[N,N] = 1

    A = zeros(N^2,N^2)
    for j = 1:(N-1)
        A[(1+(j-1)*N):(j*N),(1+(j-1)*N):(j*N)] = diag_block
        A[(1+(j-1)*N):(j*N),(1+(j)*N):((j+1)*N)] = Matrix(I,N,N)
    end 
    A[(1+N^2-N):N^2,(1+N^2-N):N^2] = diag_block

    B = zeros(N^2,N^2)
    C = zeros(N^2,N^2)

    for j = 1:N
        B[N^2-N+j,j*N] = 1
        C[(1+(j-1)*N),j] = 1
    end

    M = [ A B C ; C A B ; B C A]

    return M 
end 

function form_R_matrix(N)
    """
    R is a 3N^2 x 3N^2 matrix which transforms between the lattice sites basis and eigenstates of the C3 rotation symmetry operator. 
    """
    l = exp(2*pi*im/3)
    R = (1/sqrt(3))* [ I(N^2) l*I(N^2) conj(l)*I(N^2) ; I(N^2) conj(l)*I(N^2) l*I(N^2) ; I(N^2) I(N^2) I(N^2)]

    return R 
end 

function form_H0_matrix(N)
    """
    Calculates a matrix Hamiltonian for the fluxless Kitaev model:
    H = 1/2 (f' f) H (f f')^T
    where f are complex matter fermions 
    """
    M = form_M_matrix(N)
    h = M + M'
    Delta = M'- M 
    
    return [h Delta ; Delta' -h]
end 

function form_H_prime(N)
    """
    Calculates a matrix Hamiltonian for the fluxless Kitaev model in the rotated basis of symmetry eigenstates:
    H = 1/2 (F' F) H' (F F')^T
    where F are complex matter fermions in the C3 symmetry eigenbasis 
    """
    R = form_R_matrix(N)
    M = form_M_matrix(N)

    curly_M = R*M*R'

    h = curly_M + curly_M'
    Delta = curly_M' - curly_M

    return [ h Delta ; Delta' -h ]
end 

function form_gamma_matrix(N)
    gamma = zeros(6*N^2,6*N^2)
    gamma[1:N^2,1:N^2] = I(N^2)
    gamma[(N^2+1):2*N^2,(1+3*N^2):4*N^2] = I(N^2)
    gamma[(2*N^2+1):3*N^2,(1+N^2):2*N^2] = I(N^2)
    gamma[(3*N^2+1):4*N^2,(4*N^2+1):5*N^2] = I(N^2)
    gamma[(4*N^2+1):5*N^2,(2*N^2+1):3*N^2] = I(N^2)
    gamma[(5*N^2+1):6*N^2,(5*N^2+1):6*N^2] = I(N^2) 

    return gamma
end 

function form_gamma_2_matrix(N)
    gamma = zeros(6*N^2,6*N^2)
    reverse_order = zeros(N^2,N^2)
    for j = 1:N^2
        reverse_order[N^2+1-j,j] = 1
    end 
    
    gamma[1:N^2,(N^2+1):2*N^2] = I(N^2)
    gamma[(N^2+1):2*N^2,(3*N^2+1):4*N^2] = I(N^2)
    gamma[(2*N^2+1):3*N^2,(5*N^2+1):6*N^2] = I(N^2)
    gamma[(3*N^2+1):4*N^2,1:N^2] = reverse_order
    gamma[(4*N^2+1):5*N^2,(2*N^2+1):3*N^2] = reverse_order
    gamma[(5*N^2+1):6*N^2,(4*N^2+1):5*N^2] = reverse_order

    return gamma
end


function block_diagonalise(H_prime)
    N = Int(sqrt(size(H_prime)[1]/6))
    g = form_gamma_matrix(N)
    
    return g*H_prime*g'
end 

function diagonalise_blocks(H_prime)
    """
    This diagonalises the matrix H_prime in a single function. It works by: 
    - transforming H_prime into block diagonal form with 3 2N^2 x 2N^2 blocks 
    - Diagonalising each block seperately and forming a block diagonal unitary matrix U 
    - Transforming U back into the original basis, with reordered eigenvalues 
    returns 
    - T_prime, a unitary matrix such that T_prime*H_prime*T_prime' = [E 0 ; -E 0]

    NOTE the eigenvalue in E are NOT in increasing size order. 
    """
    N = Int(sqrt(size(H_prime)[1]/6))
    g = form_gamma_matrix(N)
    g2 = form_gamma_2_matrix(N)

    block_diagonal_H = g*H_prime*g'

    U = zeros(Complex{Float64},6*N^2,6*N^2)

    for j = 1:3
        U[(1+2*(j-1)*N^2):j*2*N^2,(1+2*(j-1)*N^2):j*2*N^2] = eigvecs(block_diagonal_H[(1+2*(j-1)*N^2):j*2*N^2,(1+2*(j-1)*N^2):j*2*N^2])
    end 

    T_prime = g2*U'*g

    return T_prime
end

function diagonalise_H0(H_prime)
    N = Int(sqrt(size(H_prime)[1]/6))
    g = form_gamma_matrix(N)
    g2 = form_gamma_2_matrix(N)
    R = form_R_matrix(N)

    block_diagonal_H = g*H_prime*g'

    U = zeros(Complex{Float64},6*N^2,6*N^2)

    for j = 1:3
        U[(1+2*(j-1)*N^2):j*2*N^2,(1+2*(j-1)*N^2):j*2*N^2] = eigvecs(block_diagonal_H[(1+2*(j-1)*N^2):j*2*N^2,(1+2*(j-1)*N^2):j*2*N^2])
    end 

    T_prime = g2*U'*g

    T = T_prime*[ R zeros(3*N^2,3*N^2) ; zeros(3*N^2,3*N^2) R]

    Y = T[(3N^2+1):end,1:3*N^2]
    X = T[(3N^2+1):end,(3N^2+1):end]

    return [conj(X) conj(Y) ; Y X]
end 
