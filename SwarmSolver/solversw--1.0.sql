-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION solversw" to load this file. \quit

-- The solver's entry point
CREATE OR REPLACE FUNCTION swarmops_solve(sl_solver_arg) RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT;
     
WITH 
     -- Registers the solver and its parameters.
     solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                  values ('swarmops', 1.0, 'Hvass Laboratories', 'http://www.hvass-labs.org/projects/swarmops/', 'The port of SwampOPS solver by Laurynas Siksnys') 
                  returning sid),     
     spar1 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('n' , 'int', 'Number of iterations to run before the solver terminates and outputs result', 1000, 0, 1E9) 
                  RETURNING pid),
     sspar1 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar1
                  RETURNING sid),
     spar2 AS    (INSERT INTO sl_parameter(name, type, description, push_default)
                  values ('rndseed' , 'int', 'A number to seed the random number generator', false) 
                  RETURNING pid),
     sspar2 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar2
                  RETURNING sid),
     spar3 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max, push_default)
                  values ('runs' , 'int', 'A number of runs to performs', 1, 1, 1E9, false) 
                  RETURNING pid),
     sspar3 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar3
                  RETURNING sid),

     -- Registers the MESH method. It has no parameters.
     method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'mesh', 'Mesh iteration', 'swarmops_solve', 'Black box optimization problem', 'Optimization method which iterates over all possible combinations of parameters fitting a mesh of a certain size. This mesh size is determined by the allowed number of optimization iterations as follows: k = pow(numIterations, 1.0/n) where numIterations is the number of optimization iterations allowed, n is the dimensionality of the problem to be optimized, and k is the number of mesh-iterations in each dimension.' 
		  FROM solver RETURNING mid),

     -- Registers the RND method. It has no parameters.
     method2 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'rnd', 'Random Sampling (Uniform)', 'swarmops_solve', 'Black box optimization problem', 'Random Sampling (RND). Positions FROM the search-space are sampled randomly and uniformly and the position with the best fitness is returned.' 
		  FROM solver RETURNING mid),

     -- Gradient Descent (GD), Gradient Emancipated Descent (GED) 
     --     are not supported yet as they require the gradient of the problem to be optimized

     -- Registers the HC method and its prameteters.
     method5 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'hc', 'Hill-Climber', 'swarmops_solve', 'Black box optimization problem', 'Hill-Climber (HC) optimization method originally due to Metropolis et al. Here made for real-coded search-spaces. Does local sampling with a stochastic choice on whether to move, depending on the fitness difference between current and new potential position.' 
		  FROM solver RETURNING mid),
     mpar5_1 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('r' , 'float', 'Sampling range', 0.01, 0.0000001, 1) 
                  RETURNING pid),
     mmpar5_1 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method5, mpar5_1
                  RETURNING pid),
     mpar5_2 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('D' , 'float', 'Probability weight', 10, 0.001, 10000) 
                  RETURNING pid),
     mmpar5_2 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method5, mpar5_2
                  RETURNING pid),

     -- Registers the SA method and its prameteters.
     method6 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'sa', 'Simulated Annealing', 'swarmops_solve', 'Black box optimization problem', 'Simulated Annealing (SA) optimization method originally due Kirkpatrick et al. Here made for real-coded search-spaces. Does local sampling with a stochastic choice on whether to move, depending on the fitness difference between current and new potential position. The movement probability is altered during an optimization run, and the agent has its position in the search-space reset to a random value at designated intervals.' 
		  FROM solver RETURNING mid),
     mpar6_1 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('r' , 'float', 'Sampling range factor', 0.01, 1e-5, 1) 
                  RETURNING pid),
     mmpar6_1 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method6, mpar6_1
                  RETURNING pid),
     mpar6_2 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('alpha' , 'float', 'Start-value', 0.03, 1e-5, 1) 
                  RETURNING pid),
     mmpar6_2 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method6, mpar6_2
                  RETURNING pid),
     mpar6_3 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('beta' , 'float', 'End-value', 0.01, 1e-5, 1) 
                  RETURNING pid),
     mmpar6_3 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method6, mpar6_3
                  RETURNING pid),
     mpar6_4 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('T' , 'float', 'Iterations between resets', 40000.01, 100, 100000) 
                  RETURNING pid),
     mmpar6_4 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method6, mpar6_4
                  RETURNING pid),

     -- Registers the PS method. It has no parameters.
     method7 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'ps', 'Pattern Search', 'swarmops_solve', 'Black box optimization problem', 'Pattern Search (DE) optimization method originally due to Fermi and Metropolis. A similar idea is due to Hooke and Jeeves. This variant uses random selection of which dimension to update and is hence	a slight simplification of the original methods.' 
		  FROM solver RETURNING mid),

     -- Registers the LUS method and its prameteters.
     method8 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'lus', 'Local Unimodal Sampling', 'swarmops_solve', 'Black box optimization problem', 'Local Unimodal Sampling (LUS). Does local sampling with an exponential decrease of the sampling-range.' 
		  FROM solver RETURNING mid),
     mpar8_1 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('gamma', 'float', 'Gamma', 3, 0.5, 20) 
                  RETURNING pid),
     mmpar8_1 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method8, mpar8_1
                  RETURNING pid),

     -- Registers the DE method and its parameters.
     method9 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'de', 'Differential Evolution', 'swarmops_solve', 'Black box optimization problem', 'Differential Evolution (DE) optimization method originally due to Storner and Price.' 
		  FROM solver RETURNING mid),
     mpar9_1 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('NP', 'float', 'Number of agents NP', 172, 3, 200) 
                  RETURNING pid),
     mmpar9_1 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method9, mpar9_1
                  RETURNING pid),
     mpar9_2 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR', 'float', 'Crossover Probability (CR)', 0.965609, 0, 1) 
                  RETURNING pid),
     mmpar9_2 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method9, mpar9_2
                  RETURNING pid),
     mpar9_3 AS  (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F', 'float', 'Differential weight (F)', 0.361520, 0, 2) 
                  RETURNING pid),
     mmpar9_3 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method9, mpar9_3
                  RETURNING pid),

     -- Registers the DEsuite method and its parameters.
     method10 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'desuite', 'Differential Evolution Suite', 'swarmops_solve', 'Black box optimization problem', 'Differential Evolution (DE) optimization method originally due to Storner and Price. This suite offers combinations of DE variants and various perturbation schemes for its behavioural parameters.' 
		  FROM solver RETURNING mid),
     mpar10_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('NP', 'float', 'Number of agents NP', 157, 4, 200) 
                  RETURNING pid),
     mmpar10_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method10, mpar10_1
                  RETURNING pid),
     mpar10_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR', 'float', 'Crossover Probability (CR)', 0.976920, 0, 1) 
                  RETURNING pid),
     mmpar10_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method10, mpar10_2
                  RETURNING pid),
     mpar10_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F', 'float', 'Differential weight (F)', 0.334942, 0, 2) 
                  RETURNING pid),
     mmpar10_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method10, mpar10_3
                  RETURNING pid),

     -- Registers the DETP method and its parameters
     method11 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'detp', 'DE with Temporal Parameters', 'swarmops_solve', 'Black box optimization problem', 'Differential Evolution (DE) optimization method originally due to Storner and Price. This variant uses Temporal Parameters, that is, different parameters are used for different periods of the optimization run.' 
		  FROM solver RETURNING mid),
     mpar11_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('NP', 'float', 'Number of agents NP', 9, 4, 200) 
                  RETURNING pid),
     mmpar11_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method11, mpar11_1
                  RETURNING pid),     
     mpar11_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR_1', 'float', 'Crossover Probability (CR_1)', 0.040135, 0, 1) 
                  RETURNING pid),
     mmpar11_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method11, mpar11_2
                  RETURNING pid),
     mpar11_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR_2', 'float', 'Crossover Probability (CR_2)', 0.576005, 0, 1) 
                  RETURNING pid),
     mmpar11_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method11, mpar11_3
                  RETURNING pid),
     mpar11_4 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F_1', 'float', 'Differential weight (F1)', 0.955493, 0, 2) 
                  RETURNING pid),
     mmpar11_4 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method11, mpar11_4
                  RETURNING pid),
     mpar11_5 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F_2', 'float', 'Differential weight (F_2)', 0.320264, 0, 2) 
                  RETURNING pid),
     mmpar11_5 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method11, mpar11_5
                  RETURNING pid),

     -- Registers the JDE method and its parameters
     method12 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'jde', 'Jan. Differential Evolution (jDE)', 'swarmops_solve', 'Black box optimization problem', 'Differential Evolution (DE) optimization method originally due to Storner and Price. jDE variant due to Brest et al. This variant claims to be "self-adaptive" in that it claims to eliminate the need to choose two parameters of the original DE, but in reality it introduces an additional 6 parameters, so the jDE variant now has 9 parameters instead of just 3 of the original DE.'
		  FROM solver RETURNING mid),
     mpar12_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('NP', 'float', 'Number of agents NP', 18, 4, 200) 
                  RETURNING pid),
     mmpar12_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_1
                  RETURNING pid),     
     mpar12_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F_{init}', 'float', 'FInit (Differential weight, initial value)', 1.393273, 0, 2)
                  RETURNING pid),
     mmpar12_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_2
                  RETURNING pid),
     mpar12_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F_l', 'float', 'Fl', 0.319121, 0, 2) 
                  RETURNING pid),
     mmpar12_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_3
                  RETURNING pid),
     mpar12_4 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F_u', 'float', 'Fu', 0.933712, 0, 2) 
                  RETURNING pid),
     mmpar12_4 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_4
                  RETURNING pid),
     mpar12_5 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('tau_{F}', 'float', 'TauF (aka. Tau1)', 0.619482, 0, 1) 
                  RETURNING pid),
     mmpar12_5 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_5
                  RETURNING pid),
     mpar12_6 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR_{init}', 'float', 'CRInit (Crossover probability, initial value)', 0.777215, 0, 1) 
                  RETURNING pid),
     mmpar12_6 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_6
                  RETURNING pid),
     mpar12_7 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR_l', 'float', 'CRl', 0.889368, 0, 1) 
                  RETURNING pid),
     mmpar12_7 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_7
                  RETURNING pid),
     mpar12_8 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('CR_u', 'float', 'CRu', 0.160088, 0, 1) 
                  RETURNING pid),
     mmpar12_8 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_8
                  RETURNING pid),
     mpar12_9 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('tau_{CR}', 'float', 'TauCR (aka. Tau2)', 0.846782, 0, 1) 
                  RETURNING pid),
     mmpar12_9 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method12, mpar12_9
                  RETURNING pid),

     -- Registers the ELG method and its parameters
     method13 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'elg', 'Evolution by Lingering Global best', 'swarmops_solve', 'Black box optimization problem', 'Evolution by Lingering Global best (ELG) optimization method derived as a simplification to the DE method.'
		  FROM solver RETURNING mid),
     mpar13_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('NP', 'float', 'Number of agents NP', 143, 2, 170) 
                  RETURNING pid),
     mmpar13_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method13, mpar13_1
                  RETURNING pid),

     -- Registers the MYG method and its parameters
     method14 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'myg', 'More Yo-yos doing Global optimization', 'swarmops_solve', 'Black box optimization problem', 'More Yo-yos doing Global optimization (MYG) devised as a simplification to the DE optimization method originally due to Storner and Price. The MYG method eliminates the probability parameter, and also has random selection of which agent to update instead of iterating over them all in order.'
		  FROM solver RETURNING mid),
     mpar14_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('NP', 'float', 'Number of agents NP', 300, 5, 300) 
                  RETURNING pid),
     mmpar14_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method14, mpar14_1
                  RETURNING pid),
     mpar14_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('F', 'float', 'Differential weight F, aka. alpha.', 1.627797, 0.5, 2) 
                  RETURNING pid),
     mmpar14_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method14, mpar14_2
                  RETURNING pid),

     -- Registers the PSO method and its parameters
     method15 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'pso', 'Particle Swarm Optimization', 'swarmops_solve', 'Black box optimization problem', 'Particle Swarm Optimization (PSO) optimization method originally due to Eberhart, Shi, Kennedy, etc.'
		  FROM solver RETURNING mid),
     mpar15_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('S', 'float', 'Number of agents', 148, 1, 200) 
                  RETURNING pid),
     mmpar15_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method15, mpar15_1
                  RETURNING pid),
     mpar15_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('omega', 'float', 'Inertia weight', -0.046644, -2, 2) 
                  RETURNING pid),
     mmpar15_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method15, mpar15_2
                  RETURNING pid),
     mpar15_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('phi_p', 'float', 'Weight on particle-best attraction', 2.882152, -4, 4) 
                  RETURNING pid),
     mmpar15_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method15, mpar15_3
                  RETURNING pid),
     mpar15_4 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('phi_g', 'float', 'Weight on swarm-best attraction', 1.857463, -4, 4) 
                  RETURNING pid),
     mmpar15_4 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method15, mpar15_4
                  RETURNING pid),

     -- Registers the FAE method and its parameters
     method16 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'fae', 'Forever Accumulating Evolution', 'swarmops_solve', 'Black box optimization problem', 'Forever Accumulating Evolution (DE) optimization method derived as a simplification to the PSO method.'
		  FROM solver RETURNING mid),
     mpar16_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('S', 'float', 'Number of agents', 100, 1, 100) 
                  RETURNING pid),
     mmpar16_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method16, mpar16_1
                  RETURNING pid),
     mpar16_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('lambda_g', 'float', 'Lambda-g', 1.486496, -2, 2) 
                  RETURNING pid),
     mmpar16_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method16, mpar16_2
                  RETURNING pid),
     mpar16_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('lambda_x', 'float', 'Lambda-x', -3.949617, -8, -1) 
                  RETURNING pid),
     mmpar16_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method16, mpar16_3
                  RETURNING pid),

     -- Registers the MOL method and its parameters
     method17 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'mol', 'Many Optimizing Liaisons', 'swarmops_solve', 'Black box optimization problem', 'Many Optimizing Liaisons (MOL) optimization method devised as a simplification to the PSO method originally due to Eberhart et al. The MOL method does not have any attraction to the particle''s own best known position, and the algorithm also makes use of random selection of which particle to update instead of iterating over the entire swarm.'
		  FROM solver RETURNING mid),
     mpar17_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('S', 'float', 'Number of agents', 100, 1, 200) 
                  RETURNING pid),
     mmpar17_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method17, mpar17_1
                  RETURNING pid),
     mpar17_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('omega', 'float', 'Inertia weight', -0.289623, -2, 2) 
                  RETURNING pid),
     mmpar17_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method17, mpar17_2
                  RETURNING pid),
     mpar17_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('phi_g', 'float', 'Weight on swarm-best attraction', 1.494742, -4, 4) 
                  RETURNING pid),
     mmpar17_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method17, mpar17_3
                  RETURNING pid),

     -- Registers the LICE method and its parameters
     method18 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'lice', 'Layered and Interleaved Co-Evolution', 'swarmops_solve', 'Black box optimization problem', 'Layered and Interleaved Co-Evolution (LICE) optimization method by M.E.H. Pedersen. Consists of two layers of LUS optimization methods, where the meta-layer is used to adjust the behavioural parameter of the base-layer in an interleaved fashion. The parameters for this LICE method are: The initial parameter (decrease-factor) for the base-layer LUS, the decrease-factor for the meta-layer, and the number of iterations to perform of the base-layer for each iteration of the meta-layer. The LICE method is an experimental method which uses what might be called meta-adaptation (as opposed to meta-optimization), because the base-layer LUS is re-using its discoveries between optimization runs. The LICE method requires significantly more iterations than using the LUS method on its own, but may also have greater adaptability to previously unseen optimization problems, although this has not yet been documented and may indeed also be a false notion.'
		  FROM solver RETURNING mid),
     mpar18_1 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('gamma_2', 'float', 'gamma2', 0.991083, 0.5, 4.0) 
                  RETURNING pid),
     mmpar18_1 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method18, mpar18_1
                  RETURNING pid),
     mpar18_2 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('N', 'float', 'N', 25, 10, 40) 
                  RETURNING pid),
     mmpar18_2 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method18, mpar18_2
                  RETURNING pid),
     mpar18_3 AS (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('gamma', 'float', 'gamma', 5.633202, 0.5, 6) 
                  RETURNING pid),
     mmpar18_3 AS(INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method18, mpar18_3
                  RETURNING pid)     

     -- Perform the actual insert
     SELECT count(*) FROM solver, spar1, sspar1, spar2, sspar2, spar3, sspar3,
	 		  -- Mesh Iteration
			  method1,
			  -- Random Sampling
			  method2,
			  -- Local Sampling
			  method5, mpar5_1, mmpar5_1, mpar5_2, mmpar5_2, 
 			  method6, mpar6_1, mmpar6_1, mpar6_2, mmpar6_2, mpar6_3, mmpar6_3, mpar6_4, mmpar6_4,
			  method7, 
			  method8, mpar8_1, mmpar8_1, 
			  -- Swarm-Based Optimization, DE and variants
			  method9, mpar9_1, mmpar9_1, mpar9_2, mmpar9_2, mpar9_3, mmpar9_3,
			  method10, mpar10_1, mmpar10_1, mpar10_2, mmpar10_2, mpar10_3, mmpar10_3, 
			  method11, mpar11_1, mmpar11_1, mpar11_2, mmpar11_2, mpar11_3, mmpar11_3, mpar11_4, mmpar11_4, mpar11_5, mmpar11_5, 
			  method12, mpar12_1, mmpar12_1, mpar12_2, mmpar12_2, mpar12_3, mmpar12_3, mpar12_4, mmpar12_4, mpar12_5, mmpar12_5, mpar12_6, mmpar12_6, mpar12_7, mmpar12_7, mpar12_8, mmpar12_8, mpar12_9, mmpar12_9,
			  method13, mpar13_1, mmpar13_1,
			  method14, mpar14_1, mmpar14_1, mpar14_2, mmpar14_2,
			  -- Swarm-Based Optimization, PSO and variants
			  method15, mpar15_1, mmpar15_1, mpar15_2, mmpar15_2, mpar15_3, mmpar15_3, mpar15_4, mmpar15_4,
			  method16, mpar16_1, mmpar16_1, mpar16_2, mmpar16_2, mpar16_3, mmpar16_3,
			  method17, mpar17_1, mmpar17_1, mpar17_2, mmpar17_2, mpar17_3, mmpar17_3,
			  -- Compound Methods
			  method18, mpar18_1, mmpar18_1, mpar18_2, mmpar18_2, mpar18_3, mmpar18_3