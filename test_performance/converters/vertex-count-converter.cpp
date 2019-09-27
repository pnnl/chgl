#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <utility>
#include <cassert>
#include <algorithm>
#include <limits>
#include <mutex>
#include <map>
#include <regex>

typedef unsigned long long ve_type;
typedef uint64_t IndexType;
std::string edgelistFile = "";

using element = std::tuple<ve_type, ve_type>;
template<typename Adjacencies, typename Vertex>
void update_adjacencies(Adjacencies& adj, Vertex src, Vertex dst) {
    //  std::cout << "Updating link " << src << " " << dst << "\n";
    if (src >= adj.size()) {
        adj.resize(src + 1);
        adj.back().first = src;
    }
    adj[src].second.push_back(dst);
}

template<typename Sequence>
size_t clean_sort(Sequence& adjacencies, std::vector<IndexType>& offsets,
        IndexType num_edges, size_t &newEdges) {
    size_t removed_count{0};
    for (auto& adj_pair : adjacencies) {
        auto& adj_list = adj_pair.second;
        std::sort(adj_list.begin(), adj_list.end());
        auto last = std::unique(adj_list.begin(), adj_list.end());
        removed_count += adj_list.end() - last;
        adj_list.erase(last, adj_list.end());
        num_edges += adj_list.size();
        offsets.push_back(num_edges);
    }
    newEdges = num_edges;
    return removed_count;
}


int main(int argc, char* argv[]) {
    ve_type nVertices, nEdges;
    ve_type source;
    unsigned argIndex = 1;
    std::string arg_t(argv[argIndex]);

    while (argIndex < argc) {
        std::string arg(argv[argIndex]);
        if (arg == "--edgelistfile") {
            ++argIndex;
            edgelistFile = std::string(argv[argIndex]);
            ++argIndex;
        }

    }
    // edgelist                                                           
    IndexType max_vertex_id{0};
    std::map<IndexType, IndexType> vertex_old_new_map;
    std::vector<std::pair<IndexType, std::vector<IndexType>>> vertex_adjacencies;

    IndexType num_links = 0;
    IndexType vrt, edg;
    // std::ifstream infile(edgelistFile);
    IndexType next_vertex_id{0}, next_edge_id{0};
    std::string line;

    std::string              string_input;
    bool                     file_symmetry = false;
    std::vector<std::string> header(5);
    std::ifstream inputFile(edgelistFile);
    std::getline(inputFile, string_input);
    std::stringstream h(string_input);
    for (auto& s : header)
        h >> s;

    if (header[0] != "%%MatrixMarket") {
        std::cerr << "Unsupported format" << std::endl;
        throw;
    }
    if (header[4] == "symmetric") {
        file_symmetry = true;
    } else if (header[4] == "general") {
        file_symmetry = false;
    } else {
        std::cerr << "Bad format (symmetry): " << header[4] << std::endl;
        throw;
    }

    while (std::getline(inputFile, string_input)) {
        if (string_input[0] != '%') break;
    }
    size_t n0, n1, nNonzeros;
    std::stringstream(string_input) >> n0 >> n1 >> nNonzeros;

    //assert(n0 == n1);
    nVertices = n0;
    nEdges = nNonzeros;

    for (size_t i = 0; i < nNonzeros; ++i) {
        std::string buffer;
        size_t      src, dst;

        std::getline(inputFile, buffer);
        std::stringstream(buffer) >> src >> dst;
        // std::cout << src << " " << dst << std::endl;

        if (src != dst) {
            ++num_links;
            IndexType new_src = src, new_dst = dst;

            // std::cout << "Read link: " << new_src << " " << new_dst << "\n";

            if (vertex_old_new_map.find(src) == vertex_old_new_map.end()) {
                new_src = next_vertex_id++;
                vertex_old_new_map[src] = new_src;
            }
            else {
                new_src = vertex_old_new_map[src];
            }
            //    std::cout << "Transformed link: " << new_src << " " << new_dst << "\n";

            if (vertex_old_new_map.find(dst) == vertex_old_new_map.end()) {
                new_dst = next_vertex_id++;
                vertex_old_new_map[dst] = new_dst;
            }
            else {
                new_dst = vertex_old_new_map[dst];
            }
            update_adjacencies(vertex_adjacencies, new_src, new_dst);
            update_adjacencies(vertex_adjacencies, new_dst, new_src);
            max_vertex_id = std::max({max_vertex_id, new_src, new_dst});

            if ((num_links % 100000) == 0) {
                std::cout << "Read " << num_links << " dstes." << std::endl;
            }
        }
    }
    if (num_links == 0) { std::cerr << "No lines read from the file" << std::endl; abort(); }

    IndexType num_vertices = max_vertex_id + 1;
    std::cout << "Read " << num_links << " links.\n";
    std::cout << "Num vertices: " << num_vertices << "\n";

    size_t removed_count{0};
    size_t num_edges = 0;
    std::vector<IndexType> offsets(1, 0);
    removed_count += clean_sort(vertex_adjacencies, offsets, num_edges, num_edges);

    std::cout << "Removed " << removed_count << " duplicate adjacencies" << std::endl;

    // Binary output data format:
    // Num_vertices  (8bytes)
    // Offsets_array [(Num_vertices + 1)*8bytes] (first element 0)
    // adjacency_lists ...
    std::string opath = edgelistFile + "_csr.bin";

    std::ofstream outfile(opath, std::ofstream::binary);
    outfile.write(reinterpret_cast<char*>(&num_vertices), sizeof(num_vertices));
    outfile.write(reinterpret_cast<char*>(offsets.data()), sizeof(IndexType)*offsets.size());

#if 0
    std::ofstream outfile_asc(opath + std::string(".cleaned_csr.asc"));
    outfile_asc << next_vertex_id << std::endl << "offsets: ";
    for (auto offset : offsets)
        outfile_asc << "\t" << offset;
    outfile_asc << std::endl;
#endif

    for (auto &adj_list : vertex_adjacencies)
    {
        outfile.write(reinterpret_cast<char*>(adj_list.second.data()), sizeof(IndexType)*adj_list.second.size());

#if 0
        outfile_asc << adj_list.first << ": ";
        for (auto &adj : adj_list.second)
            outfile_asc << "\t" << adj;
        outfile_asc << std::endl;
#endif
    }
}
