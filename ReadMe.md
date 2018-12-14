# How to Install and Run MATPOWER with HELICS #
***************************************
_Copyright (C) 2018, Battelle Memorial Institute_  
_Authors: **Laurentiu Dan Marinovici**_
		      **Jacob Hansen**_
		      **Gayathri Krishnamoorthy**_
***************************************

This documentation details: 
	 - installing MCR (MATLAB Compiler Runtime) which is used as a wrapper for MATLAB to perform transmission simulation
	 - how to use the developed wrapper to perform a simple T&D co-simulation.
	 
Requires:
	 - A compatible version of MCR downladed and installed.
	 - HELICS - 2.0 downloaded and installed 
	 - Gridlab-d installed with HELICS

Installing MCR:
	 - MATPOWER PF/OPF resides as a shared object in libMATPOWER.so, after being compiled on a computer with a complete version of MATLAB intalled.
	 - Running the MATPOWER functions requires that at least MATLAB Compiler Runtime (MCR) (downloaded for free from MATHWORKS webpage) is installed. Make sure the MCR is the same version as the MATLAB under which the compilation has been done (In this case, MATLAB R2018a and its corresposnding version 9.4 of MCR is used)
	 
Downloading the Matpower Wrapper and installing it:
	- Download all the wrapper files into a folder.
	- The paths in the 'Make file' needs to be changed to include HELICS Installation path, gridlab-d installation path and path to install the matpower executables.
	- run "make" and "make install" from the terminal. This downloads the executables to the specified path.
	

## Launching the MATPOWER Power Flow / Optimal Power Flow solver from a C++ wrapper ##
****************************************
****************************************

Main purposes of the "wrapper", that is the code in the C++ file ```start_MATPOWER.cpp```:
  - Read the MATPOWER data file that resides in a .m file (the MATPOWER case file),
  - Create the data structure needed by the MATPOWER solvers, calls the solver (runpf or runopf), and returns the results.

Files needed for deployment (for this case, at least, in order to be able to compile):
  - ```start_MATPOWER.cpp``` - main file,
  - ```libMATPOWER.h```, ```libMATPOWER.so``` - MATPOWER compiled object for deployment under Linux,
  - ```case9.m```, or any other - MATPOWER case file, that needs to have extra data added - to define the number of distribution systems connected, etc.
  - ```matpowerintegrator.h```, ```matpowerintegrator.cpp``` - files for MATPOWER-HELICS integration.
 
start_MATPOWER.cpp performs the following: 
      - Run with multiple instances of GridLAB-D/distribution feeders.
      - Ability to change the generation/trsnmission topology, by making on generator go off-line.
      - Ability to run both the regular power flow and the optimal power flow.
      - Ability to receive as many load profiles as neccessary  depending on the number of substations. This dictates real-life one day load profile.  
      - Basically, the load profile data comes into a file containing 288 values per row (every 5-minute data for 24 hours), and a number of rows greater than or equal to the number of substations.
	    - The values exchanged (publications and subscriptions) between the simulators are nicely given in a JSON format. They are several other HELICS parameters that can directly be intialized in this JSON script. 

The simpleTD_example folder has:
		- A distribution feeder model (In this case, 123 node model)
		- matpower folder (with matpower 9 bus system, real, reactive and renewable load profiles.
		- runAll - shell script (to initialize the HELICS brokers, and start the federates with their specific arguments as inputs) - Run this shell script to start the T&D co-simualtion. 
		