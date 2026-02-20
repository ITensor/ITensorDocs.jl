using Aqua: Aqua
using ITensorDocs: ITensorDocs
using Test: @testset

@testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(ITensorDocs)
end
