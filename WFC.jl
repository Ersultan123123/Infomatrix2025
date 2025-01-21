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
        new_node = GraphNode(key, deg, 0, all_neighbors(graph, key), [], 0, 999999999, -999999999)
        push!(nodes, new_node)
    end
    return nodes
end

function wfc_permutation(nodes, graph)
    permutations = Vector{Vector{Int}}()
    for operations in 1:800
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
            #PROPAGATE
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
    end
    permutations = Set(permutations)
end

function main(num_nodes=100, edge_multiplier=1.2, filename="g28.txt")
    graph, edges = setup(num_nodes, edge_multiplier, filename)
    nodes = create_nodes_vector(graph)
    wfc_permutation(nodes, graph)
end

main()
