/*Authors: Marcin Zalewski / Jesun Sahariar Firoz*/

#include <algorithm>
#include <cassert>
#include <cstddef>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <map>
#include <mutex>
#include <numeric>
#include <regex>
#include <sstream>
#include <sys/time.h>
#include <type_traits>
#include <utility>
#include <vector>

#define RUNOMP 1

#ifdef RUNOMP
#include <omp.h>
#endif



#include <upcxx/allocate.hpp>
#include <upcxx/atomic.hpp>
#include <upcxx/backend.hpp>
#include <upcxx/reduce.hpp>
#include <upcxx/rget.hpp>
#include <upcxx/rpc.hpp>
#include <upcxx/rput.hpp>
#include <upcxx/upcxx.hpp>


// #include "compressed.hpp"
using namespace upcxx;

typedef unsigned long long ve_type;
typedef uint64_t           IndexType;

using element                     = std::tuple<ve_type, ve_type>;
using edge_list                   = std::vector<std::tuple<ve_type, ve_type>>;
std::string edgelistFile          = "";
uint64_t    num_vertices          = 0;
uint64_t    num_vertices_per_rank = 0;

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

class counting_output_iterator
    : public std::iterator<std::random_access_iterator_tag, size_t> {
public:
  counting_output_iterator(size_t& count) : count{count} {}
  void                      operator++() {}
  void                      operator++(int) {}
  counting_output_iterator& operator*() { return *this; }
  counting_output_iterator& operator[](size_t) { return *this; }

  template<typename T>
  void operator=(T) {
    //     #pragma omp atomic
    count++;
  }
  size_t get_count() { return count; }

private:
  size_t& count;
};

struct gptr_and_len {
  global_ptr<uint64_t> p;    // pointer to first element in adjacencies
  int                  n;    // number of elements
};

std::vector<upcxx::global_ptr<gptr_and_len>> bases;

using BaseType = std::vector<upcxx::global_ptr<gptr_and_len>>;

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
    // std::cout << "Local vertex: " << i << " " << std::endl;

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

auto vertex_id_to_rank(uint64_t v_id) { return v_id % upcxx::rank_n(); }

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

  int         argIndex = 1;
  std::string arg_t(argv[argIndex]);

  while (argIndex < argc) {
    std::string arg(argv[argIndex]);
    if (arg == "--edgelistfile") {
      ++argIndex;
      edgelistFile = std::string(argv[argIndex]);
      ++argIndex;
    }
  }

  readBinaryFormat(edgelistFile, bases);

  // print_graph();

  upcxx::barrier();

  // the start of the conjoined future
  upcxx::future<> fut_all = upcxx::make_future();
  double          start{0};
  double          stop{0};
  if (upcxx::rank_me() == 0) start = GetCurrentTime();

  size_t                   local_triangle_count = 0;
  

#ifdef RUNOMP
#pragma omp parallel 
{
  auto tid = omp_get_thread_num();
  if (tid == 0)
    std::cout << " Total #Threads = "<< omp_get_num_threads() << std::endl;
  // schedule(static,1) // schedule(dynamic, 10)

#pragma omp for schedule(dynamic, 100)  reduction(+:local_triangle_count)
#endif
  // For each vertex
  for (uint64_t i = 0; i < num_vertices_per_rank; i++) {
    counting_output_iterator counter(local_triangle_count);
    const auto vtx_ptr =
        bases[upcxx::rank_me()].local()
            [i];    // <--This gives the local ptr to the gbl ptr and length for a vtx
    const auto adj_list_start = vtx_ptr.p.local();
    const auto adj_list_len   = vtx_ptr.n;
    // std::cout << "Local vertex: " << i << " " << std::endl;

    auto current_vertex_id = index_to_vertex_id(i);
    // For each neighbor of the vertex, get the adjacency  list and do the set intersection.
    for (auto j = 0; j < vtx_ptr.n; j++) {
      auto neighbor = adj_list_start[j];
      if (current_vertex_id < neighbor) {
	// Since everything is local, following the same procedure as parent vtx to get 2-hop neighbor
	const auto vtx_ptr_nbr =
	  bases[upcxx::rank_me()].local()[neighbor];
	const auto adj_list_nbr_start = vtx_ptr_nbr.p.local();
	const auto adj_list_nbr_len   = vtx_ptr_nbr.n;
	
	std::set_intersection(adj_list_start, adj_list_start + adj_list_len,
			      adj_list_nbr_start,
			      adj_list_nbr_start + adj_list_nbr_len, counter);
      }
    }
  }
#ifdef RUNOMP
 }
#endif

  // if (rank_me() == 0) {
  size_t total_triangle_count = 0;
  // Reduce the result
  auto done_reduction =
      upcxx::reduce_one(&local_triangle_count, &total_triangle_count, 1,
                        [](size_t a, size_t b) { return a + b; }, 0);
  done_reduction.wait();
  if (upcxx::rank_me() == 0) {
    stop          = GetCurrentTime();
    float elapsed = ElapsedMillis(start, stop);
    std::cout << "Total no of triangles: " << total_triangle_count / 3
              << " counted in " << elapsed << " ms." << std::endl;
    if (total_triangle_count % 3 > 0) {
      std::cout << "WARNING: " << total_triangle_count % 3 << " remaining."
                << std::endl;
    }
  }

  upcxx::finalize();
  return 0;
}
