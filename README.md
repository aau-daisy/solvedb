# SolveDB: A PostgreSQL-based DBMS for optimization applications

SolveDB is a Database Management Systems (DBMS) with the native support for *optimization*, *constraint satisfaction*, and *domain-specific* problems. The current version of SolveDB is based on PostgreSQL 9.6 and it comes with a number of pre-installed solvers for *linear programming* (LP), *mixed-integer programming* (MIP), *global black-box optimization* (GO), and *domain-specific* problems. For actual computations, these solvers use open-source [GLPK](https://www.gnu.org/software/glpk/), [CBC](https://projects.coin-or.org/Cbc), and [SwarmOPS](http://www.hvass-labs.org/projects/swarmops/) libraries, specially modified to run inside a PostgreSQL backend.

SolveDB targets users (analysts) who are familiar with SQL (Structured Query Language) and need to deal with optimization problems that rely on data from a database. Fur such users and problems, SolveDB aims at making problem specification and solving much more *easy*, *user-friendly*, and *efficient*. To achieve these goals, SolveDB integrates general-purpose solvers into the DBMS backend, offers in-DBMS processing optimizations, and provides a common SQL-based language for database queries, problem specification, and declerative domain-specific user-defined solvers. Users may specify and solve their problems using a single so-called solve query in the following intuitive SQL-based syntax:

```
  SOLVESELECT col_name [, ...] IN ( select_stmt ) [AS alias]
       [ WITH col_name [, ...] IN ( select_stmt )  AS alias [, ...] ]
[ MINIMIZE ( select_stmt ) [ MAXIMIZE ( select_stmt ) ] |
  MAXIMIZE ( select_stmt ) [ MINIMIZE ( select_stmt ) ] ]
[ SUBJECTTO ( select_stmt ) [, ...] ]
[ USING solver_name [. ...] [( param[:= expr] [, ...] )] ]
```

Problem specification examples and additional details can be found on [Daisy Website](http://daisy.aau.dk/solvedb)

## Getting Started

Try-out SolveDB (with all its solvers) quickly by downloading this pre-configured [SolveDB Lubuntu Image](https://drive.google.com/open?id=0BztSwe5YpUt7SWx0NlRLVC1mRG8), and then running it on [Virtual Box](https://www.virtualbox.org).

Alternativelly, the instructions below explain how to get a copy of SolveDB (with all pre-installed solvers) up and running on your local machine from its source code.

### Prerequisites

- A Linux-based distribution, with Kernel 3.19 or higher (test on Ubuntu 14.04-16.04), with superuser permissions
- Basic development tools: make, gcc, g++
- 1GB of free disc space

### Installing

SolveDB is *assembled*, *configured*, *compiled*, and *installed* by running a number of scripts in the installation folder. The scripts will download the source code of the following dependencies:
- postgresql 9.6.0
- glpk-4.47
- SwarmOps1_2
- RandomOps1_2

The source code of these dependencies will be automatically patched with the SolveDB additions.

**Installation steps**
Open the terminal at the SolveDB installation folder, and run the following commands
```
$ ./1_assembleAll.sh
$ ./2_buildAll.sh
```
These will download and patch the source code, install the required libraries, and build SolveDB and the included solvers. If the execution completes without an error, all the components are installed correctly.

**Setup Postgresql server and user**
Running SolveDB (PostgreSQL) requires creating a user. In the example below, we create a *postgres* user and grant rights to access the standard database folder:

```
$ sudo adduser postgres
$ sudo mkdir /usr/local/pgsql/data
$ chown postgres /usr/local/pgsql/data
```
SolveDB (PostgreSQL) requires creating a new database cluster (only for the first time):
```
$ su - postgres
$ /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data
```
If some errors are encountered, remove the content of /usr/local/pgsql/data, fix the problem, and execute the commands again.

SolveDB (PostgreSQL) server can be started using the following command (to be done every time you restart the machine):

```
$ /usr/local/pgsql/bin/postgres -D /usr/local/pgsql/data 
```

**Install the included Solvers**
The following instructions explain how to install the solvers for linear programming, mixed integer programming, and global black box optimization into a current database. Run the following commands in the terminal window:

```
$ su - postgres
$ psql
postgres=# CREATE EXTENSION solverapi;
postgres=# CREATE EXTENSION solverlp;
postgres=# CREATE EXTENSION solversw;
```
If no error message is shown, the solvers are succesfully installed. Note, other SolveDB solvers are installed analogously.


## Running the tests

We provide examples of SolveDB problems in the [DemoQueries](DemoQueries) folder, as well as a number of user-defined solvers in the [DemoSolvers](DemoSolvers) folder.

To solve these example problems as well as any other user-specified problems, it is possible to use the default terminal-based PostgreSQL interface (psql). Alternatively, pgAdmin provides a graphical front-end for interfacing with SolveDB (PostgreSQL). Any version of pgAdmin is compatible with SolveDB, however to have SolveDB syntax highlights in the pgAdmin SQL editor we suggest to compile pgAdmin3 from source. More information in the Section *Setup pgAdmin3 with solveDB* below.

### Setup pgAdmin3 with SolveDB
PgAdmin3 can be used as a GUI for SolveDB (PostgreSQL). In the following, we provide instructions on how to compile pgAdmin3 on SolveDB, in order to enable SolveDB syntax highlighting in the graphical SQL editor. The compliation of pgAdmin on SolveDB requires the wxGTK-2.8.12 library (it has not been tested work with later versions). Other additional libraries are required.

**Download pgAdmin3 source code**
Open the terminal in the SolveDB installation folder. 

**pgAdmin, wxGTK, and requirements**
```
$ wget https://ftp.postgresql.org/pub/pgadmin/pgadmin3/v1.20.0/src/pgadmin3-1.20.0.tar.gz
$ wget https://sourceforge.net/projects/wxwindows/files/2.8.12/wxGTK-2.8.12.tar.gz/download
$ sudo apt-get install libgtk2.0-dev unixodbc unixodbc-dev libpq-dev python-dev 
  libgtk-3-dev automake autoconf libxml2 libxml2-dev libxslt1.* libxslt1-dev python-sphinx libssl-dev
$ tar -xzf download
$ tar -xzf pgadmin3-1.20.0.tar.gz
```
**Install wxWidgets**
```
$ cd wxGTK-2.8.12/
$ ./configure --with-gtk --enable-gtk2 --enable-unicode
$ make
$ sudo make install
$ sudo ldconfig
$ cd contrib/
$ make
$ sudo make install
```
**Install pgAdmin3**
```
$ cd ../../pgadmin*
$ autoreconf -f -i
$ ./configure
$ mkdir parser
$ cd parser 
$ wget http://www.markmcfadden.net/files/kwlist.h 
$ cd ../
$ make all
$ sudo make install
```

**Testing pgAdmin3**
The executable file of pgAdmin3 is located in the folder *pgadmin3-1.20.0/pgadmin*. From there, run 
```
$ ./pgadmin3
```
PgAdmin might give some compatibility warnings. However, none of these will affect the correct functioning of SolveDB (PostgreSQL). Just skip through them.
Create a new database connection, with some test parameters
```
name: your_db_name
host: localhost
username: postgres 
password: your_password
```

Navigate to your preferred database, open the SQL editor and run the following commands (if not done already):
```
CREATE EXTENSION solverapi;
CREATE EXTENSION solverlp;
CREATE EXTENSION solversw;
```

To test if pgAdmin3 is correctly working, you can use the same examples we shown in the previous section **_Running the Tests_**

## Contributing

Anyone is welcome to contribute to this SolveDB project. Please state all our changes explicitly  in the attached CHANGELOG file.

## Versioning

* v2.0.0 - An initial GITHUB-compatible SolveDB version was added.

## Authors

* **Laurynas Siksnys** - SolveDB architecture and core implementation, solver implementation, and configuration
* **Torben Bach Pedersen** - SolveDB conceptual design 
* **Davide Frazzetto** - SolveDB configuration / installation scripts, documentation, etc.

## License

This project is licensed under the Apache License Version 2.0 - see the [LICENSE](LICENSE) file for details. All SolveDB dependencies (PostgreSQL, GLPK, CBC, SwarmOPS) are distributed under their own terms and are not bundled with SolveDB (instead, they are downloaded during the assembly phase).

