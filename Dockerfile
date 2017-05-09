#
# GROMED : GRO[macs] + [plu]MED
#
# For many reasons we need to fix the ubuntu release:
FROM ubuntu:17.04
#
MAINTAINER roberto innocente <inno@sissa.it>
#
#
ARG DEBIAN_FRONTEND=noninteractive
#
#
# we update the apt database
#
RUN  apt-get -yq update 
#
# we install vim openssh, sudo, wget, gfortran, openblas, blacs,
# fftw3, openmpi , ...
# and run ssh-keygen -A to generate all possible keys for the host
#
RUN apt install -yq vim \
		git \
		cmake \
 		openssh-server  \
 		sudo  \
 		wget  \
         	ca-certificates  \
		g++ \
		gnuplot \
		xxdiff \
		gawk \
         	libopenblas-base  \
         	libopenblas-dev  \
 		openmpi-bin   \
         	libfftw3-3  \
 		libfftw3-bin  \
  		libfftw3-dev  \
         	libfftw3-double3   \
 		libblacs-openmpi1  \
 		libblacs-mpi-dev  \
		libmatheval1 \
		libmatheval-dev \
 		net-tools  \
 		make  \
 		autoconf  \
 		libopenmpi-dev  \
 		libgfortran-6-dev  \
 		gfortran-6  \
                python3-numpy \
                python3-scipy \
                zlib1g zlib1g-dev \
	&& apt autoremove \
	&& ssh-keygen -A
#
# we create the user 'gromed' and add it to the list of sudoers
RUN  adduser -q --disabled-password --gecos gromed gromed  \
	&& echo "gromed ALL=(ALL:ALL) NOPASSWD:ALL" >>/etc/sudoers  \
	&& (echo "gromed:mammamia"|chpasswd)
#
# disable  ssh strict mode
#
RUN sed -i 's#^StrictModes.*#StrictModes no#' /etc/ssh/sshd_config \
	&& service   ssh  restart  
#
# download and compile sources.
#
WORKDIR /home/gromed
ENV     GR_HD="/home/gromed" \
   	GR_VER="-5.1.4" \
   	PL_VER="master"  
#
# First : setup PLUMED
#
RUN     cd ${GR_HD} \
	&& GR_CORES=`cat /proc/cpuinfo |grep 'cpu cores'|uniq|sed -e 's/.*://'` \
	&& git clone https://github.com/plumed/plumed2.git \
	&& cd plumed2 \
	&& git checkout ${PL_VER} \
	&& ./configure CXXFLAGS=-O3 \
	&& make -j $((2*GR_CORES)) \
        && make install

#
# Second : setup GROMACS
#
RUN 	wget http://ftp.gromacs.org/pub/gromacs/gromacs${GR_VER}.tar.gz \
	&& tar xfz gromacs${GR_VER}.tar.gz \
	&& cd gromacs${GR_VER}  \
	&& plumed patch -p -e gromacs${GR_VER} \
        && GR_SIMD="None SSE2 SSE4.1 AVX_256 AVX2_256 AVX_512" \
        && if [ __TRAVIS__ = true ] ; then GR_SIMD="SSE2" ; fi \
	&& GR_CORES=`cat /proc/cpuinfo |grep 'cpu cores'|uniq|sed -e 's/.*://'` \
	&& for item in $GR_SIMD; do \
		mkdir -p build-"$item" ; \
		(cd build-"$item"; cmake .. \
			-DGMX_SIMD="$item" -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx  \
			-DGMX_THREAD_MPI:BOOL=OFF -DGMX_MPI:BOOL=ON ; make -j $((2*GR_CORES)) ); \
	   done \
	&&  (cd build-SSE2; make install) \
	&&  echo "export PATH=/usr/local/gromacs/bin:${PATH}" >>${GR_HD}/.bashrc \
	&&  echo "source /usr/local/gromacs/bin/GMXRC" >>${GR_HD}/.bashrc

#
# move tarballs in downloads/ directory
#
RUN    	mkdir downloads \
	&& mv gromacs${GR_VER}.tar.gz downloads/
#
COPY	tune-gromacs.sh ${GR_HD}/gromacs${GR_VER}/
#
# change owner to gromed:gromed
#
RUN	chown -R gromed:gromed /home/gromed
#
WORKDIR /home/gromed
#
EXPOSE 22
#
#
# the container can be now reached via ssh
CMD [ "/usr/sbin/sshd","-D" ]


