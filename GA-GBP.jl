
using Random
using StatsBase
using Combinatorics
using Colors
using DataStructures
using Graphs
using GraphPlot

mutable struct GraphNode
    key::Int
    degree::Int
    x::Int
    neighbors::Vector{Int}
end

function setup(num_nodes, edge_multiplier, filename)
    if filename == ""
        next_available_filename = get_filename()
        println("Using this input file: $next_available_filename")
        make_random_graph(next_available_filename, num_nodes, edge_multiplier)
    else
        next_available_filename = filename
    end
    edges = read_data(next_available_filename)
    edge_list = [Edge(e[1], e[2]) for e in edges]
    return SimpleGraph(edge_list), edges
end

function make_random_graph(filename, num_nodes, edge_multiplier)
    open("input_graphs/" * filename, "w") do f
        nodes = [x for x in 1:num_nodes]
        combos = collect(Combinatorics.combinations(nodes, 2))
        edges = collect(sample(combos, trunc(Int, edge_multiplier * num_nodes); replace=false))
        for edge in edges
            write(f, "$(edge[1]) $(edge[2]) \n")
        end
    end
end

function read_data(filename)
    edges = Tuple{Int,Int}[]
    io = open("input_graphs/" * filename, "r")
    for line in eachline(io)
        x, y = [parse(Int, ss) for ss in split(line)]
        t = Tuple([x, y])
        push!(edges, t)
    end
    close(io)
    return edges
end

function viewgraph(graph, nodes)
    custom_labels = [string(nodes[i].key) * "(" * string(nodes[i].x) * ")" for i in 1:length(nodes)]

    p = graphplot(graph,
        names=custom_labels,
        fontsize=14,
        nodelabeldist=5,
        nodelabelangleoffset=π / 4,
        markershape=:circle,
        markersize=0.08,
        markerstrokewidth=1,
        edgecolor=:gray,
        linewidth=5,
        curves=true
    )
    display(p)
end

function get_filename()
    biggest_number = 1
    while isfile("input_graphs/" * string('g') * string(biggest_number) * ".txt")
        biggest_number += 1
    end
    return string('g') * string(biggest_number) * ".txt"
end

function create_nodes_vector(graph)
    nodes = Vector{GraphNode}()
    num_vertices = nv(graph)
    for key in 1:num_vertices
        deg = length(all_neighbors(graph, key))
        domain = collect(1:num_vertices)
        new_node = GraphNode(key, deg, 0, all_neighbors(graph, key))
        push!(nodes, new_node)
    end
    return nodes
end

function initialize_population(num_nodes, population_size) #O(N * P_S)
    return [shuffle(1:num_nodes) for _ in 1:population_size]
end

function fitness(individual, edges)
    max_bandwidth = 0
    for (u, v) in edges
        max_bandwidth = max(max_bandwidth, abs(individual[u] - individual[v]))
    end
    return max_bandwidth
end

function selection(population, fitnesses, num_parents)
    selected_parents = []
    #lower the fitness, higher the weight
    for _ in 1:num_parents
        selected_parents = vcat(selected_parents, [sample(population, Weights(1 ./ fitnesses))])
        #vcat function adds selected parent to the selected_parents
    end
    return selected_parents
end

function crossover(parent1, parent2)
    n = length(parent1)
    crossover_point = rand(1:n-1)
    child1 = vcat(parent1[1:crossover_point], setdiff(parent2, parent1[1:crossover_point]))
    #[1, crossover_point]
    #setdiff ----> takes the  elements from parent2 that are not present in parent1
    #child1 concatenates the result
    child2 = vcat(parent2[1:crossover_point], setdiff(parent1, parent2[1:crossover_point]))
    return child1, child2
end

function mutation(individual, mutation_rate)
    if rand() < mutation_rate
        i, j = rand(1:length(individual)), rand(1:length(individual))
        #just making sure i != j, LOL))))
        while i == j
            j = rand(1:length(individual))
        end
        individual[i], individual[j] = individual[j], individual[i]
    end
    return individual
end

function genetic_algorithm(num_nodes, edges, population_size, num_generations, mutation_rate)
    population = initialize_population(num_nodes, population_size)
    for generation in 1:num_generations
        fitnesses = [fitness(individual, edges) for individual in population]
        best_fitness = minimum(fitnesses)
        #println("Generation $generation: Best fitness = $best_fitness")

        selected_parents = selection(population, fitnesses, population_size)
        next_population = []
        for i in 1:2:population_size-1
            parent1 = selected_parents[i]
            parent2 = selected_parents[i+1]
            child1, child2 = crossover(parent1, parent2)
            push!(next_population, mutation(child1, mutation_rate))
            push!(next_population, mutation(child2, mutation_rate))
        end
        population = next_population
    end
    final_fitnesses = [fitness(individual, edges) for individual in population]
    best_individual = population[argmin(final_fitnesses)]
    return best_individual, minimum(final_fitnesses)
end

function main(num_nodes=1000, edge_multiplier=1.2, filename="g72.txt")
    graph, edges = setup(num_nodes, edge_multiplier, filename)
    nodes = create_nodes_vector(graph)
    num_nodes = nv(graph)
    #viewgraph(graph, nodes)
    population_size = 100
    num_generations = 50
    mutation_rate = 0.01
    min_ans = nv(graph)
    sum, cnt = 0, 0
    minn = 99999999
    for rep in 1:10
        best_individual, best_fitness = genetic_algorithm(num_nodes, edges, population_size, num_generations, mutation_rate)
        #println("Best individual: $best_individual with fitness: $best_fitness")
        sum += best_fitness
        minn = min(minn, best_fitness)
        cnt += 1
    end
    minn = ceil(sum / cnt)
    print("MINIMUM RESULT: $minn")
end

main()