/*
  Copyright (C) 2004-2007 EPRI Corporation and others.  All Rights Reserved.

  This code is licensed under the terms of the Eclipse Public License (EPL).

  $Id: cbc_driverC_sos.c 1902 2013-04-10 16:58:16Z stefan $
*/

/* This example shows the use of the "C" interface for CBC. */

#include "libPgCbc.h"
#include "miscadmin.h"
#include "utils/elog.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <iostream>
#include <ostream>
#include <sstream>
#include <streambuf>
#include <sstream>
#include <cmath>


#include <exception>
#include <typeinfo>
#include <stdexcept>

// Using CLP as the solver
#include "CbcOrClpParam.hpp"
#include "OsiClpSolverInterface.hpp"
#include "CbcModel.hpp"
#include "CbcSolver.hpp"
#include "CoinBuild.hpp"
#include "CbcStrategy.hpp"
#include "CbcHeuristic.hpp"
#include "CoinMessageHandler.hpp"
#include "CoinHelperFunctions.hpp"
#include "CoinError.hpp"

// For time measurements
#include <sys/time.h> /* For performance benchmarking */

/* A type of function */
typedef enum {
	LPfunctionEmpty,			/* Function does not containt variables */
	LPfunctionFloat,			/* Function contains only float variables */
	LPfunctionInteger,			/* Function contains only integer variables */
	LPfunctionBool,				/* Function contains only boolean variables */
	LPfunctionMixed				/* Function contains variables of mixed types */
} LPfunctionType;


// To allow stdio redirection
class SolverLP_MessageHandler : public CoinMessageHandler {

public:
    virtual int print();

    /** Default constructor. */
    SolverLP_MessageHandler();

    /** Destructor */
    virtual ~SolverLP_MessageHandler();

    /// Clone
    virtual CoinMessageHandler * clone() const ;
};

class SolverLP_Streambuf: public std::basic_streambuf< char,std::char_traits<char> >
{
  typedef std::basic_streambuf<char, std::char_traits<char> >::int_type int_type;
  typedef std::char_traits<char> traits_t;

  int_type overflow( int_type c )
  {
     //std::cerr << traits_t::to_char_type( c ) << traits_t::to_char_type( c );
	  appendStringInfoChar(&buf, c);

	  if (c == '\n') {
			ErrorContextCallback * old_error_context = error_context_stack;
			error_context_stack = NULL;
			ereport(NOTICE, (errmsg("%s", buf.data)));
			error_context_stack = old_error_context;
			resetStringInfo(&buf);
	  }
     return c;
  }

 public:

  SolverLP_Streambuf() :   std::basic_streambuf < char,std::char_traits<char> > ()
  {
	  initStringInfo(&buf);
  }

  ~SolverLP_Streambuf()
  {
	  if (buf.data)
		  pfree(buf.data);
  }

private:
  StringInfoData buf;
};

/* ***************** PostgreSQL Memory Manager is not yet supported. *************** */

///* If true, CBC uses PostgreSQL memory manager. This is needed, to avoid SEGFAL during the initialization of static members of the CBC solver */
//static bool use_pg_memctx = false;
///* Override the global NEW and DELETE operators to use the Postgres's memory manager */
//inline void* operator new     ( size_t size ) { if (use_pg_memctx) return palloc( size ); else return malloc(size);  }
//inline void* operator new[]   ( size_t size ) { if (use_pg_memctx) return palloc( size ); else return malloc(size);  }
//inline void  operator delete  ( void* ptr   ) { if (use_pg_memctx && ptr) pfree( ptr ); else free(ptr); }
//inline void  operator delete[]( void* ptr   ) { if (use_pg_memctx && ptr) pfree( ptr ); else free(ptr); }

/* Prototypes */
inline static LPfunctionType get_function_type(LPproblem * prob, pg_LPfunction * poly);
static CbcModel * buildCbcModel(LPproblem * prob);
static int callBack(CbcModel * model, int whereFrom);
static inline double time_diff(struct timeval *tod1, struct timeval *tod2);


extern LPsolverResult * solve_problem_cbc(LPproblem * prob, char * args, int pgLogLevel) {
	LPsolverResult 			 	 * result = NULL;
	std::streambuf				 * orgbuf;

	/* Set the memory context */
	// use_pg_memctx = true;

	/* Remembers the standard IO*/
	 orgbuf = std::cout.rdbuf();

	try {
		CbcSolverUsefulData 	 paramData;
		SolverLP_MessageHandler  * msgHnd;
		SolverLP_Streambuf		 * msgBuf;
		CbcModel 				 * model;
		struct timeval 			 start_time, end_time; /* For performance benchmarking */

		/* Redirect stdout */
		msgBuf = new SolverLP_Streambuf();
		std::cout.rdbuf( msgBuf );

		/* Build Cbc model */
		model = buildCbcModel(prob);

		if (model == NULL)
			ereport(ERROR, (errmsg("Failed creating CBC model.")));

		/* Initialize the message handler */
		msgHnd = new SolverLP_MessageHandler();
		model->passInMessageHandler(msgHnd);
		paramData.parameters_[whichParam(CLP_PARAM_INT_LOGLEVEL, paramData.numberParameters_, paramData.parameters_)].setIntValue(5);

		/* Setup default parameters */
		paramData.useSignalHandler_ = false;
		paramData.noPrinting_ = false;

		/* Performance measurements */
		gettimeofday(&start_time, NULL);

		CbcMain0(*model, paramData);

		/* Setup the logging level */
		int logLevel = 0;

		if (pgLogLevel <= INFO)
			logLevel = 1;
		if (pgLogLevel <= LOG)
			logLevel = 2;
		if (pgLogLevel <= DEBUG1)
			logLevel = 3;
		if (pgLogLevel <= DEBUG2)
			logLevel = 4;

		msgHnd->setLogLevel(logLevel);
		paramData.parameters_[whichParam(CLP_PARAM_INT_LOGLEVEL, paramData.numberParameters_, paramData.parameters_)].setIntValue(logLevel);
		paramData.parameters_[whichParam(CLP_PARAM_INT_SOLVERLOGLEVEL, paramData.numberParameters_, paramData.parameters_)].setIntValue(logLevel);

		/* Setup the arguments */
		std::vector<const char*> argv;
		argv.push_back("SolverLP Interface");

		if (args != NULL)
		{
			std::stringstream ss(args);
			std::string item;
			while(std::getline(ss, item, ' '))
				argv.push_back(strdup(item.c_str()));
		}

		argv.push_back("-solve");
		argv.push_back("-quit");

		// if (args != NULL)
		//	argv.push_back(args);

		CbcMain1((int) argv.size(), &argv[0], *model, callBack, paramData);

		gettimeofday(&end_time, NULL);

		/* Saves the solution */
		const double * solution = model->bestSolution();

		if (solution != NULL) {

			result = new LPsolverResult();
			/* CbcModel clones the solver so we need to get current copy from the CbcModel */
			result->numVariables = model->solver()->getNumCols();
			result->varIndices = new int[result->numVariables];
			result->varValues = new double[result->numVariables];
			for (int i = 0; i < result->numVariables; i++) {
				result->varIndices[i] = i;
				result->varValues[i] = solution[i];
			}
			result->solvingTime = time_diff(&end_time, &start_time);
		}
		delete model;
		delete msgHnd;
		delete msgBuf;

	} catch (const std::exception &e) {
		ereport(ERROR, (errmsg("%s", e.what())));
	} catch (const std::string & e){
		ereport(ERROR, (errmsg("%s", e.c_str())));
	} catch (const CoinError&e)	{
	    ereport(ERROR, (errmsg("%s", e.message().c_str())));
	} catch (...)	{
		ereport(ERROR, (errmsg("Some exception occured during CBC solving.")));
	}

	/* Restore stdout buffer */
	std::cout.rdbuf(orgbuf);

	/* Restore the memory context */
	// use_pg_memctx = false;

	return result;
}

/* Builds Cbc Model */
static CbcModel * buildCbcModel(LPproblem * prob) {
	OsiClpSolverInterface 	* clp;
	CoinBuild 				* build;
	int 					i;
	int 					* colStart;
	double 					* colValue;
	ListCell 				* c;
	bool 					is_mip;

	/* Early return, on NULL problems */
	if (prob == NULL || prob->numVariables <= 0)
		return NULL;

	// Instantiate the Clp solver
	clp = new OsiClpSolverInterface();
	// clp->messageHandler()->setLogLevel(0);
	//clp->messageHandler()->setFilePointer();
	clp->getModelPtr()->setDualBound(1e10);
	// Tell solver to return fast if presolve or initial solve infeasible
	// clp->getModelPtr()->setMoreSpecialOptions(3);

	/* Setup objective */
	clp->setObjSense(prob->objDirection == LPobjMinimize ? 1 : -1);

	/* Setup columns, and the objective */
	colStart = new int[prob->numVariables];
	colValue = new double[prob->numVariables];
	for (i = 0; i < prob->numVariables; i++)
		colValue[i] = 0;

	if (prob->obj != NULL)
		for (i = 0; i < prob->obj->numTerms; i++) {
			lpTerm * term = &prob->obj->term[i];
			/* Assign the objective function value */
			colValue[term->varNr] = term->factor;
		}

	build = new CoinBuild();

	is_mip = false; /* Initialy, the problem is not MIP */
	for (i = 0; i < prob->numVariables; i++) {
		double columnLower = -COIN_DBL_MAX;
		double columnUpper = COIN_DBL_MAX;

		if (prob->varTypes[i] == LPtypeBool) {
			columnLower = 0;
			columnUpper = 1;
		}

		build->addColumn(0, NULL, NULL, columnLower, columnUpper, colValue[i]);

		/* Detect if the problem is MIP */
		is_mip |= (prob->varTypes[i] == LPtypeBool)
				|| (prob->varTypes[i] == LPtypeInteger);
	}

	/* Add actual columns */
	((OsiSolverInterface *) clp)->addCols(*build);

	/* Set column types */
	for (i = 0; i < prob->numVariables; i++) {
		LPvariableType type = prob->varTypes[i];

		if (type == LPtypeInteger || type == LPtypeBool)
			clp->setInteger(i);
	}

	/* Setup rows */
	delete build;
	build = new CoinBuild();

	i = 0;
	foreach(c, prob->ctrs)
	{
		Sl_Ctr *ne = (Sl_Ctr*) lfirst(c);
		pg_LPfunction *poly = DatumGetLPfunction(sl_ctr_get_x_val(ne));
		double rowLower, rowUpper;
		LPfunctionType poly_type;
		double value;
		int j;

		Assert(poly != NULL);

		/* Moves the factor0 to the value side */
		value = ne->c_val - poly->factor0;

		/* We treat constraints differently depending on the function type */
		/* Detect the constraint type */
		poly_type = get_function_type(prob, poly);

		if (poly_type == LPfunctionEmpty)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg ("SolverLP: Cannot handle constraints involving no unknown variables in constraint query %d", i), errdetail("Please check your query.")));

		rowLower = rowUpper = 0; /* Initial */

		/* We can handle negation for booleans */
		if ((poly_type == LPfunctionBool) && (ne->op == SL_CtrType_NE)) {
			/* Inverse the value: glp_set_row_bnds(lp, i + 1, GLP_FX, 1 - value, 1 - value); */
			rowLower = 1 - value;
			rowUpper = 1 - value;
		} else if ((poly_type == LPfunctionInteger)
				&& (ne->op == SL_CtrType_LT)) {
			/* We can handle LT AND GT for integers: glp_set_row_bnds(lp, i + 1, GLP_LO, value - 1, 0); */
			rowLower = value - 1;
			rowUpper = COIN_DBL_MAX;
		} else if ((poly_type == LPfunctionInteger)
				&& (ne->op == SL_CtrType_GT)) {
			// glp_set_row_bnds(lp, i + 1, GLP_UP, 0, value + 1); // Fix from "value + 1, 0"
			rowLower = -COIN_DBL_MAX;
			rowUpper = value + 1;
		} else
			switch (ne->op) {
			case SL_CtrType_EQ:
				// glp_set_row_bnds(lp, i + 1, GLP_FX, value, value);
				rowLower = rowUpper = value;
				break;
			case SL_CtrType_GE:
				// glp_set_row_bnds(lp, i + 1, GLP_UP, 0, value);
				rowLower = poly_type == LPfunctionBool ? 0 : -COIN_DBL_MAX;
				rowUpper = value;
				break;
			case SL_CtrType_LE:
				// glp_set_row_bnds(lp, i + 1, GLP_LO, value, 0);
				rowLower = value;
				rowUpper = COIN_DBL_MAX;
				break;
			default:
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg ("SolverLP: Invalid constraint specified in the constraint query %d", i), errdetail("The solver only supports  =, >=, <= for float and mixed constraints, > and < for integer constraints, and != for boolean constraints")));
				break;
			}

		// Setup indices and bound coefficients
		for (j = 0; j < poly->numTerms; j++) {
			lpTerm * term = &poly->term[j];
			colStart[j] = term->varNr;
			colValue[j] = term->factor;
		}

		i++;

		build->addRow(poly->numTerms, colStart, colValue, rowLower, rowUpper);
	}

	/* Add actual rows */
	((OsiSolverInterface *) clp)->addRows(*build);

	return new CbcModel(*clp);
}


static int callBack(CbcModel * model, int whereFrom)
{
  if (InterruptPending)
	  throw std::runtime_error("Interrupt requested");
  return 0;
}


/*
 * Get the type of the function
 */
inline static LPfunctionType get_function_type(LPproblem * prob, pg_LPfunction * poly)
{
	int 			i;
	LPfunctionType	type = LPfunctionEmpty;

	for(i = 0; i < poly->numTerms; i++)
	{
		LPvariableType	   	var_type;
		LPfunctionType 		var_typep;
		int			   		varNr = poly->term[i].varNr;

		Assert(varNr>= 0 && varNr < prob->numVariables);

		var_type = prob->varTypes[varNr];
		var_typep =  var_type == LPtypeBool    ? LPfunctionBool :
					 var_type == LPtypeInteger ? LPfunctionInteger :
							 	 	 	 	     LPfunctionFloat;

		if (type == LPfunctionEmpty)
			type = var_typep;
		else if (type != var_typep)
		{
			 type = LPfunctionMixed;
			 break;
		}
	}

	return type;
}

/* *************************  SolverLP message handler ************************* */

//-------------------------------------------------------------------
// Default Constructor
//-------------------------------------------------------------------
SolverLP_MessageHandler::SolverLP_MessageHandler ()  : CoinMessageHandler()
{
}

//-------------------------------------------------------------------
// Destructor
//-------------------------------------------------------------------
SolverLP_MessageHandler::~SolverLP_MessageHandler ()
{
}

//-------------------------------------------------------------------
// Clone
//-------------------------------------------------------------------
CoinMessageHandler * SolverLP_MessageHandler::clone() const
{
    return new SolverLP_MessageHandler(*this);
}

int
SolverLP_MessageHandler::print()
{
	/* A PostgreSQL hack to be able to print text continously */
	ErrorContextCallback * old_error_context = error_context_stack;

	error_context_stack = NULL;

	ereport(NOTICE, (errmsg("%s", messageBuffer_)));

	error_context_stack = old_error_context;

	return 0;
}

static inline double time_diff(struct timeval *tod1, struct timeval *tod2)
{
    long long t1, t2;
    t1 = tod1->tv_sec * 1E6 + tod1->tv_usec;
    t2 = tod2->tv_sec * 1E6 + tod2->tv_usec;
    return ((double)(t1 - t2)) / 1E6;
}



/* Do initial solve */
// clp->setHintParam(OsiDoPresolveInInitial,true,OsiHintTry);
// clp->setHintParam(OsiDoDualInInitial,true,OsiHintTry);
// clp->setHintParam(OsiDoScale,false,OsiHintTry);
// clp->setHintParam(OsiDoDualInInitial,true,OsiHintTry);
//clp->initialSolve();
//if (clp->isProvenOptimal())
//		if (is_mip) {
//			// Pass the solver with the problem to be solved to CbcModel
//			CbcModel model(*clp);
//
//           	CbcStrategyDefault strategy(true, 5, 0);
//            CbcRounding heuristic(model);
//            model.addHeuristic(&heuristic);
//            model.setStrategy(strategy);
//            model.setLogLevel(0);
//
//			// Do complete search
//			model.branchAndBound(0);
//
//			/*
//			 * Saves the solution.
//			 * */
//			const double * solution = model.bestSolution();
//
//			if (solution != NULL) {
//				LPsolverResult * result = new LPsolverResult();
//				/* CbcModel clones the solver so we need to get current copy from the CbcModel */
//				result->numVariables = model.solver()->getNumCols();
//				result->varIndices = new int[result->numVariables];
//				result->varValues = new double[result->numVariables];
//				for (i = 0; i < result->numVariables; i++) {
//					result->varIndices[i] = i;
//					result->varValues[i] = solution[i];
//				}
//				return result;
//			}
//		}
