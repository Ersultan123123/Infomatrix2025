#abstract -> introduction -> conclusion(result)

using Random
using StatsBase
using Combinatorics
using Colors
using DataStructures
using LightGraphs
using GraphPlot

mutable struct GraphNode
    key::Int
    degree::Int
    label::Int
    neighbors::Vector{Int}
    domain::Vector{Int}
    colored::Int
    min::Int
    max::Int
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
    custom_labels = [string(nodes[i].key) * "(" * string(nodes[i].label) * ")" for i in 1:length(nodes)]

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
        new_node = GraphNode(key, deg, 0, all_neighbors(graph, key), [], 0, 999999999, -999999999)
        push!(nodes, new_node)
    end
    return nodes
end

function wfc_permutation(nodes, graph)
    permutations = Vector{Vector{Int}}()
    for operations in 1:80
        labels = collect(1:nv(graph))
        final = []
        pq = PriorityQueue{Int,Tuple{Int,Int}}()
        for i in 1:nv(graph)
            pq[i] = (-nodes[i].degree, -nodes[i].colored)
        end
        while !isempty(pq)
            #OBSERVE
            (key, (degree, colored)) = peek(pq)
            delete!(pq, key)
            #COLLAPSE
            random_value = rand(0:1)
            if length(labels) % 2 == 1
                index = Int((length(labels) + 1) / 2)
                selected_label = labels[index]
                push!(final, selected_label)
                deleteat!(labels, index)
                nodes[key].label = selected_label
            else
                #1, 2, 3, 4, 5, 6
                #3 + 0/1
                index = Int(length(labels) / 2) + random_value
                selected_label = labels[index]
                push!(final, selected_label)
                deleteat!(labels, index)
                nodes[key].label = selected_label
            end
            for neighbor in nodes[key].neighbors
                nodes[neighbor].colored += 1
                nodes[neighbor].min = min(nodes[neighbor].min, nodes[key].label)
                nodes[neighbor].max = max(nodes[neighbor].max, nodes[key].label)
            end
            #PROPAGATE --> WFC
            for v in 1:nv(graph)
                if nodes[v].label == 0 && length(nodes[v].neighbors) == nodes[v].colored
                    cnt, label_index = 0, 0
                    for i in 1:length(labels)
                        if nodes[v].min <= labels[i] && labels[i] <= nodes[v].max
                            cnt += 1
                            label_index = i
                        end
                    end
                    if cnt == 1
                        nodes[v].label = labels[label_index]
                        deleteat!(labels, label_index)
                    end
                end
            end
        end
        push!(permutations, final)
        for i in 1:nv(graph)
            nodes[i].colored = 0
            nodes[i].min = 999999999
            nodes[i].max = -999999999
            nodes[i].label = 0
        end
    end
    unique_permutations = []
    for permutation in permutations
        if !(permutation in unique_permutations)
            push!(unique_permutations, permutation)
        end
    end
    return unique_permutations
end

function initialize_population(nodes, graph, population_size) #O(N * P_S)
    population = wfc_permutation(nodes, graph)
    while length(population) < population_size
        random_population = shuffle(1:nv(graph))
        push!(population, random_population)
    end
    return population
end

function fitness(individual, edges)
    max_bandwidth = 0
    for (u, v) in edges
        max_bandwidth = max(max_bandwidth, abs(individual[u] - individual[v]))
    end
    return max_bandwidth
end

# 1 / max_bandwidth
#population -> 1 4 5 3 2 6 --> bandwidth = 3 -> 1 / 3
#max difference for each v -> value ^ k --> for all v -> sum -> 1 / sum
#(avg) 
#min -> max 1 / bandwidth

#1 to 1000000

#1 4 5 3 2 6 -> 3
#1 2 5 4 6 3 -> 3
# 1000 -> n - 1 
#min -> 1 max -> n - 1

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

function genetic_algorithm(nodes, graph, num_nodes, edges, population_size, num_generations, mutation_rate)
    population = initialize_population(nodes, graph, population_size)
    min_answer = 9999999999
    for generation in 1:num_generations
        fitnesses = [fitness(individual, edges) for individual in population]
        best_fitness = minimum(fitnesses)
        #println("Generation $generation: Best fitness = $best_fitness")
        min_answer = min(min_answer, best_fitness)
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
    return best_individual, min_answer
end

function main(num_nodes=300, edge_multiplier=1.2, filename="g72.txt")

    graph, edges = setup(num_nodes, edge_multiplier, filename)
    num_nodes = nv(graph)
    nodes = create_nodes_vector(graph)
    #viewgraph(graph, nodes)
    population_size = 100
    #DO NOT FORGET TO CHANGE THE FRACTION OF WFC
    num_generations = 50
    mutation_rate = 0.01

    min_ans = nv(graph)
    sum, cnt = 0, 0
    minn = 99999999
    for rep in 1:10
        best_individual, best_fitness = genetic_algorithm(nodes, graph, num_nodes, edges, population_size, num_generations, mutation_rate)
        #println("Best individual: $best_individual with fitness: $best_fitness")
        sum += best_fitness
        minn = min(minn, best_fitness)
        cnt += 1
    end
    print("MINIMUM RESULT: $minn \n")
end

main()