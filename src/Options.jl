#TODO - eventually move some of these
# into the SR call itself, rather than
# passing huge options at once.

function binopmap(op)
    if op == plus
        return +
    elseif op == mult
        return *
    elseif op == sub
        return -
    elseif op == div
        return /
    elseif op == ^
        return pow
    end
    return op
end

function unaopmap(op)
    if op == log
        return log_abs
    elseif op == log10
        return log10_abs
    elseif op == log2
        return log2_abs
    elseif op == sqrt
        return sqrt_abs
    end
    return op
end

struct Options{A,B}

    binops::A
    unaops::B
    bin_constraints::Array{Tuple{Int,Int}, 1}
    una_constraints::Array{Int, 1}
    ns::Int
    parsimony::Float32
    alpha::Float32
    maxsize::Int
    maxdepth::Int
    fast_cycle::Bool
    migration::Bool
    hofMigration::Bool
    fractionReplacedHof::Float32
    shouldOptimizeConstants::Bool
    hofFile::String
    npopulations::Int
    nrestarts::Int
    perturbationFactor::Float32
    annealing::Bool
    batching::Bool
    batchSize::Int
    mutationWeights::Array{Float64, 1}
    warmupMaxsize::Int
    useFrequency::Bool
    npop::Int
    ncyclesperiteration::Int
    fractionReplaced::Float32
    topn::Int
    verbosity::Int
    probNegate::Float32
    nuna::Int
    nbin::Int
    seed::Union{Int, Nothing}

end

"""
    Options(;kws...)

Construct options for `EquationSearch` and other functions.

# Arguments
- `binary_operators::NTuple{nbin, Any}=(div, plus, mult)`: Tuple of binary
    operators to use. Each operator should be defined for two input scalars,
    and one output scalar. All operators need to be defined over the entire
    real line (excluding infinity - these are stopped before they are input).
    Thus, `log` should be replaced with `log_abs`, etc.
    For speed, define it so it takes two reals
    of the same type as input, and outputs the same type. For the SymbolicUtils
    simplification backend, you will need to define a generic method of the
    operator so it takes arbitrary types.
- `unary_operators::NTuple{nuna, Any}=(exp, cos)`: Same, but for
    unary operators (one input scalar, gives an output scalar).
- `batching=false`: Whether to evolve based on small mini-batches of data,
    rather than the entire dataset.
- `batchSize=50`: What batch size to use if using batching.
- `npopulations=nothing`: How many populations of equations to use. By default
    this is set equal to the number of cores
- `npop=1000`: How many equations in each population.
- `ncyclesperiteration=300`: How many generations to consider per iteration.
- `ns=10`: Number of equations in each subsample during regularized evolution.
- `topn=10`: Number of equations to return to the host process, and to
    consider for the hall of fame.
- `alpha=0.100000f0`: The probability of accepting an equation mutation
    during regularized evolution is given by exp(-delta_loss/(alpha * T)),
    where T goes from 1 to 0. Thus, alpha=infinite is the same as no annealing.
- `maxsize=20`: Maximum size of equations during the search.
- `maxdepth=nothing`: Maximum depth of equations during the search, by default
    this is set equal to the maxsize.
- `parsimony=0.000100f0`: A multiplicative factor for how much complexity is
    punished.
- `useFrequency=false`: Whether to use a parsimony that adapts to the
    relative proportion of equations at each complexity; this will
    ensure that there are a balanced number of equations considered
    for every complexity.
- `fast_cycle=false`: Whether to thread over subsamples of equations during
    regularized evolution. Slightly improves performance, but is a different
    algorithm.
- `migration=true`: Whether to migrate equations between processes.
- `hofMigration=true`: Whether to migrate equations from the hall of fame
    to processes.
- `fractionReplaced=0.1f0`: What fraction of each population to replace with
    migrated equations at the end of each cycle.
- `fractionReplacedHof=0.1f0`: What fraction to replace with hall of fame
    equations at the end of each cycle.
- `shouldOptimizeConstants=true`: Whether to use NelderMead optimization
    to periodically optimize constants in equations.
- `nrestarts=3`: How many different random starting positions to consider
    when using NelderMead optimization.
- `hofFile=nothing`: What file to store equations to, as a backup.
- `perturbationFactor=1.000000f0`: When mutating a constant, either
    multiply or divide by (1+perturbationFactor)^(rand()+1).
- `probNegate=0.01f0`: Probability of negating a constant in the equation
    when mutating it.
- `mutationWeights=[10.000000, 1.000000, 1.000000, 3.000000, 3.000000, 0.010000, 1.000000, 1.000000]`:
- `annealing=true`: Whether to use simulated annealing.
- `warmupMaxsize=0`: Whether to slowly increase the max size from 5 up to
    `maxsize`. If nonzero, specifies how many iterations before increasing
    by 1.
- `verbosity=convert(Int, 1e9)`: Whether to print debugging statements or
    not.
- `bin_constraints=nothing`:
- `una_constraints=nothing`:
- `seed=nothing`: What random seed to use. `nothing` uses no seed.
"""
function Options(;
    binary_operators::NTuple{nbin, Any}=(div, plus, mult),
    unary_operators::NTuple{nuna, Any}=(exp, cos),
    bin_constraints=nothing,
    una_constraints=nothing,
    ns=10, #1 sampled from every ns per mutation
    topn=10, #samples to return per population
    parsimony=0.000100f0,
    alpha=0.100000f0,
    maxsize=20,
    maxdepth=nothing,
    fast_cycle=false,
    migration=true,
    hofMigration=true,
    fractionReplacedHof=0.1f0,
    shouldOptimizeConstants=true,
    hofFile=nothing,
    npopulations=nothing,
    nrestarts=3,
    perturbationFactor=1.000000f0,
    annealing=true,
    batching=false,
    batchSize=50,
    mutationWeights=[10.000000, 1.000000, 1.000000, 3.000000, 3.000000, 0.010000, 1.000000, 1.000000],
    warmupMaxsize=0,
    useFrequency=false,
    npop=1000,
    ncyclesperiteration=300,
    fractionReplaced=0.1f0,
    verbosity=convert(Int, 1e9),
    probNegate=0.01f0,
    seed=nothing
   ) where {nuna,nbin}

    if hofFile == nothing
        hofFile = "hall_of_fame.csv" #TODO - put in date/time string here
    end

    if una_constraints == nothing
        una_constraints = [-1 for i=1:nuna]
    end
    if bin_constraints == nothing
        bin_constraints = [(-1, -1) for i=1:nbin]
    end

    if maxdepth == nothing
        maxdepth = maxsize
    end

    if npopulations == nothing
        npopulations = nworkers()
    end

    binary_operators = map(binopmap, binary_operators)
    unary_operators = map(unaopmap, unary_operators)

    mutationWeights = map((x,)->convert(Float64, x), mutationWeights)
    if length(mutationWeights) != 8
        error("Not the right number of mutation probabilities given")
    end

    for (op, f) in enumerate(map(Symbol, binary_operators))
        _f = if f == Symbol(pow)
            Symbol(^)
        else
            f
        end
        if !isdefined(Base, _f)
            continue
        end
        @eval begin
            Base.$_f(l::Node, r::Node)::Node = (l.constant && r.constant) ? Node($f(l.val, r.val)::AbstractFloat) : Node($op, l, r)
            Base.$_f(l::Node, r::AbstractFloat)::Node =        l.constant ? Node($f(l.val, r)::AbstractFloat)     : Node($op, l, r)
            Base.$_f(l::AbstractFloat, r::Node)::Node =        r.constant ? Node($f(l, r.val)::AbstractFloat)     : Node($op, l, r)
        end
    end

    for (op, f) in enumerate(map(Symbol, unary_operators))
        if !isdefined(Base, f)
            continue
        end
        @eval begin
            Base.$f(l::Node)::Node = l.constant ? Node($f(l.val)::AbstractFloat) : Node($op, l)
        end
    end

    Options{typeof(binary_operators),typeof(unary_operators)}(binary_operators, unary_operators, bin_constraints, una_constraints, ns, parsimony, alpha, maxsize, maxdepth, fast_cycle, migration, hofMigration, fractionReplacedHof, shouldOptimizeConstants, hofFile, npopulations, nrestarts, perturbationFactor, annealing, batching, batchSize, mutationWeights, warmupMaxsize, useFrequency, npop, ncyclesperiteration, fractionReplaced, topn, verbosity, probNegate, nuna, nbin, seed)
end


