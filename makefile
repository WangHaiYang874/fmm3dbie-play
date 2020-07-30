# Makefile for fmm3dbie
# # This is the only makefile; there are no makefiles in subdirectories.
# Users should not need to edit this makefile (doing so would make it
# hard to stay up to date with repo version). Rather in order to
# change OS/environment-specific compilers and flags, create 
# the file make.inc, which overrides the defaults below (which are 
# for ubunutu linux/gcc system). 

# compiler, and linking from C, fortran
CC = gcc
CXX = g++
FC = gfortran
FFLAGS = -fPIC -O3 -march=native -funroll-loops -std=legacy 

# extra flags for multithreaded: C/Fortran, MATLAB
OMPFLAGS =-fopenmp
OMPLIBS =-lgomp 

FMMBIE_INSTALL_DIR=$(PREFIX)
ifeq ($(PREFIX),)
	FMMBIE_INSTALL_DIR = ${HOME}/lib
endif

FMM_INSTALL_DIR=$(PREFIX_FMM)
ifeq ($(PREFIX_FMM),)
	FMM_INSTALL_DIR=${HOME}/lib
endif

LBLAS = -lblas -llapack

LIBS = -lm
DYLIBS = -lm

LIBNAME=libfmm3dbie
DYNAMICLIB = $(LIBNAME).so
STATICLIB = $(LIBNAME).a
LIMPLIB = $(DYNAMICLIB)

LFMMLINKLIB = -lfmm3d
LLINKLIB = -lfmm3dbie


# For your OS, override the above by placing make variables in make.inc
-include make.inc

# update libs and dynamic libs to include appropriate versions of
# fmm3d
#
# Note: the static library is used for DYLIBS, so that fmm3d 
# does not get bundled in with the fmm3dbie dynamic library
#
LIBS += -L$(FMM_INSTALL_DIR) $(LFMMLINKLIB) 
DYLIBS += -L$(FMM_INSTALL_DIR) $(LFMMLINKLIB)

# multi-threaded libs & flags needed
ifneq ($(OMP),OFF)
  FFLAGS += $(OMPFLAGS)
  LIBS += $(OMPLIBS)
  DYLIBS += $(OMPLIBS)
endif

LIBS += $(LBLAS) $(LDBLASINC)
DYLIBS += $(LBLAS) $(LDBLASINC)



# objects to compile
#
# Common objects
COM = src/common
COMOBJS = $(COM)/cumsum.o $(COM)/hkrand.o $(COM)/dotcross3d.o \
	$(COM)/dlaran.o $(COM)/lapack_wrap.o \
	$(COM)/legeexps.o $(COM)/prini_new.o \
	$(COM)/rotmat_gmres.o $(COM)/setops.o \
	$(COM)/sort.o $(COM)/sparse_reps.o 

# FMM wrappers
FMML = src/fmm_wrappers
FOBJS = $(FMML)/hfmm3d_ndiv.o $(FMML)/lfmm3d_ndiv.o 

# Helmholtz wrappers
HELM = src/helm_wrappers
HOBJS = $(HELM)/helm_comb_dir.o

# Laplace wrappers
LAP = src/lap_wrappers
LOBJS = $(LAP)/lap_comb_dir.o

# Kernels
KER = src/kernels
KOBJS = $(KER)/helm_kernels.o $(KER)/lap_kernels.o

# Quadrature wrappers
QUAD = src/quadratures
QOBJS = $(QUAD)/far_field_routs.o \
	$(QUAD)/ggq-selfquad-routs.o $(QUAD)/ggq-quads.o \
	$(QUAD)/ggq-selfquad.o \
	$(QUAD)/near_field_routs.o

# Surface wrappers
SURF = src/surface_routs
SOBJS = $(SURF)/in_go3.o $(SURF)/surf_routs.o $(SURF)/vtk_routs.o \
	$(SURF)/xtri_routs/xtri_parameterizations.o \
	$(SURF)/xtri_routs/xtri_plot.o

# Triangle adaptive integration routines
TRIA = src/tria_routs
TOBJS = $(TRIA)/ctriaints_main.o $(TRIA)/koornexps.o \
	$(TRIA)/triaintrouts.o $(TRIA)/dtriaints_main.o \
	$(TRIA)/triasymq.o $(TRIA)/triatreerouts.o $(TRIA)/dtriaintrouts.o


OBJS = $(COMOBJS) $(FOBJS) $(HOBJS) $(KOBJS) $(LOBJS) $(QOBJS) $(SOBJS) $(TOBJS)




.PHONY: usage lib install test test-dyn python 

default: usage

usage:
	@echo "-------------------------------------------------------------------------"
	@echo "Makefile for fmm3dbie. Specify what to make:"
	@echo "  make install - compile and install the main library"
	@echo "  make install PREFIX=(INSTALL_DIR) - compile and install the main library at custom location given by PREFIX"
	@echo "  make lib - compile the main library (in lib/ and lib-static/)"
	@echo "  make test - compile and run validation tests (will take around 30 secs)"
	@echo "  make test-dyn - test successful installation by validation tests linked to dynamic library (will take a couple of mins)"
	@echo "  make python - compile and test python interfaces using python"
	@echo "  make objclean - removal all object files, preserving lib & MEX"
	@echo "  make clean - also remove lib, MEX, py, and demo executables"
	@echo ""
	@echo "For faster (multicore) making, append the flag -j"
	@echo "  'make [task] OMP=ON' for multi-threaded"
	@echo "-------------------------------------------------------------------------"



#
# implicit rules for objects (note -o ensures writes to correct dir)
#
%.o: %.f %.h
	$(FC) -c $(FFLAGS) $< -o $@
%.o: %.f90 
	$(FC) -c $(FFLAGS) $< -o $@



#
# build the library...
#
lib: $(STATICLIB) $(DYNAMICLIB)
ifneq ($(OMP),OFF)
	@echo "$(STATICLIB) and $(DYNAMICLIB) built, multithread versions"
else
	@echo "$(STATICLIB) and $(DYNAMICLIB) built, single-threaded versions"
endif

$(STATICLIB): $(OBJS) 
	ar rcs $(STATICLIB) $(OBJS)
	mv $(STATICLIB) lib-static/

$(DYNAMICLIB): $(OBJS) 
	$(FC) -shared -fPIC $(OMPFLAGS) $(OBJS) -o $(DYNAMICLIB) $(DYLIBS) 
	mv $(DYNAMICLIB) lib/
	[ ! -f $(LIMPLIB) ] || mv $(LIMPLIB) lib/

install: $(STATICLIB) $(DYNAMICLIB)
	echo $(FMMBIE_INSTALL_DIR)
	mkdir -p $(FMMBIE_INSTALL_DIR)
	cp -f lib/$(DYNAMICLIB) $(FMMBIE_INSTALL_DIR)/
	cp -f lib-static/$(STATICLIB) $(FMMBIE_INSTALL_DIR)/
	[ ! -f lib/$(LIMPLIB) ] || cp lib/$(LIMPLIB) $(FMMBIE_INSTALL_DIR)/
	@echo "Make sure to include " $(FMMBIE_INSTALL_DIR) " in the appropriate path variable"
	@echo "    LD_LIBRARY_PATH on Linux"
	@echo "    PATH on windows"
	@echo "    DYLD_LIBRARY_PATH on Mac OSX (not needed if default installation directory is used"
	@echo " "
	@echo "In order to link against the dynamic library, use -L"$(FMMBIE_INSTALL_DIR)  " "$(LLINKLIB) " -L"$(FMM_INSTALL_DIR)  " "$(LFMMLINKLIB)


#
# testing routines
#
test: $(STATICLIB) test/com test/hwrap test/tria test/lwrap test/surf
	cd test/common; ./int2-com
	cd test/helm_wrappers; ./int2-helm
	cd test/lap_wrappers; ./int2-lap
	cd test/surface_routs; ./int2-surf
	cd test/tria_routs; ./int2-tria
	cat print_testres.txt
	rm print_testres.txt

test-dyn: $(DYNAMICLIB) test/com-dyn test/hwrap-dyn test/tria-dyn test/lwrap-dyn test/surf-dyn
	cd test/common; ./int2-com
	cd test/helm_wrappers; ./int2-helm
	cd test/lap_wrappers; ./int2-lap
	cd test/surface_routs; ./int2-surf
	cd test/tria_routs; ./int2-tria
	cat print_testres.txt
	rm print_testres.txt

test/com: 
	$(FC) $(FFLAGS) test/common/test_common.f -o test/common/int2-com lib-static/$(STATICLIB) $(LIBS) 

test/hwrap:
	$(FC) $(FFLAGS) test/helm_wrappers/test_helm_wrappers_qg_lp.f -o test/helm_wrappers/int2-helm lib-static/$(STATICLIB) $(LIBS) 

test/lwrap:
	$(FC) $(FFLAGS) test/lap_wrappers/test_lap_wrappers_qg_lp.f -o test/lap_wrappers/int2-lap lib-static/$(STATICLIB) $(LIBS) 

test/surf:
	$(FC) $(FFLAGS) test/surface_routs/test_surf_routs.f -o test/surface_routs/int2-surf lib-static/$(STATICLIB) $(LIBS) 

TTOBJS = test/tria_routs/test_triaintrouts.o test/tria_routs/test_dtriaintrouts.o test/tria_routs/test_koornexps.o

test/tria: $(TTOBJS)
	$(FC) $(FFLAGS) test/tria_routs/test_triarouts.f -o test/tria_routs/int2-tria $(TTOBJS) lib-static/$(STATICLIB) $(LIBS) 


#
# Linking test files to dynamic libraries
#


test/com-dyn:
	$(FC) $(FFLAGS) test/common/test_common.f -o test/common/int2-com -L$(FMM_INSTALL_DIR) -L$(FMMBIE_INSTALL_DIR) $(LFMMLINKLIB) $(LLINKLIB)

test/hwrap-dyn:
	$(FC) $(FFLAGS) test/helm_wrappers/test_helm_wrappers_qg_lp.f -o test/helm_wrappers/int2-helm -L$(FMM_INSTALL_DIR) -L$(FMMBIE_INSTALL_DIR) $(LFMMLINKLIB) $(LLINKLIB)

test/lwrap-dyn:
	$(FC) $(FFLAGS) test/lap_wrappers/test_lap_wrappers_qg_lp.f -o test/lap_wrappers/int2-lap -L$(FMM_INSTALL_DIR) -L$(FMMBIE_INSTALL_DIR) $(LFMMLINKLIB) $(LLINKLIB)

test/surf-dyn:
	$(FC) $(FFLAGS) test/surface_routs/test_surf_routs.f -o test/surface_routs/int2-surf -L$(FMM_INSTALL_DIR) -L$(FMMBIE_INSTALL_DIR) $(LFMMLINKLIB) $(LLINKLIB)

test/tria-dyn: $(TTOBJS)
	$(FC) $(FFLAGS) test/tria_routs/test_triarouts.f -o test/tria_routs/int2-tria $(TTOBJS) -L$(FMM_INSTALL_DIR) -L$(FMMBIE_INSTALL_DIR) $(LFMMLINKLIB) $(LLINKLIB)


#
# build the python bindings/interface
#
python: $(STATICLIB)
	cd python && export FMMBIE_LIBS='$(LIBS)' && pip install -e . 

#
# housekeeping routines
#
clean: objclean
	rm -f lib-static/*.a lib/*.so
	rm -f test/common/int2-com
	rm -f test/helm_wrappers/int2-helm
	rm -f test/tria_routs/int2-tria
	rm -f python/*.so
	rm -rf python/build
	rm -rf python/fmm3dpy.egg-info

objclean: 
	rm -f $(OBJS) $(TOBJS)
	rm -f test/helm_wrappers/*.o test/common/*.o 
	rm -f test/tria_routs/*.o examples/helm_dir/*.o 
