ARG IMAGE=intersystemsdc/iris-community:2026.1
FROM $IMAGE

WORKDIR /home/irisowner/dev

ARG TESTS=0
ARG MODULE="dc-sample"
ARG NAMESPACE="IRISAPP"

## Embedded Python environment
ENV IRISUSERNAME="_SYSTEM"
ENV IRISPASSWORD="SYS"
ENV IRISNAMESPACE="${NAMESPACE}"
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"

# ==========================================================
# IntegratedML / Custom Python Models support
# ==========================================================
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    gcc \
    g++ \
    make \
    libssl-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. stack ML — usa --break-system-packages pois estamos em container
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    scikit-learn \
    pandas \
    numpy \
    joblib \
    matplotlib \
    imbalanced-learn

# 3. Pacote AutoML oficial da InterSystems
RUN python3 -m pip install --index-url https://registry.intersystems.com/pypi/simple \
    --no-cache-dir --break-system-packages \
    intersystems-iris-automl

# 4. Criar diretórios para custom models
RUN mkdir -p /home/irisowner/dev/custom_models/classifiers \
    && mkdir -p /home/irisowner/dev/custom_models/regressors \
    && chown -R irisowner:irisowner /home/irisowner/dev

# 5. Garantir que o IRIS enxergue esses pacotes em runtime
ENV PYTHONPATH="/home/irisowner/dev/custom_models:/usr/irissys/mgr/python:${PYTHONPATH:+:${PYTHONPATH}}"

# ==========================================================
# FIM — IntegratedML support
# ==========================================================

USER irisowner

COPY .iris_init /home/irisowner/

# Build padrão do projeto
RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
    iris session IRIS < iris.script && \
    ([ $TESTS -eq 0 ] || iris session iris -U "$NAMESPACE" "##class(%ZPM.PackageManager).Shell(\"test $MODULE -v -only\",1,1)") && \
    iris stop IRIS quietly
