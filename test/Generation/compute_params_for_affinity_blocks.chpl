use CHGL;


var sorted_vertex_degrees = [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 4.0]: int;
var sorted_edge_degrees = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]: int;
var sorted_vertex_metamorphosis_coefs = [0.0, 0.513, 0.469, 0.40927, 0.37258, 0.38295, 0.34176, 0.29251, 0.28721]: real;
var sorted_edge_metamorphosis_coefs = [0.0, 0.33828, 0.29778, 0.28709, 0.27506, 0.25868, 0.24713]: real;

var idv: int = get_smallest_value_greater_than_one(sorted_vertex_degrees);
var idE: int = get_smallest_value_greater_than_one(sorted_edge_degrees);
var dv = sorted_vertex_degrees[idv];
var dE = sorted_edge_degrees[idE];
var mv = sorted_vertex_metamorphosis_coefs[dv];
var mE = sorted_edge_metamorphosis_coefs[dE];
var nV: real;
var nE: real;
var rho: real;

		
//determine the nV, nE, rho
var parameters = compute_params_for_affinity_blocks(dv, dE, mv, mE);
nV = parameters[1];
nE = parameters[2];
rho = parameters[3];		
//writeln("params:", params);
var test_passed = true: bool;
if nV >= 0{
	writeln(test_passed);
	
}
if nE >= 0{
	writeln(test_passed);
	
}
if rho >= 0 && rho <= 1{
	writeln(test_passed);
	
}
