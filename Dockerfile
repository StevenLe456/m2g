FROM neurodebian:bionic-non-free
LABEL author="Ross Lawrence, Alex Loftus"
LABEL maintainer="rlawre18@jhu.edu"

#--------Environment Variables-----------------------------------------------#
ENV M2G_URL https://github.com/neurodata/m2g.git
ENV M2G_ATLASES https://github.com/neurodata/neuroparc.git
ENV AFNI_URL https://files.osf.io/v1/resources/fvuh8/providers/osfstorage/5a0dd9a7b83f69027512a12b
ENV LIBXP_URL http://mirrors.kernel.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_amd64.deb
ENV LIBPNG_URL http://mirrors.kernel.org/debian/pool/main/libp/libpng/libpng12-0_1.2.49-1%2Bdeb7u2_amd64.deb
ARG DEBIAN_FRONTEND=noninteractive

#--------Initial Configuration-----------------------------------------------#
# download/install basic dependencies, and set up python
RUN apt-get update && \
    apt-get install -y apt-utils zip unzip vim git curl libglu1 python3-setuptools zlib1g-dev \
    git libpng-dev libfreetype6-dev pkg-config g++ vim r-base-core libgsl0-dev build-essential \
    openssl

# upgrade python to solve TLS issues
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get update && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.8 python3.8-dev && \
    curl https://bootstrap.pypa.io/get-pip.py | python3.8

# Install Ubuntu dependencies and utilities
RUN apt-get install -y build-essential cmake git \
      graphviz graphviz-dev gsl-bin libcanberra-gtk-module libexpat1-dev \
      libgiftiio-dev libglib2.0-dev libglu1-mesa libglu1-mesa-dev \
      libjpeg-progs libgl1-mesa-dri libglw1-mesa libxml2 libxml2-dev \
      libxext-dev libxft2 libxft-dev libxi-dev libxmu-headers \
      libxmu-dev libxpm-dev libxslt1-dev m4 make mesa-common-dev \
      mesa-utils netpbm pkg-config rsync tcsh unzip vim xvfb \
      xauth zlib1g-dev

RUN apt-get update

RUN pip3.8 install --upgrade pip

# #---------AFNI INSTALL--------------------------------------------------------#
# # setup of AFNI, which provides robust modifications of many of neuroimaging algorithms
RUN apt-get update -qq && apt-get install -yq --no-install-recommends ed gsl-bin libglu1-mesa-dev libglib2.0-0 libglw1-mesa fsl-atlases \
    libgomp1 libjpeg62 libxm4 netpbm tcsh xfonts-base xvfb && \
    libs_path=/usr/lib/x86_64-linux-gnu && \
    if [ -f $libs_path/libgsl.so.19 ]; then \
    ln $libs_path/libgsl.so.19 $libs_path/libgsl.so.0; \
    fi

RUN mkdir -p /opt/afni
RUN curl -o afni.tar.gz -sSLO "$AFNI_URL"
RUN tar zxv -C /opt/afni --strip-components=1 -f afni.tar.gz
RUN rm -rf afni.tar.gz
ENV PATH=/opt/afni:$PATH

## --------CPAC INSTALLS-----------------------------------------------------#

# install FSL
RUN apt-get install -y --no-install-recommends \
      fsl-core \
      fsl-atlases \
      fsl-mni152-templates

# Setup FSL environment
ENV FSLDIR=/usr/share/fsl/5.0 \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    POSSUMDIR=/usr/share/fsl/5.0 \
    LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
    FSLTCLSH=/usr/bin/tclsh \
    FSLWISH=/usr/bin/wish \
    PATH=/usr/lib/fsl/5.0:$PATH

# install CPAC resources into FSL
RUN curl -sL http://fcon_1000.projects.nitrc.org/indi/cpac_resources.tar.gz -o /tmp/cpac_resources.tar.gz && \
    tar xfz /tmp/cpac_resources.tar.gz -C /tmp && \
    cp -n /tmp/cpac_image_resources/MNI_3mm/* $FSLDIR/data/standard && \
    cp -n /tmp/cpac_image_resources/MNI_4mm/* $FSLDIR/data/standard && \
    cp -n /tmp/cpac_image_resources/symmetric/* $FSLDIR/data/standard && \
    cp -n /tmp/cpac_image_resources/HarvardOxford-lateral-ventricles-thr25-2mm.nii.gz $FSLDIR/data/atlases/HarvardOxford && \
    cp -nr /tmp/cpac_image_resources/tissuepriors/2mm $FSLDIR/data/standard/tissuepriors && \
    cp -nr /tmp/cpac_image_resources/tissuepriors/3mm $FSLDIR/data/standard/tissueprior



# Install 16.04 dependencies
RUN apt-get install -y \
      dh-autoreconf \
      libgsl-dev \
      libmotif-dev \
      libtool \
      libx11-dev \
      libxext-dev \
      x11proto-xext-dev \
      x11proto-print-dev \
      xutils-dev \
      environment-modules


# Install libpng12
RUN curl -sLo /tmp/libpng12.deb http://mirrors.kernel.org/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1_amd64.deb && \
    dpkg -i /tmp/libpng12.deb && \
    rm /tmp/libpng12.deb

# Compiles libxp- this is necessary for some newer versions of Ubuntu
# where the is no Debian package available.
RUN git clone git://anongit.freedesktop.org/xorg/lib/libXp /tmp/libXp && \
    cd /tmp/libXp && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    cd - && \
    rm -rf /tmp/libXp

# Installing and setting up c3d
RUN mkdir -p /opt/c3d && \
    curl -sSL "http://downloads.sourceforge.net/project/c3d/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz" \
    | tar -xzC /opt/c3d --strip-components 1
ENV C3DPATH /opt/c3d/
ENV PATH $C3DPATH/bin:$PATH


# download OASIS templates for niworkflows-ants skullstripping
RUN mkdir /ants_template && \
    curl -sL https://s3-eu-west-1.amazonaws.com/pfigshare-u-files/3133832/Oasis.zip -o /tmp/Oasis.zip && \
    unzip /tmp/Oasis.zip -d /tmp &&\
    mv /tmp/MICCAI2012-Multi-Atlas-Challenge-Data /ants_template/oasis && \
    rm -rf /tmp/Oasis.zip /tmp/MICCAI2012-Multi-Atlas-Challenge-Data

RUN apt-get -f --yes --force-yes install

RUN apt-get --yes --force-yes install insighttoolkit4-python
RUN apt-get update && apt-get -y upgrade insighttoolkit4-python

#--------M2G SETUP-----------------------------------------------------------#
# grab atlases from neuroparc
RUN mkdir /m2g_atlases

RUN \
    git clone https://github.com/neurodata/neuroparc && \
    mv /neuroparc/atlases /m2g_atlases && \
    rm -rf /neuroparc
RUN chmod -R 777 /m2g_atlases


# Grab m2g from deploy.
RUN git clone --branch main https://github.com/StevenLe456/m2g.git /m2g && \
    cd /m2g && \
    pip3.8 install -r /m2g/requirements.txt &&\
    pip3.8 install .
RUN chmod -R 777 /usr/local/bin/m2g_bids



#-----INDI-Tools SETUP-------------------------------------------------------------#
RUN git clone --branch master https://github.com/FCP-INDI/INDI-Tools /INDI-Tools && \
    cd /INDI-Tools && \
    pip3.8 install .


# install ICA-AROMA
RUN mkdir -p /opt/ICA-AROMA
RUN curl -sL https://github.com/rhr-pruim/ICA-AROMA/archive/v0.4.3-beta.tar.gz | tar -xzC /opt/ICA-AROMA --strip-components 1
RUN chmod +x /opt/ICA-AROMA/ICA_AROMA.py
ENV PATH=/opt/ICA-AROMA:$PATH

# install torch
RUN pip3.8 install torch==1.2.0 torchvision==0.4.0 -f https://download.pytorch.org/whl/torch_stable.html

# install PyPEER
RUN pip3.8 install git+https://github.com/ChildMindInstitute/PyPEER.git

WORKDIR /

# Clear apt-get caches (try adding sudo)
RUN apt-get clean

# Installing and setting up c3d
RUN mkdir -p /opt/c3d && \
    curl -sSL "http://downloads.sourceforge.net/project/c3d/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz" \
    | tar -xzC /opt/c3d --strip-components 1
ENV C3DPATH /opt/c3d/
ENV PATH $C3DPATH/bin:$PATH

#--------INSTALL CPAC------------------------------------------------------#
RUN cd / && \
    git clone --branch v1.7.0 --single-branch https://github.com/FCP-INDI/C-PAC.git && \
    mkdir /code && \
    mv /C-PAC/dev/docker_data/* /code/ && \
    mv /C-PAC/* /code/ && \
    rm -R /C-PAC && \
    chmod +x /code/run.py && \
    cd /

# install cpac templates
RUN mv /code/cpac_templates.tar.gz / && \
    tar xvzf /cpac_templates.tar.gz

RUN mkdir /cpac_resources
RUN mv /code/default_pipeline.yml /cpac_resources/default_pipeline.yml
RUN mv /code/dev/circleci_data/pipe-test_ci.yml /cpac_resources/pipe-test_ci.yml

RUN pip3.8 install -e /code

# install AFNI [PUT AFTER CPAC IS CALLED]
RUN mv /code/required_afni_pkgs.txt /opt/required_afni_pkgs.txt
RUN if [ -f /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1.2.0]; then \
        ln -svf /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1.2.0 /usr/lib/x86_64-linux-gnu/libGL.so.1; \
    fi && \
    libs_path=/usr/lib/x86_64-linux-gnu && \
    if [ -f $libs_path/libgsl.so.23 ]; then \
        ln -svf $libs_path/libgsl.so.23 $libs_path/libgsl.so.19 && \
        ln -svf $libs_path/libgsl.so.23 $libs_path/libgsl.so.0; \
    elif [ -f $libs_path/libgsl.so.23.0.0 ]; then \
        ln -svf $libs_path/libgsl.so.23.0.0 $libs_path/libgsl.so.0; \
    elif [ -f $libs_path/libgsl.so ]; then \
        ln -svf $libs_path/libgsl.so $libs_path/libgsl.so.0; \
    fi && \
    LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH && \
    export LD_LIBRARY_PATH && \
    curl -O https://afni.nimh.nih.gov/pub/dist/bin/linux_ubuntu_16_64/@update.afni.binaries && \
    tcsh @update.afni.binaries -package linux_openmp_64 -bindir /opt/afni -prog_list $(cat /opt/required_afni_pkgs.txt) && \
    ldconfig



WORKDIR /

RUN pip3.8 install numpy==1.20.1 pandas==1.3.1 nibabel==3.0.0

RUN mkdir /input && mkdir /output && \
    chmod -R 777 /input && chmod -R 777 /output


ENV MPLCONFIGDIR /tmp/matplotlib
ENV PYTHONWARNINGS ignore

RUN ldconfig

# and add it as an entrypoint
ENTRYPOINT ["m2g"]


#https://stackoverflow.com/questions/18649512/unicodedecodeerror-ascii-codec-cant-decode-byte-0xe2-in-position-13-ordinal
RUN export LC_ALL=C.UTF-8 && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#Needed for eddy correct to work
RUN virtualenv -p /usr/bin/python2.7 venv && \
    . venv/bin/activate

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
