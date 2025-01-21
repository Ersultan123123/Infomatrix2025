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

function calculate_bandwidth(graph, permutation)
    max_bandwidth = 0
    for edge in edges(graph)
        u, v = permutation[src(edge)], permutation[dst(edge)]
        bandwidth = abs(u - v)
        max_bandwidth = max(max_bandwidth, bandwidth)
    end
    return max_bandwidth
end

function simulated_annealing(graph, initial_perm, initial_temp, cooling_rate, num_iterations)
    current_perm = initial_perm
    current_bandwidth = calculate_bandwidth(graph, current_perm)
    best_perm = copy(current_perm)
    best_bandwidth = current_bandwidth

    temp = initial_temp

    for i in 1:num_iterations
        new_perm = shuffle(current_perm)
        new_bandwidth = calculate_bandwidth(graph, new_perm)

        if new_bandwidth < current_bandwidth || exp((current_bandwidth - new_bandwidth) / temp) > rand()
            current_perm = new_perm
            current_bandwidth = new_bandwidth

            if new_bandwidth < best_bandwidth
                best_perm = new_perm
                best_bandwidth = new_bandwidth
            end
        end

        temp *= cooling_rate
    end

    return best_perm, best_bandwidth
end

function main(num_nodes=300, edge_multiplier=1.2, filename="g88.txt", initial_temp=100.0, cooling_rate=0.99, num_iterations=10000)
    graph, edges = setup(num_nodes, edge_multiplier, filename)
    num_nodes = nv(graph)
    nodes = create_nodes_vector(graph)

    initial_perm = shuffle(1:num_nodes)
    best_perm, best_bandwidth = simulated_annealing(graph, initial_perm, initial_temp, cooling_rate, num_iterations)

    println("Best Bandwidth: $best_bandwidth")
    println("Best Permutation: $best_perm")

    #viewgraph(graph, nodes)
end

main()
