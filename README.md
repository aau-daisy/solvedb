# SolveDB: A PostgreSQL-based DBMS for optimization applications

SolveDB is a Database Management Systems (DBMS) with the native support for *optimization*, *constraint satisfaction*, and *domain-specific* problems. 
The current version of SolveDB is based on PostgreSQL 9.6 and it comes with a number of pre-installed solvers for linear programming (LP), mixed-integer programming (MIP), global black-box 
optimization (GO), and domain-specific problems. 

SolveDB aims at making database-based problem specification and solving much more *easy*, *user-friendly*, and *efficient*. To achieve these goals, SolveDB integrates solvers into 
the DBMS backend, offers in-DBMS processing optimizations, and provides a common language for database queries, problem specification, and user-defined solvers.
Users may specify and solve their problems using a single so-called solve query in the following intuitive SQL-based syntax:

```
  SOLVESELECT col_name [, ...] IN ( select_stmt ) [AS alias]
       [ WITH col_name [, ...] IN ( select_stmt )  AS alias [, ...] ]
[ MINIMIZE ( select_stmt ) [ MAXIMIZE ( select_stmt ) ] |
  MAXIMIZE ( select_stmt ) [ MINIMIZE ( select_stmt ) ] ]
[ SUBJECTTO ( select_stmt ) [, ...] ]
[ USING solver_name [. ...] [( param[:= expr] [, ...] )] ]
```

More details can be found on our [Daisy Website](http://daisy.aau.dk/solvedb)

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

What things you need to install the software and how to install them

```
Give examples
```

### Installing

A step by step series of examples that tell you have to get a development env running

Say what the step will be

```
Give the example
```

And repeat

```
until finished
```

End with an example of getting some data out of the system or using it for a little demo

## Running the tests

Explain how to run the automated tests for this system

### Break down into end to end tests

Explain what these tests test and why

```
Give an example
```

### And coding style tests

Explain what these tests test and why

```
Give an example
```

## Deployment

Add additional notes about how to deploy this on a live system

## Built With

* [Dropwizard](http://www.dropwizard.io/1.0.2/docs/) - The web framework used
* [Maven](https://maven.apache.org/) - Dependency Management
* [ROME](https://rometools.github.io/rome/) - Used to generate RSS Feeds

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Billie Thompson** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the Apache License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc
