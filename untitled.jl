using JuMP
using GLPK
using MAT
using CSV
using DataFrames
using Distributions

# Define the model
model = Model(GLPK.Optimizer)



# Load data from MATLAB file
# Load the .mat file
mat_data = matread("c:/Users/HP/OneDrive - Imperial College London/Planning for Extreme Weather event/Senario generation/line_failing_prob.mat")

# Access the 3D variable
line_failing_prob = mat_data["line_failing_prob"]
harden_fail = line_failing_prob ./ 10
# Check the size of the variable
println(size(line_failing_prob))


# Load the Excel file
df = CSV.read("C:/Users/HP/OneDrive - Imperial College London/Planning for Extreme Weather event/optimisation/IEEE 33.csv",DataFrame)


# Convert DataFrame columns to arrays for easier use
branch_no = df[!, "Branch No"]
sending_end = df[!, "Sending End"]
receiving_end = df[!, "Receiving End"]
R = df[!, "R (ohms)"]
X = df[!, "X (ohms)"]
PL = df[!, "PL (kW)"]
PL = [0;PL]
QL = df[!, "QL (kVAR)"]
QL = [0;QL]

# Define sets
ΩN = 1:33  # Example set of buses
ΩB = 1:33  # Example set of lines
#ΩDG = 1:5  # Example set of buses with DGs
#ΩSW = 1:10  # Example set of lines with switches
T = 0:2:12  # Example set of time periods
S = 1:300  # Example set of scenarios
P = 1:3   # Example set of paths

# Define parameters (replace these with actual values)
#cc = Dict((i, j) => 10.0 for i in ΩB, j in ΩB) #annual capital cost for adding an automatic switch
ch = Dict((i) => 2000.0 for i in ΩB) #hardening lines
#cg = Dict(i => 100.0 for i in ΩDG) #deploying a back-up DG
cL = Dict(i => 14.0 for i in ΩN) #penalty cost for load-shedding
cR0 = 1000.0 #base repair cost
ωH = 2.0 #average occurance per year
pr = fill(1.0/(length(P)*length(S)), length(P), length(S)) #every senario havinf same probabilities
#pr = Dict(s => 0.1 for s in S)  # Example scenario probabilities
#PL = Dict((i, t, s) => rand(100:200) for i in ΩN, t in T, s in S)  # Example loads
#QL = Dict((i, t, s) => rand(50:100) for i in ΩN, t in T, s in S)  # Example reactive loads

# Example parameters (replace with actual values)
ζ0 = Dict((i, t, p, s) => rand(Bernoulli(line_failing_prob[i, p, s])) for i in ΩB, t in T, p in P,  s in S)
ζ1 = Dict((i, t, p, s) => rand(Bernoulli(harden_fail[i, p, s])) for i in ΩB, t in T, s in S, p in P)
# Print keys for debugging
#println("Keys in ζ0: ", keys(ζ0))
#println("Keys in ζ1: ", keys(ζ1))

# Define first-stage variables
#@variable(model, xg[i in ΩDG], Bin) #new back-up DG
@variable(model, xh[i in ΩB], Bin) #hardening
#@variable(model, xc[i in ΩB, j in ΩB], Bin) #line switch
#@variable(model, xc1[i in ΩB, j in ΩB], Bin) #new line switch


# Define second-stage variables
@variable(model, γ[i in ΩN, t in T, p in P, s in S] >= 0)  # Load shedding percentage
@variable(model, u[i in ΩB, t in T, p in P, s in S], Bin)  # Line damage status
println("I stop at second-stage cost variables")
# Define second-stage cost components
@expression(model, repair_cost, sum(cR0 * u[i, t, p, s] for i in ΩB, j in ΩB, t in T, p in P,  s in S))
#@expression(model, load_shedding_cost, sum(cL[i] * γ[i, t, p, s] * PL[i] for i in ΩN, t in T, s in S, p in P)) #key not found
println("I stop at second-stage cost components")

# Objective function
@objective(model, Min, sum(ch[i] * xh[i] for i in ΩB) +
                        #sum(cg[i] * xg[i] for i in ΩDG) +
                        #sum(cc[i, j] * xc1[i, j] for i in ΩB, j in ΩB) +
                        ωH * sum(pr[p, s] * (repair_cost) for p in P, s in S))

# Constraints
#@constraint(model, sum(xg[i] for i in ΩDG) <= length(ΩDG))  # Example constraint for DGs
println("aaa")
#@constraint(model, [i in ΩB, j in ΩB], xc[i, j] == xc1[i, j])  # Example constraint for switches
@constraint(model, [i in ΩB, t in T, s in S, p in P],
    u[i, t, p, s] == (1 - xh[i]) * ζ0[i, t, p, s] + xh[i] * ζ1[i, t, p, s])

# Add other constraints for power flow, voltage limits, and so on
println("where is my constraint")
# Solve the model
optimize!(model)

# Print the results
println("Objective value: ", objective_value(model))
for i in ΩB
    if xh[i] != 0.0
        println("xh[$i] = ", value(xh[i]))  
    end
end
