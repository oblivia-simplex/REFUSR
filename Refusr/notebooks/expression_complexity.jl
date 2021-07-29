### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ ee00763c-e881-4b95-adbe-d3e27113985c
begin
	using Pkg
	cd("$(ENV["HOME"])/src/refusr/Refusr")
	Pkg.activate(".")
	include("./src/base.jl")
end

# ╔═╡ 9a6ffb1e-6c43-4362-9674-ca1ce5ff32ed
using DataFrames

# ╔═╡ 40e64aa1-5ae3-4a81-ac27-578308fa865d
using Plots

# ╔═╡ fcda8305-597e-45fb-b0ee-489b83432eca
using Memoize

# ╔═╡ ba5492ba-c728-4593-a296-6c159e26be08
using LRUCache

# ╔═╡ 9f33cbc0-e907-4849-bf6f-03c3a2144091
using Statistics

# ╔═╡ cb4b55bb-88a5-4649-adda-abe8cb341922
using StatsPlots

# ╔═╡ 0b7bcd75-5a6f-4d40-b83b-939d6825d980
using Cockatrice

# ╔═╡ 8f8b27a1-905d-4c83-80d7-8e6abb142790
using ProgressMeter

# ╔═╡ a51005b4-efc7-11eb-30ab-eb893d783c0e
md"# Experiments in Expression Complexity and Simplification"

# ╔═╡ f0f982a7-f8ec-4397-b9a3-90b4bff8fe5d
Plots.plotly()

# ╔═╡ 0956c09b-5fb1-4cee-a24b-f47ffd0851fe
config = """
experiment_duration: 200
step_duration: 1
preserve_population: true
experiment: "2MUX-with-sharing"

selection:
  fitness_function: "fit"
  data: "./samples/2-MUX_overs-cohos-orbed_ALL.csv"
  d_fitness: 3
  t_size: 6
  fitness_sharing: true
  trace: true
  lexical: false

genotype:
  max_depth: 8
  min_len: 4
  max_len: 100
  data_n: 6
  registers_n: 4
  output_reg: 1
  max_steps: 512
  mutation_rate: 0.1

population:
  size: [8, 8]
  toroidal: true
  locality: 16
  n_elites: 10
  migration_rate: 0.2
  migration_type: "elite"

logging:
  log_every: 1
  save_every: 50

"""

# ╔═╡ a76d5fc1-4291-4b1c-9d68-3b6d3146795c
config_path = "/tmp/config.yaml"

# ╔═╡ ecc14b19-25e4-4035-b363-99c5103f59f3
write(config_path, config)

# ╔═╡ 516ee454-1f0a-4af3-a4c5-c0aef89138e7
evoL = mkevo(config_path)

# ╔═╡ afd46187-e022-495e-ba85-12dd0faf0b59
NAIVE_CACHE = LRU{String, Union{Bool, Expr, Symbol}}(maxsize=2^20, by=Base.summarysize)

# ╔═╡ 124c767a-9432-4741-8be9-2e1357e695bf
SIMPLE_CACHE = LRU{String, Union{Bool, Expr, Symbol}}(maxsize=2^20, by=Base.summarysize)

# ╔═╡ cf35faec-641d-4647-a95e-f2b6faf5fd19
function cache(C, g, expr)
	C[g.name] = expr
end

# ╔═╡ b2489697-3cc3-41cb-8824-b84f25ffe5c9
function check(C, g)
	try
		C[g.name]
	catch KeyError
		nothing
	end
end

# ╔═╡ 94a41066-5fdd-42c8-b857-c5cba8a9d669


# ╔═╡ ba3a2f95-13c6-4872-b50b-4929d946e13c
function naive_decompile(g)
	res = check(NAIVE_CACHE, g)
	!isnothing(res) && return res
	res = LinearGenotype.to_expr(g.chromosome, intron_free=false, incremental_simplify=false)
	cache(NAIVE_CACHE, g, res)
	return res
end

# ╔═╡ 6fdd166d-34e8-4a02-bf32-a64e11f5d28f
function simplifying_decompile(g)
	res = check(SIMPLE_CACHE, g)
	!isnothing(res) && return res
	res = LinearGenotype.to_expr(g.chromosome, intron_free=false, incremental_simplify=true)
	cache(SIMPLE_CACHE, g, res)
	return res
end
	

# ╔═╡ ed97922f-7b14-4696-94ef-0c82f4d5565d
function complexities(evo)
	N = naive_decompile.(evo.geo.deme)
	S = simplifying_decompile.(evo.geo.deme)
	Ndepth = Expressions.depth.(N)
	Nsub = Expressions.count_subexpressions.(N)
	Sdepth = Expressions.depth.(S)
	Ssub = Expressions.count_subexpressions.(S)
	return (naive_sub=Nsub, naive_depth=Ndepth, simple_sub=Ssub, simple_depth=Sdepth)
end
	
	

# ╔═╡ 3d3943a1-9210-46bc-b4e7-3f0a503230e6


# ╔═╡ e46860b7-ead9-4b00-b485-33e3c5c49288
function trace_complexities(evo, iter)
	evo = deepcopy(evo)
	function step(evo)
		res = complexities(evo)
		Cockatrice.Evo.step!(evo, eval_children=false)
		return res
	end
	@showprogress [step(evo) for i in 1:iter]
end

# ╔═╡ b879a116-fbc3-4f2e-a38d-2105fb0b8a7c


# ╔═╡ 13d59966-6e63-41c4-b751-fbf1c60e3260
#C = trace_complexities(evoL, 1000)

# ╔═╡ 2158af26-6d8c-4cf8-98ac-79351345e009
function process_complexity_data(data)
	[
		(	naive_sub_mean = mean(d.naive_sub),
			naive_depth_mean = mean(d.naive_depth),
			naive_sub_median = median(d.naive_sub),
			naive_depth_median = median(d.naive_depth),
			naive_sub_max = maximum(d.naive_sub),
			naive_depth_max = maximum(d.naive_depth),
		
			simple_sub_mean = mean(d.simple_sub),
			simple_depth_mean = mean(d.simple_depth),
			simple_sub_median = median(d.simple_sub),
			simple_depth_median = median(d.simple_depth),
			simple_sub_max = maximum(d.simple_sub),
			simple_depth_max = maximum(d.simple_depth),
		) for d in data
	] |> DataFrame
end

# ╔═╡ 4e51bcc8-baed-4824-bf99-dd8c5ca49f55


# ╔═╡ b0e48ee2-14a8-4a6b-ab5a-384e967cf068
C100 = trace_complexities(evoL, 100)

# ╔═╡ 933d59b8-0182-45e9-92cb-b9185243ed90
C100df = process_complexity_data(C100)

# ╔═╡ 9b48b200-7444-404a-bb05-04f20ffa65c2


# ╔═╡ d11d9526-a52e-4dde-bfbd-25eea4498507
C500 = trace_complexities(evoL, 500)

# ╔═╡ efe768a4-b30e-49b6-944f-789ad94db0ac
C500df = process_complexity_data(C500)

# ╔═╡ 114463d2-f6cf-42ba-bce2-7bb1b8c9ecd1
C1000 = trace_complexities(evoL, 1000)

# ╔═╡ 76fb464d-bf91-4cee-82a0-e83e6623b8cb
C1000df = process_complexity_data(C1000)

# ╔═╡ fb1e273e-9f16-4309-a8af-771b83782502
function complexity_plot(df)
	@df df plot(1:nrow(df),
	[:naive_sub_mean :naive_depth_mean :simple_sub_mean :simple_depth_mean], 
	label = ["mean subexpression count (naive)" "mean depth (naive)" "mean subexpression count (simplified)" "mean depth (simplified)"],
	ribbon = [:naive_sub_std :naive_depth_std :simple_sub_std :simple_depth_std],
	errorstyle = :ribbon,
	fillalpha = 0.2,
	legend = :topleft,
	xaxis = "Tournaments",
	w=3)
end

# ╔═╡ 576b7b0f-cf5e-42cb-980b-547264c6706a
fig1 = complexity_plot(C100df)

# ╔═╡ dec49b3c-216c-469c-997c-84cb1396a961
fig2 = complexity_plot(C500)

# ╔═╡ 3c23cc5e-3993-4ae3-81b1-a6f9442b1837
fig3 = complexity_plot(C1000)

# ╔═╡ e2bad96c-8fac-4c2f-b273-5cf2efdac7be
fig4 = complexity_plot(C1000[1:500,:])

# ╔═╡ ea36cb6c-4f8f-4cbb-8c52-0f521bac74a8
C1000

# ╔═╡ Cell order:
# ╠═a51005b4-efc7-11eb-30ab-eb893d783c0e
# ╠═9a6ffb1e-6c43-4362-9674-ca1ce5ff32ed
# ╠═f0f982a7-f8ec-4397-b9a3-90b4bff8fe5d
# ╠═ee00763c-e881-4b95-adbe-d3e27113985c
# ╠═40e64aa1-5ae3-4a81-ac27-578308fa865d
# ╠═fcda8305-597e-45fb-b0ee-489b83432eca
# ╠═ba5492ba-c728-4593-a296-6c159e26be08
# ╠═0956c09b-5fb1-4cee-a24b-f47ffd0851fe
# ╠═a76d5fc1-4291-4b1c-9d68-3b6d3146795c
# ╠═ecc14b19-25e4-4035-b363-99c5103f59f3
# ╠═516ee454-1f0a-4af3-a4c5-c0aef89138e7
# ╠═afd46187-e022-495e-ba85-12dd0faf0b59
# ╠═124c767a-9432-4741-8be9-2e1357e695bf
# ╠═cf35faec-641d-4647-a95e-f2b6faf5fd19
# ╠═b2489697-3cc3-41cb-8824-b84f25ffe5c9
# ╠═94a41066-5fdd-42c8-b857-c5cba8a9d669
# ╠═ba3a2f95-13c6-4872-b50b-4929d946e13c
# ╠═6fdd166d-34e8-4a02-bf32-a64e11f5d28f
# ╠═9f33cbc0-e907-4849-bf6f-03c3a2144091
# ╠═ed97922f-7b14-4696-94ef-0c82f4d5565d
# ╠═3d3943a1-9210-46bc-b4e7-3f0a503230e6
# ╠═cb4b55bb-88a5-4649-adda-abe8cb341922
# ╠═0b7bcd75-5a6f-4d40-b83b-939d6825d980
# ╠═8f8b27a1-905d-4c83-80d7-8e6abb142790
# ╠═e46860b7-ead9-4b00-b485-33e3c5c49288
# ╠═b879a116-fbc3-4f2e-a38d-2105fb0b8a7c
# ╠═13d59966-6e63-41c4-b751-fbf1c60e3260
# ╠═2158af26-6d8c-4cf8-98ac-79351345e009
# ╠═4e51bcc8-baed-4824-bf99-dd8c5ca49f55
# ╠═b0e48ee2-14a8-4a6b-ab5a-384e967cf068
# ╠═933d59b8-0182-45e9-92cb-b9185243ed90
# ╠═9b48b200-7444-404a-bb05-04f20ffa65c2
# ╠═d11d9526-a52e-4dde-bfbd-25eea4498507
# ╠═efe768a4-b30e-49b6-944f-789ad94db0ac
# ╠═114463d2-f6cf-42ba-bce2-7bb1b8c9ecd1
# ╠═76fb464d-bf91-4cee-82a0-e83e6623b8cb
# ╠═fb1e273e-9f16-4309-a8af-771b83782502
# ╠═576b7b0f-cf5e-42cb-980b-547264c6706a
# ╠═dec49b3c-216c-469c-997c-84cb1396a961
# ╠═3c23cc5e-3993-4ae3-81b1-a6f9442b1837
# ╠═e2bad96c-8fac-4c2f-b273-5cf2efdac7be
# ╠═ea36cb6c-4f8f-4cbb-8c52-0f521bac74a8
