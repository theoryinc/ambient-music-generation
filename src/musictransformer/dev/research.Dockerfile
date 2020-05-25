####################################
#
# Music Transformer
#
####################################
FROM ubuntu:latest as music_transformer_data
RUN apt-get update && apt-get install ca-certificates curl apt-transport-https ca-certificates gnupg -y && \
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
  tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
  apt-get update && apt-get install google-cloud-sdk -y
RUN mkdir -p /data/transformer && \
  gsutil -q -m cp -r gs://magentadata/models/music_transformer/* /data/transformer && \
  gsutil -q -m cp gs://magentadata/soundfonts/Yamaha-C5-Salamander-JNv5.1.sf2 /data/transformer


####################################
#
# Jason
#
####################################
FROM ubuntu:latest as preprocessing_step
ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y \
  libgirepository1.0-dev gcc libcairo2-dev \
  pkg-config gir1.2-gtk-3.0 software-properties-common \
  git curl wget \
  && add-apt-repository ppa:deadsnakes/ppa -y \
  && apt-get install python3.6 python3-pip -y

# ######### Set up Jason #########
RUN apt-get install libcairo2-dev libjpeg-dev libgif-dev libpango1.0-dev libssl-dev -y
RUN git clone https://github.com/hitheory/MusicTransformer-tensorflow2.0.git /src
RUN pip3 install -r /src/requirements.txt --ignore-installed

######### Install jason #########
RUN git clone https://github.com/jason9693/midi-neural-processor.git \
  && mv midi-neural-processor /src/midi_processor
RUN sh /src/dataset/scripts/classic_piano_downloader.sh /data/classic_piano
RUN python3 /src/preprocess.py /data/classic_piano /data/classic_piano_preprocessed

# ####################################
# #
# # Jupyter
# #
# ####################################
FROM ubuntu:latest
ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8

######### Magenta Data #########
# Copy Transformer
COPY --from=music_transformer_data /data /data
# Copy Preprocessed data
COPY --from=preprocessing_step /data/classic_piano_preprocessed /data/classic_piano_preprocessed

RUN apt-get update && apt-get install -y \
  libgirepository1.0-dev gcc libcairo2-dev \
  pkg-config gir1.2-gtk-3.0 software-properties-common \
  git curl wget \
  && add-apt-repository ppa:deadsnakes/ppa -y \
  && apt-get install python3.6 python3-pip -y

######### NVIDIA #########
RUN apt-get install nvidia-modprobe nvidia-utils-440 -y

######### Set up Jason #########
RUN apt-get install libcairo2-dev libjpeg-dev libgif-dev libpango1.0-dev libssl-dev -y
RUN git clone https://github.com/hitheory/MusicTransformer-tensorflow2.0.git /src
RUN pip3 install -r /src/requirements.txt --ignore-installed
# RUN git clone https://github.com/jason9693/midi-neural-processor.git \
#   && mv midi-neural-processor /src/midi_processor

######### Install Jupyter and Notebook requirements #########
RUN pip3 install google-colab
# https://github.com/jupyter/jupyter_console/issues/163#issuecomment-418392676
RUN pip3 install tensor2tensor prompt-toolkit
RUN pip3 install jupyter
RUN pip3 install --upgrade ipykernel
RUN pip3 uninstall notebook -y
RUN pip3 install --ignore-installed --no-cache-dir --upgrade notebook
RUN pip3 install tensorboard
# Magenta runs an old version of bokeh
# RUN pip uninstall bokeh -y
# RUN pip3 install bokeh==1.4.0

######### Set up file system #########
RUN mkdir -p /notebooks && chmod a+rwx /notebooks
RUN mkdir -p /logs && chmod 777 /logs
RUN mkdir /.local && chmod a+rwx /.local
WORKDIR /notebooks
EXPOSE 8888
COPY jupyter_notebook_config.py /root/.jupyter/jupyter_notebook_config.py

######### Run Jupyter notebook #########
# CMD ["bash", "-c", "jupyter notebook --ip 0.0.0.0 --allow-root --no-browser"]
COPY bash_scripts/dev.start.sh /notebooks/src/bash_scripts/dev.start.sh
CMD ["bash", "-c", "/notebooks/src/bash_scripts/dev.start.sh"]