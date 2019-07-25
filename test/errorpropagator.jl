@testset "Constructors and basic properties" begin
    # numbers
    for T in (Float64, ComplexF64)
        B = ErrorPropagator(T)

        @test length(B) == 0
        @test ndims(B) == 0
        @test isempty(B)
        @test eltype(B) == T
        @test capacity(B) == 2^32 - 1
        @test BinningAnalysis.nlevels(B) == 32

        append!(B, rand(1000))
        @test length(B) == 1000
        @test !isempty(B)

        empty!(B)
        @test length(B) == 0
        @test isempty(B)
    end

    # arrays
    for T in (Float64, ComplexF64)
        B = ErrorPropagator(zeros(T, 2, 3))

        @test length(B) == 0
        @test ndims(B) == 2
        @test isempty(B)
        @test eltype(B) == Array{T, 2}
        @test capacity(B) == 2^32 - 1
        @test BinningAnalysis.nlevels(B) == 32

        append!(B, [rand(T, 2,3) for _ in 1:1000])
        @test length(B) == 1000
        @test !isempty(B)
        empty!(B)
        @test length(B) == 0
        @test isempty(B)
    end

    # Constructor arguments
    B = ErrorPropagator(capacity=12345)
    @test capacity(B) == 16383
    @test_throws ArgumentError ErrorPropagator(capacity=0)
    @test_throws ArgumentError ErrorPropagator(capacity=-1)


    # Test error on overflow
    B = ErrorPropagator(capacity=1)
    push!(B, 1.0)
    @test_throws OverflowError push!(B, 2.0)

    B = ErrorPropagator(zeros(2,2), capacity=1)
    push!(B, rand(2,2))
    @test_throws OverflowError push!(B, rand(2,2))

    # time series constructor (#26)
    x = rand(10)
    B = ErrorPropagator(x)
    @test length(B) == 10
    @test mean(B, 1) == mean(x)

    x = [rand(2,3) for _ in 1:5]
    B = ErrorPropagator(x)
    @test length(B) == 5
    @test mean(B, 1) == mean(x)
end



@testset "Checking converging data (Real)" begin
    BA = ErrorPropagator()

    # block of maximally correlated values:
    N_corr = 16

    # number of blocks
    N_blocks = 131_072 # 2^17

    for _ in 1:N_blocks
        x = rand()
        for __ in 1:N_corr
            push!(BA, x)
        end
    end

    # # BA must diverge until 16 values are binned
    # for lvl in 1:4
    #     @test !has_converged(BA, lvl)
    # end
    #
    # # Afterwards it must converge (for a while)
    # for lvl in 5:8
    #     @test has_converged(BA, lvl)
    # end
    # # Later values may fluctuate due to small samples / small threshold in
    # # has_converged

    # means should be consistent
    means = BinningAnalysis.all_means(BA)
    for x in means
        @test x[1] ≈ means[1][1]
    end
end



@testset "Check variance for complex values" begin
    # NOTE
    # Due to the different (mathematically equivalent) versions of the variance
    # calculated here, the values are onyl approximately the same. (Float error)
    Random.seed!(1234)
    xs = rand(ComplexF64, 1_000_000)
    BA = ErrorPropagator(ComplexF64)

    # Test small set (off by one errors are large here)
    for x in xs[1:10]; push!(BA, x) end
    @test var(BA, 1, 1) ≈ var(xs[1:10])
    @test varN(BA, 1, 1) ≈ var(xs[1:10])/10

    # Test full set
    for x in xs[11:end]; push!(BA, x) end
    @test var(BA, 1, 1) ≈ var(xs)
    @test varN(BA, 1, 1) ≈ var(xs)/1_000_000

    # all_* methods
    @test isapprox(first.(all_vars(BA)), [0.16671474067121222, 0.08324845751233179, 0.041527133392489035, 0.020847602123934883, 0.010430741538377142, 0.005111097271805531, 0.0025590988213273214, 0.001283239131297187, 0.0006322480081128456, 0.0003060164750540162, 0.00015750782337442537, 8.006142368921498e-5, 3.810111634139357e-5, 1.80535512880331e-5, 1.0002438211476061e-5, 5.505102193326117e-6, 2.8788397929968568e-6, 1.7242475507384114e-6, 7.900888818745955e-7])
    @test isapprox(first.(all_varNs(BA)), zero(first.(all_varNs(BA))), atol=1e-6)
    @test isapprox(first.(all_taus(BA)), [0.0, -0.00065328850247931, -0.0018180968845809553, 0.00019817179932868356, 0.0005312186016332987, -0.009476150581268994, -0.008794711536776634, -0.007346737569564443, -0.014542478848703244, -0.030064159934323653, -0.01599670814224563, -0.007961042363178128, -0.03167873601168558, -0.056188229083248886, -0.008218660661725774, 0.05035147373711113, 0.0756019296606737, 0.2387501479629205, 0.289861051172009])
    @test isapprox(first.(all_std_errors(BA)), [0.0004083071646092097, 0.0004080403350462593, 0.00040756414657076514, 0.0004083880715587553, 0.0004085240073900606, 0.00040441947616030687, 0.00040470028980091994, 0.0004052963382191276, 0.00040232555162611277, 0.00039584146247874917, 0.00040172249945971054, 0.00040504357104527986, 0.00039516087376314515, 0.0003846815937765092, 0.00040493752222959487, 0.0004283729758565588, 0.00043808977717638777, 0.0004963074437049236, 0.0005131890106236348])

    @test isapprox(tau(BA, 1), -0.008218660661725774)
    @test isapprox(std_error(BA, 1), 0.00040493752222959487)
end



@testset "Check variance for complex vectors" begin
    Random.seed!(1234)
    xs = [rand(ComplexF64, 3) for _ in 1:1_000_000]
    BA = ErrorPropagator(zeros(ComplexF64, 3))

    # Test small set (off by one errors are large here)
    for x in xs[1:10]; push!(BA, x) end
    @test var(BA, 1, 1) ≈ var(xs[1:10])
    @test varN(BA, 1, 1) ≈ var(xs[1:10])/10

    # Test full set
    for x in xs[11:end]; push!(BA, x) end
    @test var(BA, 1, 1) ≈ var(xs)
    @test varN(BA, 1, 1) ≈ var(xs)/1_000_000

    # all_std_errors for <:AbstractArray
    @test all(isapprox.(first.(all_std_errors(BA)), Ref(zeros(3)), atol=1e-2))

    @test all(isapprox.(tau(BA, 1), [-0.101203, -0.0831874, -0.0112827], atol=1e-6))
    @test all(isapprox.(std_error(BA, 1), [0.000364498, 0.00037268, 0.000403603], atol=1e-6))
end



@testset "Checking converging data (Complex)" begin
    BA = ErrorPropagator(ComplexF64)

    # block of maximally correlated values:
    N_corr = 16

    # number of blocks
    N_blocks = 131_072 # 2^17

    for _ in 1:N_blocks
        x = rand(ComplexF64)
        for __ in 1:N_corr
            push!(BA, x)
        end
    end

    # # BA must diverge until 16 values are binned
    # for lvl in 1:4
    #     @test !has_converged(BA, lvl)
    # end
    #
    # # Afterwards it must converge (for a while)
    # for lvl in 5:8
    #     @test has_converged(BA, lvl)
    # end
    # # Later values may fluctuate due to small samples / small threshold in
    # # has_converged

    # means should be consistent
    means = BinningAnalysis.all_means(BA)
    for x in means
        @test x[1] ≈ means[1][1]
    end
end



@testset "Checking converging data (Vector)" begin
    BA = ErrorPropagator(zeros(3))

    # block of maximally correlated values:
    N_corr = 16

    # number of blocks
    N_blocks = 131_072 # 2^17

    for _ in 1:N_blocks
        x = rand(Float64, 3)
        for __ in 1:N_corr
            push!(BA, x)
        end
    end

    # # BA must diverge until 16 values are binned
    # for lvl in 1:4
    #     @test !has_converged(BA, lvl)
    # end
    #
    # # Afterwards it must converge (for a while)
    # for lvl in 5:8
    #     @test has_converged(BA, lvl)
    # end
    # # Later values may fluctuate due to small samples / small threshold in
    # # has_converged

    # means should be consistent
    means = BinningAnalysis.all_means(BA)
    for x in means
        @test x[1] ≈ means[1][1]
    end
end



@testset "Type promotion" begin
    Bf = ErrorPropagator(zero(1.)) # Float64 ErrorPropagator
    Bc = ErrorPropagator(zero(im)) # Float64 ErrorPropagator

    # Check that this doesn't throw (TODO: is there a better way?)
    @test (append!(Bf, rand(1:10, 10000)); true)
    @test (append!(Bc, rand(10000)); true)
end



@testset "Sum-type heuristic" begin
    # numbers
    @test typeof(ErrorPropagator(zero(Int64))) == ErrorPropagator{Float64, 32}
    @test typeof(ErrorPropagator(zero(ComplexF16))) == ErrorPropagator{ComplexF64, 32}

    # arrays
    @test typeof(ErrorPropagator(zeros(Int64, 2,2))) == ErrorPropagator{Matrix{Float64}, 32}
    @test typeof(ErrorPropagator(zeros(ComplexF16, 2,2))) == ErrorPropagator{Matrix{ComplexF64}, 32}
end



@testset "Indexing Bounds" begin
    BA = ErrorPropagator(zero(Float64); capacity=1)
    for func in [:var, :varN, :mean, :tau]
        # check if func(BA, 0) throws BoundsError
        # It should as level 1 is now the initial level
        @test_throws BoundsError @eval $func($BA, 1, 0)
        # Check that level 1 exists
        @test (@eval $func($BA, 1, 1); true)
        # Check that level 2 throws BoundsError
        @test_throws BoundsError @eval $func($BA, 1, 2)
    end
end



@testset "_reliable_level" begin
    BA = ErrorPropagator()
    # Empty Binner
    @test BinningAnalysis._reliable_level(BA) == 1
    @test isnan(std_error(BA, 1, BinningAnalysis._reliable_level(BA)))

    # One Element should still return NaN (due to 1/(n-1))
    push!(BA, rand())
    @test BinningAnalysis._reliable_level(BA) == 1
    @test isnan(std_error(BA, 1, BinningAnalysis._reliable_level(BA)))

    # Two elements should return some value
    push!(BA, rand())
    @test BinningAnalysis._reliable_level(BA) == 1
    @test !isnan(std_error(BA, 1, BinningAnalysis._reliable_level(BA)))

    # same behavior up to (including) 63 values (31 binned in first binned lvl)
    append!(BA, rand(61))
    @test BinningAnalysis._reliable_level(BA) == 1
    @test !isnan(std_error(BA, 1, BinningAnalysis._reliable_level(BA)))

    # at 64 or more values, the lvl should be increasing
    push!(BA, rand())
    @test BinningAnalysis._reliable_level(BA) == 2
    @test !isnan(std_error(BA, 1, BinningAnalysis._reliable_level(BA)))
end



@testset "Cosmetics (show, print, etc.)" begin
    B = ErrorPropagator();
    # empty binner
    io = IOBuffer()
    println(io, B) # compact
    show(io, MIME"text/plain"(), B) # full


    # compact
    l = String(take!(io))
    @test l == "ErrorPropagator{Float64,32}()\nErrorPropagator{Float64,32}\n| Count: 0"
    @test length(readlines(io)) == 0


    # filled binner
    Random.seed!(1234)
    append!(B, rand(1000))
    show(io, MIME"text/plain"(), B)

    l = String(take!(io))
    @test l == "ErrorPropagator{Float64,32}\n| Count: 1000\n| Means: [0.49685]\n| StdErrors: [0.00733]"
    @test length(readlines(io)) == 0
    close(io);
end


@testset "Error Propagation" begin
    g(x1, x2) = x1^2 - x2
    g(v) = v[1]^2 - v[2]
    grad_g(x1, x2) = [2x1, -1.0]
    grad_g(v) = [2v[1], -1.0]

    # derivative of identity is x -> 1
    grad_identity(v) = 1

    # Real
    # comparing to results from mean(ts), std(ts)/sqrt(10) (etc)
    ts = [0.00124803, 0.643089, 0.183268, 0.799899, 0.0857666, 0.955348, 0.165763, 0.765998, 0.63942, 0.308818]
    ts2 = [0.606857, 0.0227746, 0.805997, 0.978731, 0.0853112, 0.311463, 0.628918, 0.0190664, 0.515998, 0.0223728]
    ep = ErrorPropagator(ts)
    @test isapprox(mean(ep, 1), 0.454861763, atol=1e-12)
    @test isapprox(std_error(ep, grad_identity, 1), 0.10834619757501408, atol=1e-12)
    # check consistency with Julia's Statistics
    @test std_error(ep, grad_identity, 1) ≈ std(ts)/sqrt(length(ts))

    ep = ErrorPropagator(1 ./ ts)
    @test isapprox(mean(ep, 1), 83.43709884072862, atol=1e-12)
    @test isapprox(std_error(ep, grad_identity, 1), 79.76537738034834, atol=1e-12)

    ep = ErrorPropagator(ts, ts2.^2)
    @test isapprox(g(means(ep)...), -0.07916794438503649, atol=1e-12)
    # Adjust error or atol here
    @test isapprox(std_error(ep, grad_g, 1), 0.14501699232741938, atol=1e-12)


    # Complex
    ts = Complex{Float64}[0.0259924+0.674798im, 0.329853+0.558688im, 0.821612+0.142805im, 0.0501703+0.801068im, 0.0309707+0.877745im, 0.937856+0.852463im, 0.669084+0.606286im, 0.887004+0.431615im, 0.763452+0.210563im, 0.678384+0.428294im]
    ts2 = Complex{Float64}[0.138147+0.11007im, 0.484956+0.127761im, 0.986078+0.702827im, 0.45161+0.878256im, 0.768398+0.954537im, 0.228518+0.260732im, 0.256892+0.437918im, 0.647672+0.749172im, 0.0587658+0.408715im, 0.0792651+0.288578im]
    ep = ErrorPropagator(ts)
    @test isapprox(mean(ep, 1), 0.51943784 + 0.5584325im, atol=1e-12)
    @test isapprox(std_error(ep, grad_identity, 1), 0.14286073531999163, atol=1e-12)
    # check consistency with Julia's Statistics
    @test std_error(ep, grad_identity, 1) ≈ std(ts)/sqrt(length(ts))

    ep = ErrorPropagator(1 ./ ts)
    @test isapprox(mean(ep, 1), 0.6727428408881814 - 0.8112743686359858im, atol=1e-12)
    @test isapprox(std_error(ep, grad_identity, 1), 0.2047347223258764, atol=1e-12)

    ep = ErrorPropagator(ts, ts2.^2)
    @test isapprox(g(means(ep)...), 0.021446672721215643 + 0.06979705636190503im, atol=1e-12)
    @test isapprox(std_error(ep, grad_g, 1), 0.2752976586383889, atol=1e-12)
end