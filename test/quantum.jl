const obsnames_XXZ = ["Energy", "Energy^2", "Specific Heat",
                  # "|Magnetization|",
                  "Magnetization^2",
                  # "Magnetization^4", "Binder Ratio",
                  "Susceptibility",
                  # "Connected Susceptibility",
                 ]

function loaddata(filename, obsnames)
    Ts = zeros(0)
    res = Dict(n=>zeros(0) for n in obsnames)
    for line in eachline(filename)
        words = split(line)
        push!(Ts, parse(words[1]))
        for (i,n) in enumerate(obsnames)
            push!(res[n], parse(words[i+1]))
        end
    end
    return Ts, res
end

function parse_filename(filename)
    m = match(r"^S_([\d.-]*)__Jz_([\d.-]*)__Jxy_([\d.-]*)__G_([\d.-]*)__L_([\d.-]*).dat$", filename)
    if m == nothing
        return nothing
    end
    p = Dict()
    p["S"] = parse(m.captures[1])
    p["Jz"] = parse(m.captures[2])
    p["Jxy"] = parse(m.captures[3])
    p["Gamma"] = parse(m.captures[4])
    p["L"] = parse(Int, m.captures[5])
    return p
end

function QMC(T; S=0.5, Jz=1.0, Jxy=1.0, Gamma=0.0, L=8)
    p = Dict("Model"=>QuantumXXZ, "Lattice"=>chain_lattice,
             "S"=>S, "L"=>L,
             "Jz"=>Jz, "Jxy"=>Jxy,
             "Gamma"=>Gamma,
             "T"=>T,
             "MCS"=>MCS,
             "Thermalization"=>Therm,
            )
    return runMC(p)
end

#=
@testset "QuantumXXZ chain" begin
    for filename in readdir(joinpath("ref", "QuantumXXZ"))
        p = parse_filename(filename)
        if p == nothing
            continue
        end
        @testset "S=$(p[:S]), Jz=$(p[:Jz]), Jxy=$(p[:Jxy]), Gamma=$(p[:Gamma]), L=$(p[:L])" begin
            Ts, exacts = loaddata(joinpath("ref", "QuantumXXZ", filename))
            N = length(Ts)
            for (T,exact) in zip(Ts,exacts)
                srand(SEED)
                res = QMC(T; p...)
                ene = res["Energy"]
                if !(p_value(ene, exact) > alpha/N)
                    if  mean(res["Sign"]) < 1.0 && !(isfinite(mean(ene)))
                        ## Sign problem makes test very difficult...
                        continue
                    else
                        ## Perform one more test since single MC test may fail.
                        res = QMC(T; p...)
                        ene = res["Energy"]
                    end
                end
                @test p_value(ene, exact) > alpha/N
            end
        end
    end
end
=#

@testset "$modelstr" for (modelstr, pnames, obsnames) in [("QuantumXXZ", ("S", "Jz", "Jxy", "Gamma", "L"), obsnames_XXZ)]
    model = eval(Symbol(modelstr))
    @testset "$(latticestr)" for latticestr in ["chain_lattice"]
        lattice = eval(Symbol(latticestr))
        for filename in readdir(joinpath("ref", modelstr, latticestr))
            p = parse_filename(filename)
            if p == nothing
                continue
            end
            testname = ""
            for pname in pnames
                testname *= "$(pname)=$(p[pname]) "
            end
            @testset "$testname" begin
                Ts, exacts = loaddata(joinpath("ref", modelstr, latticestr, filename),obsnames)
                nT = length(Ts)
                p["Model"] = model
                p["Lattice"] = lattice
                p["MCS"] = MCS
                p["Thermalization"] = Therm
                srand(SEED)
                res1 = []
                res2 = []
                for i in 1:nT
                    p["T"] = Ts[i]
                    push!(res1, runMC(p))
                    push!(res2, runMC(p))
                end
                @testset "$n" for n in obsnames
                # @testset "$n" for n in ["Magnetization^2"]
                    for i in 1:nT
                        T = Ts[i]
                        exact = exacts[n][i]
                        r1 = res1[i]
                        r2 = res2[i]
                        ## single MC test may fail.
                        mc1 = r1[n]
                        mc2 = r2[n]
                        ex = exact
                        # @show exact, mc1, mc2
                        if !(p_value(mc1, exact) > alpha/nT || p_value(mc2, exact) > alpha/nT)
                            @show T
                            @show exact
                            @show mc1, p_value(mc1, exact)
                            @show mc2, p_value(mc2, exact)
                        end
                        @test p_value(mc1, exact) > alpha/nT || p_value(mc2, exact) > alpha/nT
                    end
                end
            end
        end
    end
end
