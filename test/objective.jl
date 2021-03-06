struct DummyOptimizer <: MOI.AbstractOptimizer end
MOI.is_empty(::DummyOptimizer) = true

@testset "Unsupported objective_function" begin
    model = Model(with_optimizer(DummyOptimizer))
    func = MOI.SingleVariable(MOI.VariableIndex(1))
    @test_throws ErrorException JuMP.set_objective_function(model, func)
end

@testset "Unsupported function in macro" begin
    model = Model()
    @variable(model, x[1:2])
    exception = ErrorException("The objective function `VariableRef[x[1]," *
                               " x[2]]` is not supported by JuMP.")
    @test_throws exception @objective(model, Min, x)
end

function objectives_test(ModelType::Type{<:JuMP.AbstractModel}, VariableRefType::Type{<:JuMP.AbstractVariableRef})
    AffExprType = JuMP.GenericAffExpr{Float64, VariableRefType}
    QuadExprType = JuMP.GenericQuadExpr{Float64, VariableRefType}

    @testset "objective_sense set and get" begin
        model = ModelType()
        JuMP.set_objective_sense(model, MOI.FEASIBILITY_SENSE)
        @test JuMP.objective_sense(model) == MOI.FEASIBILITY_SENSE
    end

    @testset "SingleVariable objectives" begin
        m = ModelType()
        @variable(m, x)

        @objective(m, Min, x)
        @test JuMP.objective_sense(m) == MOI.MIN_SENSE
        @test JuMP.objective_function_type(m) == VariableRefType
        @test JuMP.objective_function(m) == x
        @test JuMP.objective_function(m, VariableRefType) == x

        @objective(m, Max, x)
        @test JuMP.objective_sense(m) == MOI.MAX_SENSE
        @test JuMP.objective_function_type(m) == VariableRefType
        @test JuMP.objective_function(m) == x
        @test JuMP.objective_function(m, VariableRefType) == x
    end

    @testset "Linear objectives" begin
        m = ModelType()
        @variable(m, x)

        @objective(m, Min, 2x)
        @test JuMP.objective_sense(m) == MOI.MIN_SENSE
        @test JuMP.objective_function_type(m) == AffExprType
        @test JuMP.isequal_canonical(JuMP.objective_function(m), 2x)
        @test JuMP.isequal_canonical(JuMP.objective_function(m, AffExprType), 2x)

        @objective(m, Max, x + 3x + 1)
        @test JuMP.objective_sense(m) == MOI.MAX_SENSE
        @test JuMP.objective_function_type(m) == AffExprType
        @test JuMP.isequal_canonical(JuMP.objective_function(m), 4x + 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(m, AffExprType), 4x + 1)
    end

    @testset "Quadratic objectives" begin
        m = ModelType()
        @variable(m, x)

        @objective(m, Min, x^2 + 2x)
        @test JuMP.objective_sense(m) == MOI.MIN_SENSE
        @test JuMP.objective_function_type(m) == QuadExprType
        @test JuMP.isequal_canonical(JuMP.objective_function(m), x^2 + 2x)
        @test JuMP.isequal_canonical(JuMP.objective_function(m, QuadExprType), x^2 + 2x)
        @test_throws InexactError JuMP.objective_function(m, AffExprType)
    end

    @testset "Sense as symbol" begin
        m = ModelType()
        @variable(m, x)

        @test_throws ErrorException @objective(m, :Min, 2x)
    end

    @testset "Sense in variable" begin
        m = ModelType()
        @variable(m, x)

        sense = MOI.MIN_SENSE
        @objective(m, sense, 2x)
        @test JuMP.objective_sense(m) == MOI.MIN_SENSE
        @test JuMP.isequal_canonical(JuMP.objective_function(m, AffExprType), 2x)

        sense = :Min
        @test_throws ErrorException @objective(m, sense, 2x)
    end
end


@testset "Objectives for JuMP.Model" begin
    objectives_test(Model, VariableRef)
end

@testset "Objectives for JuMPExtension.MyModel" begin
    objectives_test(JuMPExtension.MyModel, JuMPExtension.MyVariableRef)
end
