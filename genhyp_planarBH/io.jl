__precompile__()

#= 
#  Module for writing output files for pspec
=#

module io

using DelimitedFiles

export writeData, writeCondition

    # Write vector data to file
    function writeData(data::Vector)
        # Check for data directory; create if abscent
        isdir("./data") ? nothing : mkdir("./data")
        # Construct file name
        size = Integer(length(data)/2)
        fname = "./data/Eigenvals_N" * string(size) * "P"
        if eltype(data) == BigFloat || eltype(data) == Complex{BigFloat}
            fname *= string(precision(BigFloat)) * ".txt"
        else
            fname *= "64.txt"
        end
        open(fname, "w") do io
            writedlm(io, length(data)-1)
            # Caution: \t character automatically added to file between real and imaginary parts
            writedlm(io, hcat(real.(data), imag.(data)))
            println("Wrote data to ", split(io.name," ")[2][1:end-1])
        end
    end

    # Write vector data to file
    function writeData(data::Vector, N::Int64)
        # Check for data directory; create if abscent
        isdir("./data") ? nothing : mkdir("./data")
        # Construct file name
        size = Integer(N)
        fname = "./data/Eigenvals_N" * string(size) * "P"
        if eltype(data) == BigFloat || eltype(data) == Complex{BigFloat}
            fname *= string(precision(BigFloat)) * ".txt"
        else
            fname *= "64.txt"
        end
        open(fname, "w") do io
            writedlm(io, length(data)-1)
            # Caution: \t character automatically added to file between real and imaginary parts
            writedlm(io, hcat(real.(data), imag.(data)))
            println("Wrote data to ", split(io.name," ")[2][1:end-1])
        end
    end



    # Write vector data to file
    function writeData(data::Vector, m::Float64, q::Float64, N::Int64=1)
        # Check for data directory; create if abscent
        isdir("./data") ? nothing : mkdir("./data")
        # Construct file name
        if N != 1
            size = Integer(length(data)/2)
        else
            size = Integer(N)
        end
        fname = "./data/Eigenvals_N" * string(size) * "P"
        if eltype(data) == BigFloat || eltype(data) == Complex{BigFloat}
            fname *= string(precision(BigFloat))
        else
            fname *= "64"
        end
        fname *= "m" * string(round(m; digits=1)) * "q" * string(round(q; digits=1)) * ".txt"
        open(fname, "w") do io
            writedlm(io, length(data))
            # Caution: \t character automatically added to file between real and imaginary parts
            writedlm(io, hcat(real.(data), imag.(data)))
            println("Wrote data to ", split(io.name," ")[2][1:end-1])
        end
    end

    # Write condition numbers to file
    function writeCondition(data::Vector)
        # Check for data directory; create if abscent
        isdir("./data") ? nothing : mkdir("./data")
        # Construct file name
        size = Integer(length(data))
        fname = "./data/Conditions_N" * string(size) * "P"
        if eltype(data) == BigFloat || eltype(data) == Complex{BigFloat}
            fname *= string(precision(BigFloat)) * ".txt"
        else
            fname *= "64.txt"
        end
        open(fname, "w") do io
            writedlm(io, length(data))
            writedlm(io, data)
            println("Wrote condition numbers to ", split(io.name," ")[2][1:end-1])
        end
    end

    function writeData(data::Matrix, x::Vector, m::Float64, q::Float64, inpts::Any)
        # Check for data directory; create if abscent
        isdir("./data") ? nothing : mkdir("./data")
        # Construct file name
        this_size = Integer(length(x)-1)
        fname = "./data/jpspec_N" * string(this_size) * "P"
        if eltype(x) == BigFloat || eltype(x) == Complex{BigFloat}
            fname *= string(precision(BigFloat))
        else
            fname *= "64"
        end
        fname *= "m" * string(round(m; digits=1)) * "q" * string(round(q; digits=1)) * ".txt"
        open(fname, "w") do io
            writedlm(io, adjoint([inpts.xmin::Float64, inpts.xmax::Float64, inpts.ymin::Float64, inpts.ymax::Float64, inpts.xgrid::Int64]))
            writedlm(io, hcat(size(data)))
            writedlm(io, data)
            println("Wrote data to ", split(io.name," ")[2][1:end-1])
        end
    end

end
