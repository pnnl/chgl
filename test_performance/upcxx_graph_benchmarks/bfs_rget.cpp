/*Authors: Marcin Zalewski / Jesun Sahariar Firoz*/

#include <algorithm>
#include <cassert>
#include <fstream>
#include <iostream>
#include <limits>
#include <map>
#include <mutex>
#include <numeric>
#include <regex>
#include <sstream>
#include <sys/time.h>
#include <utility>
#include <vector>

#include <extensions/allocator/allocator.hpp>
#include <upcxx/allocate.hpp>
#include <upcxx/atomic.hpp>
#include <upcxx/backend.hpp>
#include <upcxx/rget.hpp>
#include <upcxx/rpc.hpp>
#include <upcxx/rput.hpp>
#include <upcxx/upcxx.hpp>

#include <boost/asio.hpp>
#include <boost/dynamic_bitset.hpp>

#if defined NDEBUG
const bool  debug{false};
#else
const bool debug{true};
#endif
#define dout \
    if (!debug) {} \
    else std::cerr

namespace ip = boost::asio::ip;

typedef unsigned long long ve_type;
typedef uint64_t           IndexType;

using element                     = std::tuple<ve_type, ve_type>;
using edge_list                   = std::vector<std::tuple<ve_type, ve_type>>;
std::string edgelistFile          = "";
uint64_t    num_vertices          = 0;
uint64_t    num_vertices_per_rank = 0;

// retain a per-destination queue for current and next iteration
std::vector<std::vector<std::pair<uint64_t, uint64_t>,
                        upcxxc::allocator<std::pair<uint64_t, uint64_t>>>>
    nextFrontierQarr[2];
// received buffer is never exported, so no need for current and next
std::vector<std::pair<uint64_t, uint64_t>> received_buffer;

double GetCurrentTime() {
  static struct timeval  tv;
  static struct timezone tz;
  gettimeofday(&tv, &tz);
  return tv.tv_sec + 1.e-6 * tv.tv_usec;
}

double TimeDifference(double& a, double& b) { return 1000 * (b - a); }

double ElapsedMillis(double start, double stop) {
  return TimeDifference(start, stop);
}

struct gptr_and_len {
  upcxx::global_ptr<uint64_t> p;    // pointer to first element in adjacencies
  int                         n;    // number of elements
};

struct gptr_and_len_pair {
  upcxx::global_ptr<std::pair<uint64_t, uint64_t>>
      p;    // pointer to first element in destination buffer
  int n;    // number of elements
};

std::vector<upcxx::global_ptr<gptr_and_len>> bases;

using BaseType = std::vector<upcxx::global_ptr<gptr_and_len>>;

using BaseQType = std::vector<upcxx::global_ptr<gptr_and_len_pair>>;

uint64_t index_to_vertex_id(size_t index) {
  // muliply for rows, add for row offset
  return index * upcxx::rank_n() + upcxx::rank_me();
}

size_t vertex_id_to_index(uint64_t vertex_id) {
  // It's ok to round off, as every vertex in a row in cyclic dist. will have the same index on every rank
  return vertex_id / upcxx::rank_n();
}

auto print_graph() {
  // For each vertex
  for (uint64_t i = 0; i < num_vertices_per_rank; i++) {
    const auto vtx_ptr =
        bases[upcxx::rank_me()].local()
            [i];    // <--This gives the local ptr to the gbl ptr and length for a vtx
    const auto adj_list_start = vtx_ptr.p.local();
    const auto adj_list_len   = vtx_ptr.n;

    auto current_vertex_id = index_to_vertex_id(i);

    std::cout << "i = " << i << ", vertex id = " << current_vertex_id
              << ", adjs: ";
    // For each neighbor of the vertex, get the adjacency  list and do the set intersection.
    for (auto j = 0; j < vtx_ptr.n; j++) {
      auto neighbor = adj_list_start[j];
      std::cout << neighbor << ", ";
    }
    std::cout << std::endl;
  }
}

upcxx::intrank_t vertex_id_to_rank(uint64_t v_id) {
  return v_id % upcxx::rank_n();
}

auto vertex_id_to_offset(uint64_t v_id) { return v_id / upcxx::rank_n(); }

void init_adjs(std::istream& infile, BaseType& bases) {
  infile.read(reinterpret_cast<char*>(&num_vertices), sizeof(num_vertices));
  std::cout << num_vertices << std::endl;

  bases.reserve(upcxx::rank_n());
  num_vertices_per_rank =
      (num_vertices + upcxx::rank_n() - 1 - upcxx::rank_me()) / upcxx::rank_n();
  std::cout << "No of vertices per rank: " << num_vertices_per_rank
            << std::endl;
  bases[upcxx::rank_me()] =
      upcxx::new_array<gptr_and_len>(num_vertices_per_rank);

  for (int r = 0; r < upcxx::rank_n(); r++) {
    bases[r] = upcxx::broadcast(bases[r], r).wait();
  }

  for (uint64_t i = upcxx::rank_me(); i < num_vertices; i += upcxx::rank_n()) {
    gptr_and_len pn;
    uint64_t     adj_indices[2];
    const auto   index_seekg = 1 + i;
    infile.seekg(index_seekg * sizeof(uint64_t), infile.beg);
    infile.read(reinterpret_cast<char*>(adj_indices), 2 * sizeof(uint64_t));
    auto cur_adj_len = adj_indices[1] - adj_indices[0];
    pn.n             = cur_adj_len;
    pn.p                      = upcxx::new_array<uint64_t>(cur_adj_len);
    const auto adj_list_seekg = 2 + num_vertices + adj_indices[0];
    infile.seekg(adj_list_seekg * sizeof(uint64_t), infile.beg);
    infile.read(reinterpret_cast<char*>(pn.p.local()),
                cur_adj_len * sizeof(uint64_t));
    for (auto edg = 0; edg < cur_adj_len; edg++) {
      std::cout << pn.p.local()[edg] << " ";
    }
 
    const auto base_index                       = vertex_id_to_index(i);
    bases[upcxx::rank_me()].local()[base_index] = pn;
  }
}

void readBinaryFormat(const std::string& filename, BaseType& bases) {
  std::ifstream inputFile;
  inputFile.exceptions(std::ifstream::failbit);
  try {
    inputFile.open(filename);
    init_adjs(inputFile, bases);
    inputFile.close();
  } catch (std::ios_base::failure& fail) {
    std::cerr << "Something went wrong with reading the matrix from file "
              << filename << std::endl;
    throw fail;
  }
}

int main(int argc, char* argv[]) {
  upcxx::init();

  boost::asio::io_service io_service;

  std::string h = ip::host_name();
  std::cout << "hostname: " << h << 'n';

  int         argIndex = 1;
  std::string arg_t(argv[argIndex]);
  uint64_t    source = 0;
  while (argIndex < argc) {
    std::string arg(argv[argIndex]);
    if (arg == "--edgelistfile") {
      ++argIndex;
      edgelistFile = std::string(argv[argIndex]);
      ++argIndex;
    }
    if (arg == "--source") {
      ++argIndex;
      source = std::stoul(argv[argIndex], nullptr, 0);
      ++argIndex;
    }
  }
  readBinaryFormat(edgelistFile, bases);

  upcxx::barrier();

  boost::dynamic_bitset<> color_map(num_vertices_per_rank);
  std::vector<uint64_t>   parent_map(num_vertices_per_rank);

  auto level               = 0;
  auto current_queue_index = [&]() { return level % 2; };
  auto nextFrontierQ       = [&]() -> auto& {
    dout << "nextFrontierQarr[" << current_queue_index() << "]"
              << std::endl;
    return nextFrontierQarr[current_queue_index()];
  };
  for (size_t i = 0; i < 2; ++i) {
    nextFrontierQarr[i].resize(upcxx::rank_n());
  }
  // find the rank of the source
  auto rank = vertex_id_to_rank(source);
  // if I am the owner of the source
  if (rank == upcxx::rank_me()) {
    auto v_index = vertex_id_to_index(source);
    // Set source's colormap to 1.
    color_map.set(v_index);
    parent_map[v_index] = source;    // source is its own parent
    auto vtx_ptr        = bases[upcxx::rank_me()].local()[v_index];
    auto adj_list_start = vtx_ptr.p.local();
    auto adj_list_len   = vtx_ptr.n;
    // For each neighbor of the vertex, put it in appropriate buffer
    for (auto j = 0; j < vtx_ptr.n; j++) {
      auto neighbor     = adj_list_start[j];
      auto neighborRank = vertex_id_to_rank(neighbor);
      nextFrontierQ()[neighborRank].push_back(std::make_pair(neighbor, source));
    }
  }

  BaseQType gpNextFrontierQarr[2];
  // access current queue
  auto gpNextFrontierQ = [&]() -> auto& {
    return gpNextFrontierQarr[current_queue_index()];
  };
  // initialize and exchange
  for (auto i = 0; i < 2; ++i) {
    gpNextFrontierQarr[i].resize(upcxx::rank_n());
    gpNextFrontierQarr[i][upcxx::rank_me()] =
        upcxx::new_array<gptr_and_len_pair>(upcxx::rank_n());
    for (int r = 0; r < upcxx::rank_n(); r++) {
      gpNextFrontierQarr[i][r] =
          upcxx::broadcast(gpNextFrontierQarr[i][r], r).wait();
    }
  }

  double start{0};
  double stop{0};
  if (upcxx::rank_me() == 0) start = GetCurrentTime();

  while (true) {
    // for each rank
    size_t localFrontierSize = 0;
    for (upcxx::intrank_t r = 0; r < upcxx::rank_n(); r++) {
      // sort and remove duplicates
      std::sort(nextFrontierQ()[r].begin(), nextFrontierQ()[r].end(),
                [](auto& a, auto& b) { return a.first < b.first; });
      std::unique(nextFrontierQ()[r].begin(), nextFrontierQ()[r].end(),
                  [](auto& a, auto& b) { return a.first == b.first; });

      // Now copy the neighbor list per rank to the dist obj
      gptr_and_len_pair pn;
      auto              destination_buffer_size = nextFrontierQ()[r].size();
      pn.n                                      = destination_buffer_size;
      dout << "nextFrontierQ()[r].data() = " << nextFrontierQ()[r].data()
                << ", r = " << r << std::endl;
      pn.p = upcxx::try_global_ptr(nextFrontierQ()[r].data());
      if (pn.p == nullptr) {
        if (nextFrontierQ()[r].size() > 0) {
          throw std::runtime_error(
              "Could not get a global pointer from upcxx allocator vector.");
        }
      }
      gpNextFrontierQ()[upcxx::rank_me()].local()[r] = pn;

      // reduce local frontier sizes
      localFrontierSize += nextFrontierQ()[r].size();
    }

    // Do a reduction to check whether we have reached the end
    //////////////////////////////////////////////////////////
    size_t totalFrontierSize = 0;
    auto done_reduction =
        upcxx::reduce_all(&localFrontierSize, &totalFrontierSize, 1,
                          [](size_t a, size_t b) { return a + b; });
    done_reduction.wait();
 
    // zero out receive buffer
    received_buffer.resize(0);
    // the start of the conjoined future
    upcxx::future<> fut_all = upcxx::make_future();

    if (upcxx::rank_me() == 0) {
      std::cout << "Level: " << level << " Size: " << totalFrontierSize
                << std::endl;
    }

    if (totalFrontierSize == 0) break;

    // Get vertices targeted for me from each rank
    for (upcxx::intrank_t r = 0; r < upcxx::rank_n(); r++) {
      upcxx::future<> fut =
          upcxx::rget(    // TODO: skip me
              gpNextFrontierQ()[r] + upcxx::rank_me())
              .then([=](gptr_and_len_pair pn) {
                std::vector<std::pair<uint64_t, uint64_t>> target_neighbor_list(
                    pn.n);
                return upcxx::rget(pn.p, target_neighbor_list.data(), pn.n)
                    .then([=, target_neighbor_list =
                                  std::move(target_neighbor_list)]() {
                      received_buffer.insert(received_buffer.end(),
                                             target_neighbor_list.begin(),
                                             target_neighbor_list.end());
                    });
              });
      // conjoin the futures
      fut_all = upcxx::when_all(fut_all, fut);
    }

    // wait for all the conjoined futures to complete
    fut_all.wait();
    dout << "fut_all" << std::endl;

    // Important: do not increment the level until rgets are finished or the rgets will work with the wrong level
    level += 1;

    // After level is increased, we can clear the data from the previous level that is still in the queue
    for (upcxx::intrank_t r = 0; r < upcxx::rank_n(); r++) {
      nextFrontierQ()[r].resize(0);
    }

    // At this point everyone should have the next frontier for the next iteration
    // sort and remove duplicates
    std::sort(received_buffer.begin(), received_buffer.end(),
              [](auto& a, auto& b) { return a.first < b.first; });
    std::unique(received_buffer.begin(), received_buffer.end(),
                [](auto& a, auto& b) { return a.first == b.first; });

    for (auto vertex_p : received_buffer) {
      auto vtx    = vertex_p.first;
      auto parent = vertex_p.second;
      // Check whether the vertex has already been visited.
      auto v_index = vertex_id_to_index(vtx);
      if (color_map[v_index]) {    //Already visited
        continue;
      } else {    // Not visited yet
        dout << "Marking " << vtx << " as visited. " << std::endl;
        color_map.set(v_index);
        parent_map[v_index] = parent;
        // Put all its neighbors into the nextfrontier
        auto vtx_ptr        = bases[upcxx::rank_me()].local()[v_index];
        auto adj_list_start = vtx_ptr.p.local();
        auto adj_list_len   = vtx_ptr.n;
        // For each neighbor of the vertex, put it in appropriate buffer
        for (auto j = 0; j < vtx_ptr.n; j++) {
          auto neighbor     = adj_list_start[j];
          auto neighborRank = vertex_id_to_rank(neighbor);
          nextFrontierQ()[neighborRank].push_back(
              std::make_pair(neighbor, vtx));
        }
      }
    }
  }

  if (upcxx::rank_me() == 0) {
    stop          = GetCurrentTime();
    float elapsed = ElapsedMillis(start, stop);
    std::cout << "Total time " << elapsed << " ms." << std::endl;
  }

  // TODO: clean up after each barrier, empty the next frontier ds, received buffer ds etc.
  upcxx::finalize();
  return 0;
}
