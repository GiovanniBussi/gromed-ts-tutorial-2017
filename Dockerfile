#
# GROMED : GRO[macs] + [plu]MED
#
# For many reasons we need to fix the ubuntu release:
FROM ubuntu:17.04
#
MAINTAINER roberto innocente <inno@sissa.it>, giovanni bussi <bussi@sissa.it>
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
	&& apt autoremove \
	&& ssh-keygen -A
#
# we create the user 'gromed' and add it to the list of sudoers
RUN  adduser -q --disabled-password --gecos gromed gromed  \
	&& echo "gromed 	NOPASSWD:ALL ALL=(ALL:ALL) ALL" >>/etc/sudoers  \
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
#
# First : setup PLUMED
#
RUN wget http://people.sissa.it/~inno/plumed-2.3.1.tgz  \
	&& tar xfz plumed-2.3.1.tgz \
	&& cd /home/gromed/plumed-2.3.1 \
	&& echo 'export plumedir="/home/gromed/plumed-2.3.1"' >>/home/gromed/.bashrc \
	&& echo 'export PLUMED_ROOT="/home/gromed/plumed-2.3.1"' >>/home/gromed/.bashrc \
	&& echo 'export PLUMED_PREFIX="/home/gromed/plumed-2.3.1"' >>/home/gromed/.bashrc \
	&& ./configure \
	&& source sourceme.sh ; make ; make install

#
# Second : setup GROMACS
#
RUN wget http://ftp.gromacs.org/pub/gromacs/gromacs-2016.3.tar.gz \
	&& tar xfz gromacs-2016.3.tar.gz \
	&& cd gromacs-2016.3  \
	&& plumed patch -p -e gromacs-2016.3 \
	&& GR_SIMD="None SSE2 SSE4.1 AVX_256 AVX2_256 AVX_512" \
	&& GR_CORES=`cat /proc/cpuinfo |grep 'cpu cores'|uniq|sed -e 's/.*://'` \
	&& for item in $GR_SIMD; do \
		mkdir -p build-"$item" ; \
		(cd build-"$item"; cmake ..  -DGMX_SIMD="$item" ; make -j $GR_CORES ); \
	   done \
	&&  (cd build-SSE2; make install) \
	&&  echo "export PATH=/usr/local/gromacs/bin:${PATH}" >>/home/gromed/.bashrc \
	&&  echo "source /usr/local/gromacs/bin/GMXRC" >>/home/gromed/.bashrc

#
# move tarballs in downloads/ directory
#
RUN    	mkdir downloads \
	&& mv gromacs-2016.3.tar.gz plumed-2.3.1.tgz downloads/
#
# get from github and copy tuning script inside gromacs directory
#
RUN	wget 	https://raw.githubusercontent.com/rinnocente/gromed/edits/tune-gromacs.sh \
	&& mv tune-gromacs.sh gromacs-2016.3/

#
# change owner to gromed:gromed
#
RUN	chown -R gromed:gromed /home/gromed

WORKDIR /home/gromed

EXPOSE 22

#
# the container can be now reached via ssh
CMD [ "/usr/sbin/sshd","-D" ]


