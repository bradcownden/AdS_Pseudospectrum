__precompile__()

#=
#  Perform Clenshaw-Curtis quadrature on a function: calculate the quadrature points
#  and weights then return a matrix whose diagonal is the partial sum
=#

module quad

export Gram
export quadrature_GC
export quadrature_GL
export quadrature

using LinearAlgebra
using ThreadsX
using BlockArrays

    # Return the quadrature weights assuming the endpoint grid
    function quadrature(x::Vector)
        nn = length(x) - 1
        tquad = ThreadsX.map(i->pi*i/nn, 0:nn)
        wts = Vector{eltype(x)}(undef, length(x))
        kappa = [i == 1 ? 2 : i == length(x) ? 2 : 1 for i in eachindex(x)]
        Nfl = trunc(Int, floor(nn/2))
        # T_n(cos x) = cos(n x)
        @inbounds ThreadsX.foreach(eachindex(wts)) do I
            mysum = ThreadsX.sum(k == Nfl ? cos(2*k * tquad[I]) / (4*k^2 - 1) : 2 * cos(2*k * tquad[I]) / (4*k^2 - 1) for k in 1:Nfl)
            wts[I] = 2 * (1 - mysum) / (kappa[I] * nn)
        end
        return wts
    end
    
    # Construct the first Gram matrix from the phi_1 phi_2 term . 
    # Note that factors of (2) come
    # from changing derivative matrices from x to rho
    function G1(x::Array, D::Matrix, m::Float64, q::Float64)
        qwts = quadrature(x)
        rho = x ./ 2 .+ (1/2)
        f = f_p(x)
        #print("High res quadrature weights: "); show(wts); println("")
        foo = Matrix{eltype(x)}(undef, size(D))
        # Terms with derivatives
        foo = D' * (diagm(ThreadsX.map(i -> f[i] * qwts[i] * (1 - rho[i]), 
                    eachindex(x))) ./ 4) * D
            - D' * (diagm(qwts .* f)) - (diagm(qwts .* f)) * D
        # Terms without derivatives
        foo += diagm(ThreadsX.map(i -> qwts[i] * ((4 * f[i] + m^2) / (1 - rho[i]) + q^2 * (1 - rho[i])), eachindex(x)))
        return foo
    end

    # Construct the first Gram matrix. Note that factors of (2) come
    # from changing derivative matrices from x to rho
    function G2(x::Array)
        qwts = quadrature(x)
        rho = x ./ 2 .+ (1/2)
        f = f_p(x)
        return diagm(ThreadsX.map(i -> qwts[i] * (2 - f[i]) * (1 - rho[i]), eachindex(x)))
    end
    
    # Use quadrature to construct Gram matrices at double the spectral
    # density, then use interpolation to bring the result back to the
    # proper shape
    function Gram(x::Vector, D::Matrix, y::Vector, Dy::Matrix, m::Float64, q::Float64)
        # Interpolation from high res (2N+2)x(2N+2) to low res (N+1)x(N+1)
        Imat = interpolator(x,y)
        ImatT = Imat'
        # Use high res grid to calculate G1, then interpolate down
        temp = Matrix{eltype(x)}(undef, (length(y), length(x)))
        G1_int = Matrix{eltype(x)}(undef, size(D))
        # Safe matrix product to handle Infs
        G1mat = G1(y,Dy,m,q)
        # G(1,1) is Inf but only multiplies a non-zero value once
        @views ThreadsX.foreach(Iterators.product(eachindex(y), eachindex(x))) do (i,j)
            if i == 1 && j == 1
                temp[i,j] = Inf
            elseif i == 1
                temp[i,j] = dot(G1mat[i,2:end], Imat[2:end,j])
            else
                temp[i,j] = dot(G1mat[i,:], Imat[:,j])
            end
        end
        @views ThreadsX.foreach(Iterators.product(eachindex(x), eachindex(x))) do (i,j)
            # Intermediate matrix has a row of Infs that multiplies either 0 or 1
            if isinf(temp[begin,j])
                if i != 1
                    # Infinite value is multiplied by 0 so does not contribute
                    G1_int[i,j] = dot(ImatT[i,begin+1:end], temp[begin+1:end,j])
                else
                    # Execpt the last row where it is multiplied by 1
                    G1_int[i,j] = Inf
                end
            else
                G1_int[i,j] = dot(ImatT[i,:], temp[:,j])
            end
        end
        # Remove rows and columns corresponding to the rho = 1 boundary
        Gup = reduce(hcat, [view(G1_int, 2:length(x), 2:length(x)), zeros(eltype(x), (length(x)-1, length(x)-1))])
        # Same for G2
        #print("G2 high res: "); show(G2(y)); println("")
        G2_int = ImatT * G2(y) * Imat
        #print("G2 interpolated: "); show(G2_int); println("")
        # Remove rows and columns corresponding to the rho = 1 boundary
        Glow = reduce(hcat, [zeros(eltype(x), (length(x)-1, length(x)-1)), view(G2_int, 2:length(x), 2:length(x))])
        println("Gupper posdef? ", isposdef(Gup))
        println("Glower posdef? ", isposdef(Glow))
        G = vcat(Gup, Glow)
    return G
    end

    function delta(x, y)
        return x == y ? 1 : 0
    end

    # Interpolation between high (y) and low (x) resolution Gram matrices
    function interpolator(x::Vector, y::Vector)
        tx = Vector{eltype(x)}(undef, length(x))
        ty = Vector{eltype(y)}(undef, length(y))
        ThreadsX.map!(i -> i * pi / (length(x) - 1), tx, 0:length(x)-1)
        ThreadsX.map!(i -> i * pi / (length(y) - 1), ty, 0:length(y)-1)
        Imat = Matrix{eltype(x)}(undef, (length(y),length(x)))
        kappa = [i == 1 ? 2 : i == length(x) ? 2 : 1 for i in eachindex(x)]
        ThreadsX.foreach(Iterators.product(eachindex(y), eachindex(x))) do (i,j)
            sum = ThreadsX.sum((2 - delta(k, length(x)-1)) * cos(k * ty[i]) * cos(k * tx[j]) for k in 1:length(x)-1)
            Imat[i,j] = (1 + sum) / (kappa[j] * (length(x)-1))
        end
        #=
        println(""); print("Interpolation matrix: "); show(Imat); println("")
        testm = [0.015873 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
        0.0 0.146219 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
        0.0 0.0 0.279365 0.0 0.0 0.0 0.0 0.0 0.0; 
        0.0 0.0 0.0 0.361718 0.0 0.0 0.0 0.0 0.0; 
        0.0 0.0 0.0 0.0 0.393651 0.0 0.0 0.0 0.0; 
        0.0 0.0 0.0 0.0 0.0 0.361718 0.0 0.0 0.0; 
        0.0 0.0 0.0 0.0 0.0 0.0 0.279365 0.0 0.0; 
        0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.146219 0.0; 
        0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.015873]
        println(""); print("Test interpolation: "); show(Imat' * testm * Imat); println("")
        =#
        return Imat
    end

end