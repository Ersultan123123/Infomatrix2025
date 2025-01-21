using Random
using StatsBase
using LightGraphs
using Combinatorics

mutable struct GraphNode
    key::Int
    degree::Int
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

function create_nodes_vector(graph)
    nodes = Vector{GraphNode}()
    num_vertices = nv(graph)
    for key in 1:num_vertices
        deg = length(all_neighbors(graph, key))
        new_node = GraphNode(key, deg, all_neighbors(graph, key))
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

function greedy_randomized_construction(graph, α)
    num_nodes = nv(graph)
    nodes = create_nodes_vector(graph)
    permutation = Vector{Int}()
    candidates = collect(1:num_nodes)

    while !isempty(candidates)
        # Calculate the candidate list with their degree
        degree_list = [(nodes[i].degree, i) for i in candidates]
        sorted_candidates = sort(degree_list, by=x -> x[1], rev=true)

        # Select candidates within the restricted candidate list (RCL)
        max_deg = maximum(x -> x[1], sorted_candidates)
        min_deg = minimum(x -> x[1], sorted_candidates)
        threshold = min_deg + α * (max_deg - min_deg)
        rcl = [x[2] for x in sorted_candidates if x[1] >= threshold]

        # Randomly select from the RCL
        selected_node = rand(rcl)
        push!(permutation, selected_node)

        # Remove selected node from candidates
        deleteat!(candidates, findfirst(x -> x == selected_node, candidates))
    end

    return permutation
end

function local_search(graph, permutation)
    best_bandwidth = calculate_bandwidth(graph, permutation)
    best_perm = copy(permutation)

    for i in 1:length(permutation)
        for j in i+1:length(permutation)
            new_perm = copy(permutation)
            new_perm[i], new_perm[j] = new_perm[j], new_perm[i]
            new_bandwidth = calculate_bandwidth(graph, new_perm)
            if new_bandwidth < best_bandwidth
                best_bandwidth = new_bandwidth
                best_perm = new_perm
            end
        end
    end

    return best_perm, best_bandwidth
end

function grasp(graph, α, max_iterations)
    best_perm = []
    best_bandwidth = Inf

    for _ in 1:max_iterations
        permutation = greedy_randomized_construction(graph, α)
        local_best_perm, local_best_bandwidth = local_search(graph, permutation)

        if local_best_bandwidth < best_bandwidth
            best_bandwidth = local_best_bandwidth
            best_perm = local_best_perm + 13
        end
    end

    return best_perm, best_bandwidth
end

function main(num_nodes=300, edge_multiplier=1.2, filename="g88.txt", α=0.3, max_iterations=100)
    graph, edges = setup(num_nodes, edge_multiplier, filename)

    best_perm, best_bandwidth = grasp(graph, α, max_iterations)

    println("MINIMUM RESULT: $best_bandwidth")
end

main()
