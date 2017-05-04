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

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

- A Linux-based distribution, with kernel 3.19 or higher (test on Ubuntu 14.04-16.04), with superuser permission
- Basic development tools: make, gcc, g++
- XXX mb of free space


### Installing

SolveDB can be installed by terminal with the scripts provided in the installation folder. The scripts will download the source code for
- postgresql 9.6.0
-

and patch with the SolveDB additions.

**Installation steps**
Open the terminal at the SolveDB installation folder, and run the following commands
```
./1_AssembleAll.sh
```
Downloads and patches the source codes
```
./2_buildAll.sh
```
Installs the required libraries, and builds postgresql, SolveDB, and the included solvers.

If the installation is successful, the final output will be
```

```

**Setup Postgresql server and user**
To utilize postgresql, it is needed to create a user with privileges to the database folder. Open the terminal at the SolveDB installation folder:

```
adduser postgres
mkdir /usr/local/pgsql/data
chown postgres /usr/local/pgsql/data
```


Initialize postgtresql (only the first time OR if some errors are encountered. In this case, remove the content of /usr/local/pgsql/data and execute the following lines again)
```
6 su - postgres
7 /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data
```

Start the postgresql server (to be done every time you restart the machine)

```
/usr/local/pgsql/bin/postgres -D /usr/local/pgsql/data 
```

**Install the included Solvers**
The following instructions explain how to install the solvers for linear programming, mixed integer programming, and global black box optimization. From the terminal:

```
su -s postgres
psql
CREATE EXTENSION solverapi;
CREATE EXTENSION solverlp;
CREATE EXTENSION solversw;
```
If no error message is shown, the solvers are succesfully installed.


## Running the tests

To utilize the system it is possible to use the default terminal-based postgresql interface. Alternatively, pgAdmin provides a graphical front-end for interfacing with postgresql. Any version of pgAdmin is compatible with SolveDB, however to have SolveDB syntax highlights in the pgAdmin SQL editor we suggest to compile pgAdmin3 from source. More information in the Section *Setup pgAdmin3 with solveDB* below.

We provide an example of use with psql.


### Setup pgAdmin3 with SolveDB
PgAdmin3 can be used as a GUI for postgresql/SolveDB. In the following, we provide instructions on how to compile pgAdmin3 on SolveDB, in order to enable SolveDB syntax highlighting in the graphical SQL editor. The compliation of pgAdmin on solveDB requires the wxGTK-2.8.12 library (it has not been tested work with later versions). Other additional libraries are required

**Download pgAdmin3 source code**
Open the terminal in the SolveDB installation folder. 
**pgAdmin, wxGTK, and requirements**
```
wget https://ftp.postgresql.org/pub/pgadmin/pgadmin3/v1.20.0/src/pgadmin3-1.20.0.tar.gz
wget https://sourceforge.net/projects/wxwindows/files/2.8.12/wxGTK-2.8.12.tar.gz/download
sudo apt-get install libgtk2.0-dev unixodbc unixodbc-dev libpq-dev python-dev 
  libgtk-3-dev automake autoconf libxml2 libxml2-dev libxslt1.* libxslt1-dev python-sphinx
```
**Install wxWidgets**
```
cd wxGTK-2.8.12/
./configure --with-gtk --enable-gtk2 --enable-unicode
make
sudo make install
ldconfig
cd contrib/
make
sudo make install
```
**Install pgAdmin3**
```
cd ../../pgadmin*
make clean
autoreconf -f -i
./configure
mkdir parser
cd parser 
wget http://www.markmcfadden.net/files/kwlist.h 
cd ../
make all
make install
```

**Testing pgAdmin3**
The executable file of pgAdmin3 is located in the folder *pgadmin3-1.20.0/pgadmin*, from there run from GUI or run
```
./pgadmin3
```
PgAdmin might give some compatibility warnings. However, none of these will affect the correct functioning of postgresql and solveDB. Just skip through them.
To create a new database connection
```
name: your_db_name
host: localhost
username: postgres 
password: your_password
```

Navigate to the db schema, open the SQL editor and run the following commands (if not done already)
```
CREATE EXTENSION solverapi;
CREATE EXTENSION solverlp;
CREATE EXTENSION solversw;
```

To test if pgAdmin3 is correctly working, you can use the same examples we shown in the previous section **_Running the Tests_**

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Laurynas Siksnys** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

## License

This project is licensed under the Apache License Version 2.0 - see the [LICENSE](LICENSE) file for details

